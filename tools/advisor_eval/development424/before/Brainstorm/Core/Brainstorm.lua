local lovely = require("lovely")
local nfs = require("nativefs")
local ffi = require("ffi")

Brainstorm = {}

Brainstorm.VERSION = "Brainstorm v2.206.0-alpha"
Brainstorm.NATIVE_FILE = "Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll"

Brainstorm.SMODS = nil

local saveKeys = { "1", "2", "3", "4", "5" }

Brainstorm.config = {
  enable = true,
  keybind_autoreroll = "r",
  keybinds = {
    options = "t",
    modifier = "lctrl",
    f_reroll = "r",
    a_reroll = "a",
    s_state = "z",
    l_state = "x",
  },
  ar_filters = {
    pack = {},
    pack_id = 1,
    voucher_name = "",
    voucher_id = 1,
    tag_name = "tag_charm",
    tag_id = 2,
    soul_count = 1,
    -- observatory_deadline is 0 when disabled, otherwise the last Ante in
    -- which the Telescope -> Observatory voucher chain may be completed.
    -- inst_observatory remains synchronized for old configs and saved runs.
    inst_observatory = false,
    observatory_deadline = 0,
    -- Kept for one config migration cycle. The UI now uses joker_targets.
    inst_perkeo = false,
    joker_targets = { "", "", "", "", "" },
    joker_target_editions = {
      "Any Edition",
      "Any Edition",
      "Any Edition",
      "Any Edition",
      "Any Edition",
    },
    joker_target_locations = {
      "ante_1",
      "ante_1",
      "ante_1",
      "ante_1",
      "ante_1",
    },
    no_perishable_jokers = false,
    copy_money = false,
    bean = false,
    burglar = false,
    retcon = false,
    custom_filter_name = "No Filter",
    custom_filter_id = 1,
    rank_name = "King",
    rank_id = 12,
    suit_name = "Any Suit",
    suit_id = 1,
    rank_min = 0,
    rank_min_id = 1,
    any_rank_min = 0,
    any_rank_min_id = 1,
  },
  -- Retained so older config files continue to round-trip. Native search is
  -- CPU-bound and does not use a seeds-per-frame limit.
  ar_prefs = {
    spf_id = 3,
    spf_int = 1000,
    native_cpu_mode = "balanced",
  },
}

Brainstorm.ar_timer = 0
Brainstorm.ar_frames = 0
Brainstorm.ar_text = nil
Brainstorm.ar_active = false
Brainstorm.AR_INTERVAL = 0.01
Brainstorm.ar_native_query = nil
Brainstorm.search_estimate = {
  headline = "Not estimated yet",
  detail = "Use the button below for the current setup",
  method_line = "",
  sample_line = "",
  speed_line = "",
  note_line = "Changing any search setting clears this result",
  warning_line = "",
  evidence_line = "",
  status = "idle",
  fingerprint = nil,
}
Brainstorm.search_estimate_generation = 0
Brainstorm.search_estimate_dirty = true
Brainstorm.SEARCH_ESTIMATE_BUDGET_MS = 1000

local immolate = nil
local immolate_cdef_loaded = false
local immolate_runtime_libs = {}
local immolate_runtime_loaded = false

-- Cache frequently used functions
local math_abs = math.abs
local string_format = string.format
local string_lower = string.lower

local MAX_SOUL_COUNT = 4
local MAX_JOKER_TARGETS = 5
local DEFAULT_JOKER_TARGET_LOCATION = "ante_1"
local joker_target_location_ids = {
  ante_1 = true,
  soul_pack = true,
  ante_2 = true,
  soul_or_ante_2 = true,
  ante_3 = true,
  ante_4 = true,
  by_ante_2 = true,
  by_ante_3 = true,
  by_ante_4 = true,
  by_ante_5 = true,
  by_ante_6 = true,
  by_ante_7 = true,
  by_ante_8 = true,
}
local flexible_joker_target_locations = { soul_or_ante_2 = true }
local later_ante_joker_target_locations = {
  ante_2 = true,
  ante_3 = true,
  ante_4 = true,
  by_ante_2 = true,
  by_ante_3 = true,
  by_ante_4 = true,
  by_ante_5 = true,
  by_ante_6 = true,
  by_ante_7 = true,
  by_ante_8 = true,
}
local legendary_jokers = {
  Canio = true,
  Triboulet = true,
  Yorick = true,
  Chicot = true,
  Perkeo = true,
}
local soul_custom_filters = {
  ["Negative Perkeo"] = true,
  N_Perk_Blueprint = true,
  ["Perkeo Baseball"] = true,
}
local suit_filter_ids = {
  ["Any Suit"] = 1,
  ["Any One Suit"] = 2,
  Clubs = 3,
  Diamonds = 4,
  Hearts = 5,
  Spades = 6,
}
local vanilla_deck_names = {
  b_red = "Red Deck",
  b_blue = "Blue Deck",
  b_yellow = "Yellow Deck",
  b_green = "Green Deck",
  b_black = "Black Deck",
  b_magic = "Magic Deck",
  b_nebula = "Nebula Deck",
  b_ghost = "Ghost Deck",
  b_abandoned = "Abandoned Deck",
  b_checkered = "Checkered Deck",
  b_zodiac = "Zodiac Deck",
  b_painted = "Painted Deck",
  b_anaglyph = "Anaglyph Deck",
  b_plasma = "Plasma Deck",
  b_erratic = "Erratic Deck",
  b_challenge = "Challenge Deck",
}
local vanilla_deck_name_set = {}
for _, deck_name in pairs(vanilla_deck_names) do
  vanilla_deck_name_set[deck_name] = true
end

local standard_rank_names = {
  ["2"] = true,
  ["3"] = true,
  ["4"] = true,
  ["5"] = true,
  ["6"] = true,
  ["7"] = true,
  ["8"] = true,
  ["9"] = true,
  ["10"] = true,
  Jack = true,
  Queen = true,
  King = true,
  Ace = true,
}
local grouped_rank_names = {
  ["Kings or Queens"] = { "King", "Queen" },
  Royals = { "Ace", "Jack", "King", "Queen", "10" },
}
local abandoned_rank_names = { Jack = true, Queen = true, King = true }
local fixed_suit_names = {
  Clubs = true,
  Diamonds = true,
  Hearts = true,
  Spades = true,
}

local function getCurrentDeckName()
  local selected_back = G and G.GAME and G.GAME.selected_back
  local center = selected_back
    and selected_back.effect
    and selected_back.effect.center
  if center and center.key then
    return vanilla_deck_names[center.key]
  end
  return (center and center.name)
    or (selected_back and selected_back.name)
    or "Red Deck"
end

local function targetRankExistsInDeck(deck_name, target_rank)
  local ranks = grouped_rank_names[target_rank] or { target_rank }
  for _, rank in ipairs(ranks) do
    if
      standard_rank_names[rank]
      and not (
        deck_name == "Abandoned Deck" and abandoned_rank_names[rank]
      )
    then
      return true
    end
  end
  return false
end

local function getDeterministicSpecificRankMaximum(filters, deck_name)
  if not targetRankExistsInDeck(deck_name, filters.rank_name) then
    return 0
  end

  local target_suit = filters.suit_name
  if deck_name == "Checkered Deck" then
    if target_suit == "Any Suit" then
      return 4
    end
    if
      target_suit == "Any One Suit"
      or target_suit == "Hearts"
      or target_suit == "Spades"
    then
      return 2
    end
    return 0
  end

  if target_suit == "Any Suit" then
    return 4
  end
  if target_suit == "Any One Suit" or fixed_suit_names[target_suit] then
    return 1
  end
  return 0
end

local function deterministicRankFiltersPossible(filters, deck_name)
  if deck_name == "Erratic Deck" then
    return true
  end

  local specific_min = math.max(
    0,
    math.floor(tonumber(filters.rank_min) or 0)
  )
  local any_rank_min = math.max(
    0,
    math.floor(tonumber(filters.any_rank_min) or 0)
  )
  if specific_min == 0 and any_rank_min == 0 then
    return true
  end

  local specific_possible = specific_min > 0
    and specific_min
      <= getDeterministicSpecificRankMaximum(filters, deck_name)
  local any_rank_possible = any_rank_min > 0 and any_rank_min <= 4
  return specific_possible or any_rank_possible
end

local function clampInteger(value, minimum, maximum, fallback)
  local number = tonumber(value)
  if number == nil then
    return fallback
  end
  number = math.floor(number)
  return math.max(minimum, math.min(maximum, number))
end

local function getCurrentStakeLevel()
  local stake = G and G.GAME and G.GAME.stake
  if stake == nil and G and G.PROFILES and G.SETTINGS then
    local profile = G.PROFILES[G.SETTINGS.profile]
    stake = profile and profile.MEMORY and profile.MEMORY.stake
  end
  return clampInteger(stake, 1, 8, 1)
end

local function normalizeObservatoryDeadline(value, legacy_enabled)
  if value == nil then
    return legacy_enabled and 2 or 0
  end

  local deadline = tonumber(value)
  if deadline == nil or deadline <= 0 then
    return 0
  end
  return math.max(2, math.min(8, math.floor(deadline)))
end

local function normalizeJokerTargets(targets)
  local normalized = {}
  targets = type(targets) == "table" and targets or {}
  for i = 1, MAX_JOKER_TARGETS do
    local target = targets[i]
    if
      type(target) == "string"
      and target ~= ""
      and target ~= "None"
    then
      normalized[i] = target
    else
      normalized[i] = ""
    end
  end
  return normalized
end

local function normalizeJokerTargetEditions(editions, targets)
  local normalized = {}
  editions = type(editions) == "table" and editions or {}
  for i = 1, MAX_JOKER_TARGETS do
    normalized[i] = targets[i] ~= "" and editions[i] == "Negative"
        and "Negative"
      or "Any Edition"
  end
  return normalized
end

local function normalizeJokerTargetLocations(locations)
  local normalized = {}
  locations = type(locations) == "table" and locations or {}
  for i = 1, MAX_JOKER_TARGETS do
    local location = locations[i]
    normalized[i] = joker_target_location_ids[location] and location
      or DEFAULT_JOKER_TARGET_LOCATION
  end
  return normalized
end

local function serializeJokerTargets()
  local filters = Brainstorm.config.ar_filters
  local targets = normalizeJokerTargets(filters.joker_targets)
  local editions = normalizeJokerTargetEditions(
    filters.joker_target_editions,
    targets
  )
  local serialized = {}
  for i = 1, MAX_JOKER_TARGETS do
    serialized[i] = targets[i]
    if targets[i] ~= "" and editions[i] == "Negative" then
      serialized[i] = targets[i] .. "\30N"
    end
  end
  return table.concat(serialized, "\31")
end

local function serializeJokerTargetLocations()
  return table.concat(
    normalizeJokerTargetLocations(
      Brainstorm.config.ar_filters.joker_target_locations
    ),
    "\31"
  )
end

local function getEffectiveJokerTimingOptions(target, location)
  if legendary_jokers[target] then
    -- Legendary Jokers always come from a starting-pack Soul, including the
    -- legacy ante_1 and flexible Charm/Ante 2 location values.
    return { 0 }
  end
  if location == "soul_pack" then
    return { 0 }
  end
  if location == "soul_or_ante_2" then
    return { 0, 2 }
  end
  local deadline = tonumber(type(location) == "string"
      and location:match("^by_ante_(%d+)$")
    or nil)
  if deadline then
    -- Cumulative deadlines include the starting Charm Pack and every natural
    -- no-reroll opportunity through the selected Ante. Native search consumes
    -- distinct acquisitions when the same Joker occupies multiple slots.
    local timings = {}
    for timing = 0, deadline do
      timings[#timings + 1] = timing
    end
    return timings
  end
  if location == "ante_2" then
    return { 2 }
  end
  if location == "ante_3" then
    return { 3 }
  end
  if location == "ante_4" then
    return { 4 }
  end
  return { 1 }
end

local function orderedJokerTargetTimingsPossible(targets, locations)
  local previous_timing = 0
  for slot = 1, MAX_JOKER_TARGETS do
    if targets[slot] ~= "" then
      local selected_timing
      for _, timing in ipairs(
        getEffectiveJokerTimingOptions(targets[slot], locations[slot])
      ) do
        if timing >= previous_timing then
          selected_timing = timing
          break
        end
      end
      if selected_timing == nil then
        return false, slot
      end
      previous_timing = selected_timing
    end
  end
  return true
end

local function orderedJokerTargetRoutePossible(
  targets,
  locations,
  implicit_starting_pack_choices
)
  local states = {
    {
      timing = 0,
      starting_pack_choices = implicit_starting_pack_choices,
      judgement_choices = 0,
    },
  }

  for slot = 1, MAX_JOKER_TARGETS do
    local target = targets[slot]
    if target ~= "" then
      local next_states = {}
      local seen_states = {}
      local exceeded_starting_pack_choices = false
      local exceeded_judgement_choices = false
      for _, state in ipairs(states) do
        for _, timing in ipairs(
          getEffectiveJokerTimingOptions(target, locations[slot])
        ) do
          if timing >= state.timing then
            local is_starting_pack_choice = timing == 0
            local is_judgement_choice =
              is_starting_pack_choice and not legendary_jokers[target]
            local starting_pack_choices =
              state.starting_pack_choices
                + (is_starting_pack_choice and 1 or 0)
            local judgement_choices =
              state.judgement_choices + (is_judgement_choice and 1 or 0)

            if judgement_choices > 1 then
              exceeded_judgement_choices = true
            elseif starting_pack_choices > 2 then
              exceeded_starting_pack_choices = true
            else
              local state_key =
                timing
                  .. ":"
                  .. starting_pack_choices
                  .. ":"
                  .. judgement_choices
              if not seen_states[state_key] then
                seen_states[state_key] = true
                next_states[#next_states + 1] = {
                  timing = timing,
                  starting_pack_choices = starting_pack_choices,
                  judgement_choices = judgement_choices,
                }
              end
            end
          end
        end
      end
      states = next_states
      if #states == 0 then
        return false,
          exceeded_judgement_choices and "judgement" or "choices"
      end
    end
  end

  return true
end

local function getRequiredLegendaryTargetCount(filters)
  local count = 0
  local has_perkeo_target = false
  for _, target in ipairs(normalizeJokerTargets(filters.joker_targets)) do
    if legendary_jokers[target] then
      count = count + 1
      if target == "Perkeo" then
        has_perkeo_target = true
      end
    end
  end
  if
    soul_custom_filters[filters.custom_filter_name]
    and not has_perkeo_target
  then
    count = count + 1
  end
  return count
end

function Brainstorm.getRequiredSoulCount()
  local filters = Brainstorm.config.ar_filters
  local required = clampInteger(
    filters.soul_count,
    0,
    MAX_SOUL_COUNT,
    1
  )
  local legendary_target_count = getRequiredLegendaryTargetCount(filters)
  return math.max(required, legendary_target_count)
end

function Brainstorm.validateAutoRerollFilters()
  if G and G.GAME and G.GAME.challenge then
    if Brainstorm.validateChallengeOpening then return Brainstorm.validateChallengeOpening() end
    return false, "Challenge opening search is unavailable"
  end
  local filters = Brainstorm.config.ar_filters
  local current_deck_name = getCurrentDeckName()
  local legendary_target_count = getRequiredLegendaryTargetCount(filters)
  local joker_targets = normalizeJokerTargets(filters.joker_targets)
  local joker_target_locations = normalizeJokerTargetLocations(
    filters.joker_target_locations
  )
  local starting_pack_choice_count = legendary_target_count
  local starting_pack_judgement_count = 0
  local previous_location_by_target = {}
  local seen_legendary_targets = {}
  local has_repeated_joker = false
  local needs_starting_charm_pack =
    Brainstorm.getRequiredSoulCount() > 0
      or soul_custom_filters[filters.custom_filter_name]

  if legendary_target_count > 2 then
    return false, "Choose at most 2 legendary Jokers"
  end

  for slot = 1, MAX_JOKER_TARGETS do
    local target = joker_targets[slot]
    local location = joker_target_locations[slot]
    if target ~= "" then
      if target == "Stone Joker" then
        return false,
          "Normal opening search cannot yet model the Stone Card prerequisite for Stone Joker. Search for Marble Joker first, then find Stone Joker during play."
      end
      local prerequisite = ({
        ["Steel Joker"] = "a Steel Card",
        ["Glass Joker"] = "a Glass Card",
        ["Golden Ticket"] = "a Gold Card",
        ["Lucky Cat"] = "a Lucky Card",
        ["Cavendish"] = "Gros Michel destroying itself",
      })[target]
      if prerequisite then
        return false, "Normal opening search cannot yet model " .. prerequisite ..
          " before " .. target .. ". Meet this prerequisite and find the Joker during play."
      end
      if legendary_jokers[target] then
        if seen_legendary_targets[target] then
          return false,
            "A starting Soul cannot give the same Legendary Joker twice"
        end
        seen_legendary_targets[target] = true
      end

      if
        legendary_jokers[target]
        and later_ante_joker_target_locations[location]
      then
        return false,
          "Legendary Joker " .. slot .. " must use Starting Charm Pack"
      end

      if location == "soul_pack" then
        needs_starting_charm_pack = true
        if not legendary_jokers[target] then
          starting_pack_choice_count = starting_pack_choice_count + 1
          starting_pack_judgement_count =
            starting_pack_judgement_count + 1
        end
      elseif location == "soul_or_ante_2" then
        needs_starting_charm_pack = true
      end

      local previous_location = previous_location_by_target[target]
      if previous_location then
        has_repeated_joker = true
      end
      if
        previous_location
        and (
          flexible_joker_target_locations[previous_location]
          or flexible_joker_target_locations[location]
        )
      then
        return false, "Repeated Jokers need exact timing for every copy"
      end
      if not previous_location then
        previous_location_by_target[target] = location
      end
    end
  end

  if has_repeated_joker then
    local timing_order_possible, backwards_slot =
      orderedJokerTargetTimingsPossible(
        joker_targets,
        joker_target_locations
      )
    if not timing_order_possible then
      return false,
        "Joker " .. backwards_slot .. " cannot appear before an earlier Joker"
    end

    local implicit_starting_pack_choices =
      soul_custom_filters[filters.custom_filter_name]
        and not previous_location_by_target.Perkeo
        and 1
      or 0
    local route_possible, route_failure =
      orderedJokerTargetRoutePossible(
        joker_targets,
        joker_target_locations,
        implicit_starting_pack_choices
      )
    if not route_possible then
      if route_failure == "judgement" then
        return false, "Starting Charm Pack can provide only 1 Judgement Joker"
      end
      return false, "Starting Charm Pack would need more than 2 choices"
    end
  end

  if starting_pack_judgement_count > 1 then
    return false, "Starting Charm Pack can provide only 1 Judgement Joker"
  end
  if starting_pack_choice_count > 2 then
    return false, "Starting Charm Pack would need more than 2 choices"
  end

  if not vanilla_deck_name_set[current_deck_name] then
    return false, "Auto-reroll supports vanilla decks only"
  end

  if
    G
    and G.GAME
    and (G.GAME.challenge or current_deck_name == "Challenge Deck")
  then
    return false, "Auto-reroll is not supported in Challenge runs"
  end

  if not deterministicRankFiltersPossible(filters, current_deck_name) then
    return false,
      "Rank/suit criteria are impossible for " .. current_deck_name
  end

  local observatory_deadline = normalizeObservatoryDeadline(
    filters.observatory_deadline,
    filters.inst_observatory == true
  )
  if
    observatory_deadline > 0
    and filters.voucher_name ~= ""
    and filters.voucher_name ~= "v_telescope"
  then
    return false,
      "Observatory deadline supports Telescope or no Voucher Search"
  end
  if observatory_deadline > 0 and filters.retcon then
    return false,
      "Observatory and Early Retcon cannot be guaranteed together"
  end

  if
    needs_starting_charm_pack
    and filters.tag_name ~= ""
    and filters.tag_name ~= "tag_charm"
  then
    return false, "Soul searches need Charm Tag or no tag"
  end

  return true
end

local function findBrainstormDirectory(directory)
  for _, item in ipairs(nfs.getDirectoryItems(directory)) do
    local itemPath = directory .. "/" .. item
    if
      nfs.getInfo(itemPath, "directory")
      and string_lower(item):find("brainstorm")
    then
      return itemPath
    end
  end
  return nil
end

local function fileExists(filePath)
  return nfs.getInfo(filePath) ~= nil
end

local function preloadImmolateRuntime()
  if immolate_runtime_loaded or ffi.os ~= "Windows" then
    return
  end

  ffi.cdef([[
    int SetDllDirectoryA(const char* lpPathName);
  ]])
  if ffi.C.SetDllDirectoryA(Brainstorm.PATH) == 0 then
    error(
      "Failed to set DLL search path for Brainstorm runtime loading."
    )
  end

  local runtime_names = {
    "libwinpthread-1.dll",
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
  }

  for _, runtime_name in ipairs(runtime_names) do
    local runtime_path = Brainstorm.PATH .. "/" .. runtime_name
    if fileExists(runtime_path) then
      local ok, lib_or_err = pcall(ffi.load, runtime_path)
      if not ok then
        error(
          "Failed to load Brainstorm runtime dependency '"
            .. runtime_name
            .. "': "
            .. tostring(lib_or_err)
        )
      end
      immolate_runtime_libs[#immolate_runtime_libs + 1] = lib_or_err
    end
  end

  immolate_runtime_loaded = true
end

local function ensureImmolateLoaded()
  if not immolate_cdef_loaded then
    ffi.cdef([[
      const char* brainstorm_v2(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers);
      const char* brainstorm_v3(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck);
      const char* brainstorm_v4(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations);
      const char* brainstorm_v5(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations);
      const char* brainstorm_v6(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations);
      const char* brainstorm_v7(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int stakeLevel);
      const char* brainstorm_v8(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int stakeLevel, bool noPerishableJokers);
      const char* brainstorm_v9(const char* seed, const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int stakeLevel, bool noPerishableJokers, bool interchangeableCopies, const char* missingNames, int minimumDistinct, int firstAnte, int lastAnte, int budgetMs);
      void brainstorm_cancel_v9();
      const char* brainstorm_estimate_v1(const char* voucher, const char* pack, const char* tag, int souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int budget_ms);
      const char* brainstorm_estimate_v2(const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int budget_ms);
      const char* brainstorm_estimate_v3(const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int budget_ms, int stakeLevel);
      const char* brainstorm_estimate_v4(const char* voucher, const char* pack, const char* tag, int souls, bool observatory, int observatoryDeadline, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin, const char* targetJokers, const char* deck, const char* targetLocations, int budget_ms, int stakeLevel, bool noPerishableJokers);
      void brainstorm_set_search_thread_mode(int mode);
      const char* brainstorm_challenge_opening_v1(const char* seed, const char* challenge_id, const char* targetJokersCSV);
      const char* brainstorm_challenge_opening_v2(const char* seed, const char* challenge_id, const char* targetJokersCSV, const char* laterJoker, int deadlineAnte, const char* rarePoolMask);
      void free_result(const char* result);
    ]])
    immolate_cdef_loaded = true
  end

  if immolate == nil then
    preloadImmolateRuntime()
    local library_name
    if ffi.os == "Windows" then
      library_name = Brainstorm.NATIVE_FILE
    elseif ffi.os == "Linux" then
      library_name = "Immolate.so"
    else
      error("Brainstorm native search does not support " .. tostring(ffi.os))
    end
    local ok, lib_or_err = pcall(
      ffi.load,
      Brainstorm.PATH .. "/" .. library_name
    )
    if not ok then
      error(
        "Failed to load Brainstorm "
          .. library_name
          .. ". "
          .. (ffi.os == "Windows"
              and "Make sure the Brainstorm folder includes libgcc_s_seh-1.dll, libstdc++-6.dll, and libwinpthread-1.dll. "
            or "Build and place the portable native library in the Brainstorm folder. ")
          .. "Original error: "
          .. tostring(lib_or_err)
      )
    end
    immolate = lib_or_err
  end

  return immolate
end

local function formatCompactEstimateNumber(value)
  value = tonumber(value)
  if not value or value < 0 or value ~= value then
    return nil
  end

  local suffixes = {
    { 1000000000000, "T" },
    { 1000000000, "B" },
    { 1000000, "M" },
    { 1000, "K" },
  }
  for _, suffix in ipairs(suffixes) do
    if value >= suffix[1] then
      local formatted = string_format("%.1f", value / suffix[1])
      formatted = formatted:gsub("%.0$", "")
      return formatted .. suffix[2]
    end
  end
  return tostring(math.floor(value + 0.5))
end

local function formatEstimateDuration(seconds)
  seconds = tonumber(seconds)
  if
    not seconds
    or seconds < 0
    or seconds ~= seconds
    or seconds == math.huge
  then
    return nil
  end
  if seconds < 1 then
    return "<1 sec"
  end

  local total_seconds = math.floor(seconds + 0.5)
  if total_seconds < 60 then
    return total_seconds .. " sec"
  end
  if total_seconds < 3600 then
    local minutes = math.floor(total_seconds / 60)
    local remaining_seconds = total_seconds % 60
    if remaining_seconds == 0 then
      return minutes .. " min"
    end
    return minutes .. "m " .. remaining_seconds .. "s"
  end
  if total_seconds < 86400 then
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor((total_seconds % 3600) / 60)
    if minutes == 0 then
      return hours .. " hr"
    end
    return hours .. "h " .. minutes .. "m"
  end
  if total_seconds < 604800 then
    local days = math.floor(total_seconds / 86400)
    local hours = math.floor((total_seconds % 86400) / 3600)
    if hours == 0 then
      return days .. (days == 1 and " day" or " days")
    end
    return days .. "d " .. hours .. "h"
  end
  if total_seconds < 31557600 then
    local weeks = math.floor(total_seconds / 604800)
    local days = math.floor((total_seconds % 604800) / 86400)
    if days == 0 then
      return weeks .. (weeks == 1 and " week" or " weeks")
    end
    return weeks .. "w " .. days .. "d"
  end

  local years = seconds / 31557600
  local formatted = string_format(years < 10 and "%.1f" or "%.0f", years)
  formatted = formatted:gsub("%.0$", "")
  return formatted .. (formatted == "1" and " year" or " years")
end

local function parseSearchEstimateResult(raw_result)
  local fields = {}
  if type(raw_result) ~= "string" then
    return fields
  end
  for field in (raw_result .. "\t"):gmatch("(.-)\t") do
    local key, value = field:match("^([%w_]+)=(.*)$")
    if key then
      fields[key] = value
    end
  end
  return fields
end

local function shortenEstimateDetail(text)
  text = tostring(text or ""):gsub("[\r\n\t]", " ")
  if #text > 42 then
    return text:sub(1, 39) .. "..."
  end
  return text
end

local function setSearchEstimate(
  status,
  headline,
  detail,
  method_line,
  sample_line,
  speed_line,
  note_line,
  warning_line,
  evidence_line
)
  local estimate = Brainstorm.search_estimate
  estimate.status = status
  estimate.headline = headline
  estimate.detail = shortenEstimateDetail(detail)
  estimate.method_line = shortenEstimateDetail(method_line)
  estimate.sample_line = shortenEstimateDetail(sample_line)
  estimate.speed_line = shortenEstimateDetail(speed_line)
  estimate.note_line = shortenEstimateDetail(note_line)
  estimate.warning_line = shortenEstimateDetail(warning_line)
  estimate.evidence_line = shortenEstimateDetail(evidence_line)
end

function Brainstorm.applySearchEstimateResult(raw_result)
  local fields = parseSearchEstimateResult(raw_result)
  local status = fields.status
  local method = fields.method or ""
  if status == "always" then
    status = "ok"
    method = "always"
  end
  local is_indexed = method == "exact_index" or method == "index_sample"
  local tested = tonumber(
    fields.indexed_tested or fields.exact_tested or fields.tested
  )
  local hits = tonumber(fields.indexed_hits or fields.exact_hits or fields.hits)
  local seeds_per_second = tonumber(
    fields.candidates_per_second or fields.seeds_per_second
  )
  local median = formatEstimateDuration(fields.median_seconds)
  local p90 = formatEstimateDuration(fields.p90_seconds)
  local median_low = formatEstimateDuration(fields.median_low_seconds)
  local median_high = formatEstimateDuration(fields.median_high_seconds)
  local exact_median_lower =
    formatEstimateDuration(fields.exact_median_lower_seconds)
  if status == "ok" and method == "always" and not median then
    median = "<1 sec"
  end
  local tested_label = formatCompactEstimateNumber(tested)
  local hits_label = formatCompactEstimateNumber(hits)
  local speed_label = formatCompactEstimateNumber(seeds_per_second)
  local sample_line = ""
  local speed_line = ""

  if tested_label then
    sample_line =
      "Sample: "
      .. (hits_label or "0")
      .. " matches / "
      .. tested_label
      .. (is_indexed and " candidates" or " seeds")
  end
  if speed_label then
    speed_line =
      "Measured speed: "
      .. speed_label
      .. (is_indexed and " candidates/sec" or " seeds/sec")
  end

  if status == "impossible" then
    setSearchEstimate(
      "impossible",
      "No matching seeds",
      fields.message or "The selected criteria cannot occur together",
      is_indexed and "Method: complete exact index"
        or "Method: deterministic validation",
      sample_line,
      speed_line,
      "Change the selected criteria before searching"
    )
    return false
  end

  if status == "invalid" then
    setSearchEstimate(
      "invalid",
      "Cannot estimate this setup",
      fields.message or "Check the selected criteria",
      "Method: validation",
      "",
      "",
      "Change the selected criteria and try again"
    )
    return false
  end

  if status == "no_hits" or (status == "ok" and hits == 0 and not median) then
    local evidence_line = exact_median_lower
        and ("95% exact lower bound: typical > " .. exact_median_lower)
      or ""
    setSearchEstimate(
      "no_hits",
      "Too rare for this exact sample",
      tested_label
          and (
            "No matches in "
              .. tested_label
              .. (is_indexed and " tested candidates" or " tested seeds")
          )
        or "No matches were found during the estimate",
      is_indexed
          and "Method: indexed sample | Confidence: unresolved"
        or "Method: exact sample | Confidence: unresolved",
      sample_line,
      speed_line,
      fields.message
        or "This is not proof that matching seeds do not exist",
      "",
      evidence_line
    )
    return false
  end

  if status ~= "ok" or not median then
    setSearchEstimate(
      "unavailable",
      "Estimate unavailable",
      fields.message or "The native estimator did not return a time",
      "",
      sample_line,
      speed_line,
      "Try the estimate again"
    )
    return false
  end

  local is_rough =
    method == "staged_heuristic"
      or method == "heuristic"
      or method == "rough_model"
  local is_always = method == "always"
  local headline = (
    is_indexed and "Indexed typical: "
      or (is_rough and "Rough typical: " or "Typical: ")
  ) .. median
  local detail
  if is_always then
    detail = fields.message or "The selected filters pass every seed"
  elseif median_low and median_high and p90 then
    detail =
      "Range "
      .. median_low
      .. "-"
      .. median_high
      .. " | 90% by "
      .. p90
  elseif p90 then
    detail = "90% chance by " .. p90
  elseif median_low and median_high then
    detail = "Broad range: " .. median_low .. "-" .. median_high
  else
    detail = is_rough and "Based on a staged rarity model" or "Sample-based estimate"
  end

  local confidence = (fields.confidence or ""):gsub("_", " ")
  if confidence == "" then
    confidence = is_always and "exact"
      or (is_rough and "low" or "sample-based")
  end
  local heuristic_samples_label =
    formatCompactEstimateNumber(fields.heuristic_samples)
  local method_label = is_always and "Deterministic pass"
    or (method == "exact_index" and "Complete exact index")
    or (method == "index_sample" and "Exact index sample")
    or (is_rough and "Rough model" or "Exact sample")
  if is_rough and heuristic_samples_label then
    method_label = method_label .. " " .. heuristic_samples_label
  end
  local method_line = method_label .. " | Confidence: " .. confidence
  local note_line = not is_always and fields.message or nil
  if not note_line or note_line == "" then
    note_line = is_indexed
        and "A complete rare-event index replaces raw enumeration"
      or is_rough
        and "No exact hits; model-based times may vary widely"
      or "Sample-based times vary between searches"
  end
  local expected_full_space_matches =
    tonumber(fields.expected_full_space_matches)
  local warning_line = ""
  if expected_full_space_matches and expected_full_space_matches < 1 then
    warning_line = "Warning: <1 full-space match expected"
  elseif confidence == "very low" then
    warning_line = "Warning: very low confidence"
  end
  local evidence_line = exact_median_lower
      and ("95% exact lower bound: typical > " .. exact_median_lower)
    or ""

  setSearchEstimate(
    is_rough and "rough" or "ok",
    headline,
    detail,
    method_line,
    sample_line,
    speed_line,
    note_line,
    warning_line,
    evidence_line
  )
  return true
end

local function applyAutoRerollFilterDefaults()
  local changed = false
  local filters = Brainstorm.config.ar_filters or {}

  if Brainstorm.config.ar_filters == nil then
    Brainstorm.config.ar_filters = filters
    changed = true
  end

  local defaults = {
    rank_name = "King",
    rank_id = 12,
    suit_name = "Any Suit",
    suit_id = 1,
    rank_min = 0,
    rank_min_id = 1,
    any_rank_min = 0,
    any_rank_min_id = 1,
  }

  for key, value in pairs(defaults) do
    if filters[key] == nil then
      filters[key] = value
      changed = true
    end
  end

  Brainstorm.config.ar_prefs = type(Brainstorm.config.ar_prefs) == "table"
      and Brainstorm.config.ar_prefs
    or {}
  local native_cpu_mode =
    Brainstorm.config.ar_prefs.native_cpu_mode == "maximum"
      and "maximum"
    or "balanced"
  if Brainstorm.config.ar_prefs.native_cpu_mode ~= native_cpu_mode then
    Brainstorm.config.ar_prefs.native_cpu_mode = native_cpu_mode
    changed = true
  end

  local observatory_deadline = normalizeObservatoryDeadline(
    filters.observatory_deadline,
    filters.inst_observatory == true
  )
  if filters.observatory_deadline ~= observatory_deadline then
    filters.observatory_deadline = observatory_deadline
    changed = true
  end
  local observatory_enabled = observatory_deadline > 0
  if filters.inst_observatory ~= observatory_enabled then
    filters.inst_observatory = observatory_enabled
    changed = true
  end

  local no_perishable_jokers = filters.no_perishable_jokers == true
  if filters.no_perishable_jokers ~= no_perishable_jokers then
    filters.no_perishable_jokers = no_perishable_jokers
    changed = true
  end

  -- Suit options are stored by both name and menu index. Recompute the index
  -- from the stable name when options are added so old configs still point at
  -- the suit the player selected.
  local suit_name = suit_filter_ids[filters.suit_name]
      and filters.suit_name
    or "Any Suit"
  local suit_id = suit_filter_ids[suit_name]
  if filters.suit_name ~= suit_name then
    filters.suit_name = suit_name
    changed = true
  end
  if filters.suit_id ~= suit_id then
    filters.suit_id = suit_id
    changed = true
  end

  local soul_count = clampInteger(
    filters.soul_count ~= nil and filters.soul_count or filters.soul_skip,
    0,
    MAX_SOUL_COUNT,
    1
  )
  if filters.soul_count ~= soul_count then
    filters.soul_count = soul_count
    changed = true
  end

  local joker_targets = normalizeJokerTargets(filters.joker_targets)
  if filters.inst_perkeo then
    local already_targeted = false
    for _, target in ipairs(joker_targets) do
      if target == "Perkeo" then
        already_targeted = true
        break
      end
    end
    if not already_targeted then
      for i = 1, MAX_JOKER_TARGETS do
        if joker_targets[i] == "" then
          joker_targets[i] = "Perkeo"
          break
        end
      end
    end
    filters.inst_perkeo = false
    changed = true
  end

  for i = 1, MAX_JOKER_TARGETS do
    if
      type(filters.joker_targets) ~= "table"
      or filters.joker_targets[i] ~= joker_targets[i]
    then
      changed = true
      break
    end
  end
  filters.joker_targets = joker_targets

  local joker_target_editions = normalizeJokerTargetEditions(
    filters.joker_target_editions,
    joker_targets
  )
  for i = 1, MAX_JOKER_TARGETS do
    if
      type(filters.joker_target_editions) ~= "table"
      or filters.joker_target_editions[i] ~= joker_target_editions[i]
    then
      changed = true
      break
    end
  end
  filters.joker_target_editions = joker_target_editions

  local joker_target_locations = normalizeJokerTargetLocations(
    filters.joker_target_locations
  )
  for i = 1, MAX_JOKER_TARGETS do
    if joker_targets[i] == "" then
      joker_target_locations[i] = DEFAULT_JOKER_TARGET_LOCATION
    end
  end
  for i = 1, MAX_JOKER_TARGETS do
    if
      type(filters.joker_target_locations) ~= "table"
      or filters.joker_target_locations[i] ~= joker_target_locations[i]
    then
      changed = true
      break
    end
  end
  filters.joker_target_locations = joker_target_locations

  if filters.soul_skip ~= nil then
    filters.soul_skip = nil
    changed = true
  end

  return changed
end

function Brainstorm.refreshAutoRerollQuery()
  if type(localize) ~= "function" then
    Brainstorm.ar_native_query = nil
    return nil
  end

  local pack
  if #Brainstorm.config.ar_filters.pack > 0 then
    pack = Brainstorm.config.ar_filters.pack[1]:match("^(.*)_")
  else
    pack = {}
  end

  Brainstorm.ar_native_query = {
    pack_name = localize({ type = "name_text", set = "Other", key = pack }),
    tag_name = localize({
      type = "name_text",
      set = "Tag",
      key = Brainstorm.config.ar_filters.tag_name,
    }),
    voucher_name = localize({
      type = "name_text",
      set = "Voucher",
      key = Brainstorm.config.ar_filters.voucher_name,
    }),
    target_rank = Brainstorm.config.ar_filters.rank_name or "King",
    target_suit = Brainstorm.config.ar_filters.suit_name or "Any Suit",
    specific_rank_min = Brainstorm.config.ar_filters.rank_min or 0,
    any_rank_min = Brainstorm.config.ar_filters.any_rank_min or 0,
    joker_targets = serializeJokerTargets(),
    joker_target_locations = serializeJokerTargetLocations(),
    observatory_deadline = normalizeObservatoryDeadline(
      Brainstorm.config.ar_filters.observatory_deadline,
      Brainstorm.config.ar_filters.inst_observatory == true
    ),
  }

  return Brainstorm.ar_native_query
end

local function getSearchEstimateFingerprint(
  search_query,
  deck_name,
  stake_level
)
  if not search_query then
    return nil
  end
  local filters = Brainstorm.config.ar_filters
  local parts = {
    search_query.voucher_name,
    search_query.pack_name,
    search_query.tag_name,
    filters.soul_count,
    search_query.observatory_deadline,
    filters.inst_perkeo,
    filters.copy_money,
    filters.retcon,
    filters.bean,
    filters.burglar,
    filters.custom_filter_name,
    search_query.target_rank,
    search_query.target_suit,
    search_query.specific_rank_min,
    search_query.any_rank_min,
    search_query.joker_targets,
    deck_name,
    search_query.joker_target_locations,
    stake_level,
    filters.no_perishable_jokers,
  }
  for index = 1, 20 do
    parts[index] = tostring(parts[index] or "")
  end
  return table.concat(parts, "\29")
end

function Brainstorm.invalidateSearchEstimate()
  Brainstorm.search_estimate_generation =
    Brainstorm.search_estimate_generation + 1
  Brainstorm.search_estimate_dirty = true
  Brainstorm.search_estimate.fingerprint = nil
  setSearchEstimate(
    "stale",
    "Estimate out of date",
    "Run a new estimate for the selected setup",
    "",
    "",
    "",
    "Only estimates for the current settings are shown"
  )
end

function Brainstorm.ensureSearchEstimateCurrent()
  local estimate = Brainstorm.search_estimate
  if not estimate.fingerprint then
    return
  end
  local search_query = Brainstorm.ar_native_query
    or Brainstorm.refreshAutoRerollQuery()
  local current_fingerprint =
    getSearchEstimateFingerprint(
      search_query,
      getCurrentDeckName(),
      getCurrentStakeLevel()
    )
  if current_fingerprint ~= estimate.fingerprint then
    Brainstorm.invalidateSearchEstimate()
  end
end

local function finishSearchEstimate(
  generation,
  fingerprint,
  raw_result,
  error_message
)
  if generation ~= Brainstorm.search_estimate_generation then
    return
  end
  local current_query = Brainstorm.ar_native_query
    or Brainstorm.refreshAutoRerollQuery()
  local current_fingerprint =
    getSearchEstimateFingerprint(
      current_query,
      getCurrentDeckName(),
      getCurrentStakeLevel()
    )
  if current_fingerprint ~= fingerprint then
    Brainstorm.invalidateSearchEstimate()
    return
  end

  if error_message then
    setSearchEstimate(
      "unavailable",
      "Estimate unavailable",
      error_message,
      "",
      "",
      "",
      "Try the estimate again"
    )
  else
    Brainstorm.applySearchEstimateResult(raw_result)
  end
  Brainstorm.search_estimate.fingerprint = fingerprint
  Brainstorm.search_estimate_dirty = false
end

function Brainstorm.requestSearchEstimate()
  if Brainstorm.native_search_busy then return false end
  local valid, validation_message = Brainstorm.validateAutoRerollFilters()
  if G and G.GAME and G.GAME.challenge then
    valid, validation_message = false, "Use the Challenge opening page; normal-filter estimates do not apply"
  end
  if not valid then
    Brainstorm.search_estimate_generation =
      Brainstorm.search_estimate_generation + 1
    setSearchEstimate(
      "invalid",
      "Cannot estimate this setup",
      validation_message,
      "Method: validation",
      "",
      "",
      "Change the selected criteria and try again"
    )
    Brainstorm.search_estimate.fingerprint = nil
    Brainstorm.search_estimate_dirty = false
    return
  end

  local search_query = Brainstorm.ar_native_query
    or Brainstorm.refreshAutoRerollQuery()
  if not search_query then
    setSearchEstimate(
      "unavailable",
      "Estimate unavailable",
      "Search settings are not ready yet",
      "",
      "",
      "",
      "Close and reopen the Brainstorm menu"
    )
    return
  end

  Brainstorm.search_estimate_generation =
    Brainstorm.search_estimate_generation + 1
  local generation = Brainstorm.search_estimate_generation
  local deck_name = getCurrentDeckName()
  local stake_level = getCurrentStakeLevel()
  local fingerprint =
    getSearchEstimateFingerprint(search_query, deck_name, stake_level)
  setSearchEstimate(
    "measuring",
    "Measuring this setup...",
    "The menu may pause for about one second",
    "Method: testing the selected criteria",
    "",
    "",
    "Please wait"
  )
  Brainstorm.search_estimate.fingerprint = nil
  Brainstorm.search_estimate_dirty = true

  G.E_MANAGER:add_event(Event({
    trigger = "after",
    delay = 0.05,
    blockable = false,
    blocking = false,
    func = function()
      if Brainstorm.native_search_busy or generation ~= Brainstorm.search_estimate_generation then
        return true
      end

      local immolate_lib
      local load_ok = pcall(function()
        immolate_lib = ensureImmolateLoaded()
      end)
      if not load_ok then
        finishSearchEstimate(
          generation,
          fingerprint,
          nil,
          "Could not load the native estimator"
        )
        return true
      end

      local raw_result
      local call_ok = pcall(function()
        immolate_lib.brainstorm_set_search_thread_mode(
          Brainstorm.config.ar_prefs.native_cpu_mode == "maximum" and 1 or 0
        )
        raw_result = immolate_lib.brainstorm_estimate_v4(
          search_query.voucher_name,
          search_query.pack_name,
          search_query.tag_name,
          Brainstorm.config.ar_filters.soul_count,
          Brainstorm.config.ar_filters.inst_observatory,
          search_query.observatory_deadline,
          Brainstorm.config.ar_filters.inst_perkeo,
          Brainstorm.config.ar_filters.copy_money,
          Brainstorm.config.ar_filters.retcon,
          Brainstorm.config.ar_filters.bean,
          Brainstorm.config.ar_filters.burglar,
          Brainstorm.config.ar_filters.custom_filter_name,
          search_query.target_rank,
          search_query.target_suit,
          search_query.specific_rank_min,
          search_query.any_rank_min,
          search_query.joker_targets,
          deck_name,
          search_query.joker_target_locations,
          Brainstorm.SEARCH_ESTIMATE_BUDGET_MS,
          stake_level,
          Brainstorm.config.ar_filters.no_perishable_jokers
        )
      end)
      if not call_ok or raw_result == nil then
        finishSearchEstimate(
          generation,
          fingerprint,
          nil,
          "The native estimator could not run"
        )
        return true
      end

      local result_string
      local string_ok = pcall(function()
        result_string = ffi.string(raw_result)
      end)
      pcall(function()
        immolate_lib.free_result(raw_result)
      end)
      if not string_ok then
        finishSearchEstimate(
          generation,
          fingerprint,
          nil,
          "The native estimate could not be read"
        )
        return true
      end

      finishSearchEstimate(
        generation,
        fingerprint,
        result_string,
        nil
      )
      return true
    end,
  }))
end

function Brainstorm.loadConfig()
  local configPath = Brainstorm.PATH .. "/config.lua"
  if not fileExists(configPath) then
    Brainstorm.writeConfig()
  else
    local configFile, err = nfs.read(configPath)
    if not configFile then
      error("Failed to read config file: " .. (err or "unknown error"))
    end
    Brainstorm.config = STR_UNPACK(configFile) or Brainstorm.config
  end

  if applyAutoRerollFilterDefaults() then
    Brainstorm.writeConfig()
  end

  Brainstorm.refreshAutoRerollQuery()
end

function Brainstorm.writeConfig()
  Brainstorm.refreshAutoRerollQuery()
  Brainstorm.invalidateSearchEstimate()
  local configPath = Brainstorm.PATH .. "/config.lua"
  local success, err = nfs.write(configPath, STR_PACK(Brainstorm.config))
  if not success then
    error("Failed to write config file: " .. (err or "unknown error"))
  end
end

function Brainstorm.createCharmArcanaCard(
  pack,
  card_type,
  area,
  legendary,
  rarity,
  skip_materialize,
  soulable,
  forced_key,
  key_append
)
  local filter_info = G.GAME and G.GAME.filter_info
  local required_souls = filter_info
      and (
        filter_info.required_soul_count
        or filter_info.soul_count
        or (filter_info.filter_params and filter_info.filter_params[5])
      )
    or 0
  local center_key = pack and pack.config and pack.config.center_key
  local is_matching_charm_pack = G.GAME
    and G.GAME.used_filter
    and (tonumber(required_souls) or 0) > 1
    and pack
    and pack.from_tag
    and (not Brainstorm.ChallengeOpening or Brainstorm.ChallengeOpening.matching_pack(G.GAME, pack))
    and (
      center_key == "p_arcana_mega_1"
      or center_key == "p_arcana_mega_2"
    )
    and (
      pack.brainstorm_multi_soul_pack
      or not filter_info.multi_soul_pack_consumed
    )

  if is_matching_charm_pack and not pack.brainstorm_multi_soul_pack then
    -- All five create_card calls share this pack object. Claim it once so a
    -- later Charm-tag pack in the same filtered run remains fully vanilla.
    pack.brainstorm_multi_soul_pack = true
    filter_info.multi_soul_pack_consumed = true
    if filter_info.challenge_opening and area then area.brainstorm_challenge_opening = true end
    if not G.GAME.challenge and area and G.GAME.round==0 and
        (G.GAME.round_resets or {}).ante==1 and G.GAME.blind_on_deck=='Big' and
        ((G.GAME.round_resets or {}).blind_states or {}).Small=='Skipped' and
        (G.GAME.skips or 0)==1 then
      area.brainstorm_normal_opening=true
    end
  end

  if not is_matching_charm_pack or not G.GAME.used_jokers.c_soul then
    return create_card(
      card_type,
      area,
      legendary,
      rarity,
      skip_materialize,
      soulable,
      forced_key,
      key_append
    )
  end

  -- The first Soul remains completely vanilla. For later Charm-pack slots,
  -- bypass only Soul's duplicate guard so each slot gets its natural seeded
  -- Soul roll; every other duplicate and banned-card rule still applies.
  local soul_was_used = G.GAME.used_jokers.c_soul
  G.GAME.used_jokers.c_soul = nil
  local ok, card = pcall(create_card,
    card_type,
    area,
    legendary,
    rarity,
    skip_materialize,
    soulable,
    forced_key,
    key_append
  )
  G.GAME.used_jokers.c_soul = soul_was_used
  if not ok then error(card) end
  return card
end

function Brainstorm.init()
  Brainstorm.PATH = findBrainstormDirectory(lovely.mod_dir)
  Brainstorm.loadConfig()
  local opening = assert(load(nfs.read(Brainstorm.PATH .. "/Core/challenge_opening.lua")))()
  opening.attach(Brainstorm, {alert = saveManagerAlert, search = function(seed, challenge, targets, later)
    local lib = ensureImmolateLoaded()
    lib.brainstorm_set_search_thread_mode(Brainstorm.config.ar_prefs.native_cpu_mode == "maximum" and 1 or 0)
    local ptr
    if later then
      ptr = lib.brainstorm_challenge_opening_v2(seed, challenge, targets,
        later.target_key, later.deadline, later.rare_pool_mask)
    else
      ptr = lib.brainstorm_challenge_opening_v1(seed, challenge, targets)
    end
    if ptr == nil then error("The native opening search returned no result") end
    local ok, result = pcall(ffi.string, ptr)
    lib.free_result(ptr)
    if not ok then error(result) end
    return result
  end})
  Brainstorm.JokerlessOpening = assert(load(nfs.read(Brainstorm.PATH .. "/Core/jokerless_opening.lua")))()
  local jokerless_search = assert(load(nfs.read(Brainstorm.PATH .. "/Core/jokerless_search_runtime.lua")))()
  jokerless_search.attach(Brainstorm, {opening=Brainstorm.JokerlessOpening,alert=saveManagerAlert,
    now=function() return love.timer.getTime() end})
  local start_opening=Brainstorm.startChallengeOpeningSearch
  Brainstorm.startChallengeOpeningSearch=function(...)
    if Brainstorm.native_search_busy then return false,'A bounded search is already running.' end
    return start_opening(...)
  end
  Brainstorm.Advisor = assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/runtime.lua")))()
  Brainstorm.CollectionSearch=assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/collection_search.lua")))()
  local collection_runtime=assert(load(nfs.read(Brainstorm.PATH .. "/Core/collection_search_runtime.lua")))()
  collection_runtime.attach(Brainstorm,{native=function()return ensureImmolateLoaded()end,
    now=function()return love.timer.getTime()end})
  local collection_product=assert(load(nfs.read(Brainstorm.PATH .. "/Core/collection_search_product.lua")))()
  collection_product.attach(Brainstorm)
  local checkpoint_store = assert(load(nfs.read(Brainstorm.PATH .. "/Core/checkpoint_store.lua")))()
  local checkpoints = assert(load(nfs.read(Brainstorm.PATH .. "/Core/checkpoint_runtime.lua")))()
  checkpoints.attach(Brainstorm, {store=checkpoint_store,codec=Brainstorm.Advisor.retry_journal,
    fs=love.filesystem,alert=saveManagerAlert,
    hash=function(bytes)return (love.data.hash('sha256',bytes):gsub('.',function(c)return string.format('%02x',string.byte(c)) end)) end,
    compress=function(bytes)return love.data.compress('string','deflate',bytes,1) end,
    decompress=function(bytes)return love.data.decompress('string','deflate',bytes) end,
    is_down=function(key)return love.keyboard.isDown(key) end})
  local auto_controller=assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/auto_run.lua")))()
  local auto_terminal=assert(load(nfs.read(Brainstorm.PATH .. "/Core/auto_terminal.lua")))()
  local auto_settlement=assert(load(nfs.read(Brainstorm.PATH .. "/Core/auto_run_settlement.lua")))()
  local auto_product=assert(load(nfs.read(Brainstorm.PATH .. "/Core/auto_run_product.lua")))()
  auto_product.attach(Brainstorm,{controller=auto_controller,terminal=auto_terminal,settlement=auto_settlement})
  local manual_log=assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/manual_run_log.lua")))()
  manual_log.attach(Brainstorm.Advisor,Brainstorm)
  Brainstorm.EventCadence=assert(load(nfs.read(Brainstorm.PATH .. "/Core/event_cadence.lua")))().new()
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/advisor.lua")))()
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/challenge_opening.lua")))()
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/collection_run.lua")))()
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/ui.lua")))()
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/game_speed.lua")))().attach(_G)
end

local key_press_update_ref = Controller.key_press_update
function Controller:key_press_update(key, dt)
    if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Keyboard input.') end
    if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged()) then Brainstorm.CollectionSearchProduct.stop('Keyboard input.') end
    local keybinds = Brainstorm.config.keybinds
    if key == "h" and love.keyboard.isDown(keybinds.modifier)
      and not self.text_input_hook and Brainstorm.Advisor then
      if not Brainstorm.Advisor.hotkey_down then
        Brainstorm.Advisor.hotkey_down = true
        if Brainstorm.Advisor.menu_open then
          G.FUNCS.brainstorm_advisor_close()
        elseif not G.OVERLAY_MENU then
          Brainstorm.Advisor.open()
        end
      end
      return
    end
    if Brainstorm.Checkpoints and Brainstorm.Checkpoints:hotkey(key,
      love.keyboard.isDown(keybinds.s_state),love.keyboard.isDown(keybinds.l_state),self.text_input_hook) then return end
    key_press_update_ref(self, key, dt)
  
    if love.keyboard.isDown(keybinds.modifier) then
        if key == keybinds.f_reroll then
            if Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged() then return end
            Brainstorm.reroll()
        elseif key == keybinds.a_reroll then
            if Brainstorm.ar_hotkey_down then return end
            Brainstorm.ar_hotkey_down = true
            -- An engaged auto session owns its search; this hotkey cannot
            -- cancel it, renew its budget or start an overlapping reroll.
            if Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged() then return end
            if Brainstorm.native_search_busy then
                Brainstorm.CollectionSearchProduct.stop('Search hotkey pressed.')
            elseif Brainstorm.ar_active then
                if Brainstorm.stopChallengeOpeningSearch then Brainstorm.stopChallengeOpeningSearch()
                else Brainstorm.ar_active = false end
            elseif G.GAME and G.GAME.challenge and Brainstorm.startChallengeOpeningSearch then
                Brainstorm.startChallengeOpeningSearch()
            else
                local valid, validation_message =
                    Brainstorm.validateAutoRerollFilters()
                if valid then
                    Brainstorm.ar_active = true
                else
                    saveManagerAlert(validation_message)
                end
            end
        end
    end
end

function saveManagerAlert(text)
G.E_MANAGER:add_event(Event({
  trigger = "after",
  delay = 0.4,
  func = function()
  attention_text({
    text = text,
    scale = 0.7,
    hold = 3,
    major = G.STAGE == G.STAGES.RUN and G.play or G.title_top,
    backdrop_colour = G.C.SECONDARY_SET.Tarot,
    align = "cm",
    offset = {
      x = 0,
      y = -3.5,
    },
    silent = true,
  })
  G.E_MANAGER:add_event(Event({
    trigger = "after",
    delay = 0.06 * G.SETTINGS.GAMESPEED,
    blockable = false,
    blocking = false,
    func = function()
    play_sound("other1", 0.76, 0.4)
    return true
    end,
  }))
  return true
  end,
}))
end

function Brainstorm.reroll()
  local G = G -- Cache global G for performance
  G.GAME.viewed_back = nil
  G.run_setup_seed = G.GAME.seeded
  G.challenge_tab = G.GAME and G.GAME.challenge and G.GAME.challenge_tab or nil
  G.forced_seed = G.GAME.seeded and G.GAME.pseudorandom.seed or nil

  local seed = G.run_setup_seed and G.setup_seed or G.forced_seed
  local stake = getCurrentStakeLevel()

  G:delete_run()
  G:start_run({ stake = stake, seed = seed, challenge = G.challenge_tab })
end

-- Actual input invalidates auto action context without stopping its session.
for _,method in ipairs({'queue_L_cursor_press','queue_R_cursor_press'}) do
  local original=Controller[method]
  if type(original)=='function' then
    Controller[method]=function(self,...)
      if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Mouse input.') end
      if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged()) then Brainstorm.CollectionSearchProduct.stop('Mouse input.') end
      return original(self,...)
    end
  end
end

local update_ref = Game.update
function Game:update(dt)
  local P=Brainstorm.Advisor and Brainstorm.Advisor.performance
  local frame_start,gap
  if P then frame_start,gap=P:begin_frame(dt) end
  local mark=frame_start
  if Brainstorm.EventCadence then Brainstorm.EventCadence:update(self) end
  update_ref(self, dt)
  if mark then mark=P:finish('game_update',mark) end
  if Brainstorm.Checkpoints then Brainstorm.Checkpoints:update(dt) end
  if mark then mark=P:finish('checkpoint_update',mark) end
  if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.update() end
  if mark then mark=P:finish('search_update',mark) end
  if Brainstorm.Advisor and Brainstorm.Advisor.player_log then
    Brainstorm.Advisor.player_log:install_hooks(G)
    if Brainstorm.ManualLog then Brainstorm.ManualLog:update(G) end
    Brainstorm.Advisor.player_log:update(G)
  end
  if mark then mark=P:finish('journal_update',mark) end
  if not love.keyboard.isDown(Brainstorm.config.keybinds.a_reroll) then Brainstorm.ar_hotkey_down = false end

  if Brainstorm.Advisor then
    if not love.keyboard.isDown("h") then Brainstorm.Advisor.hotkey_down = false end
    Brainstorm.Advisor.update(dt)
  end
  if mark then mark=P:finish('advisor_update',mark) end
  local auto_status
  if Brainstorm.AutoRun then auto_status=Brainstorm.AutoRun:update(dt) end
  if mark then mark=P:finish('auto_update',mark) end

  if Brainstorm.ar_active then
    Brainstorm.ar_frames = Brainstorm.ar_frames + 1
    Brainstorm.ar_timer = Brainstorm.ar_timer + dt

    if Brainstorm.ar_timer >= Brainstorm.AR_INTERVAL then
      Brainstorm.ar_timer = Brainstorm.ar_timer - Brainstorm.AR_INTERVAL
      if Brainstorm.autoReroll() then
        Brainstorm.ar_active = false
        Brainstorm.ar_frames = 0
        if Brainstorm.ar_text then
          Brainstorm.removeAttentionText(Brainstorm.ar_text)
          Brainstorm.ar_text = nil
        end
      end
    end

    if Brainstorm.ar_frames == 60 and not Brainstorm.ar_text then
      local jokerless_progress = Brainstorm.JokerlessOpeningSearch
      jokerless_progress = jokerless_progress and jokerless_progress.searching and jokerless_progress
      Brainstorm.ar_text = Brainstorm.attentionText({
        scale = jokerless_progress and 0.55 or 1.4,
        text = jokerless_progress and {{ref_table = jokerless_progress, ref_value = 'progress_count'}} or "Rerolling...",
        maxw = jokerless_progress and 8 or nil,
        align = "cm",
        offset = { x = 0, y = -3.5 },
        major = G.STAGE == G.STAGES.RUN and G.play or G.title_top,
      })
    end
  end
  if mark then P:finish('legacy_reroll',mark) end
  if frame_start then
    -- Only scalar public flags: no snapshot, status callback or identity copy.
    local g=G or {};local game=g.GAME or {};local settings=g.SETTINGS or {}
    local controller=g.CONTROLLER or {};local advisor=Brainstorm.Advisor
    local flags={paused=settings.paused==true,
      dragging=not not (controller.dragging and controller.dragging.target),
      advisor_worker=not not (advisor and advisor.worker)}
    local function number(key,value)
      if type(value)=='number' and value==value and value~=math.huge and value~=-math.huge then flags[key]=value end
    end
    number('state',g.STATE);number('stage',g.STAGE)
    number('ante',(game.round_resets or {}).ante);number('round',game.round)
    number('game_speed',settings.GAMESPEED)
    if type(auto_status)=='table' and type(auto_status.active)=='boolean' then flags.auto_active=auto_status.active end
    flags.idle_menu=not not (g.STAGES and g.STAGES.MAIN_MENU~=nil and g.STAGE==g.STAGES.MAIN_MENU
      and not Brainstorm.ar_active and not Brainstorm.native_search_busy
      and not (type(auto_status)=='table' and (auto_status.busy or auto_status.active or auto_status.resume_pending)))
    -- update_total excludes the trailing bounded emission; performance_emit
    -- is recorded separately by the collector for the following window.
    P:end_frame(frame_start,gap,flags)
    local manual=advisor and advisor.manual_log
    P:flush(manual and manual:is_active(G) and manual:journal_for(G) or advisor and advisor.player_log,flags)
  end
end

function Brainstorm.autoReroll()
  if Brainstorm.native_search_busy then return nil end
  local valid, validation_message = Brainstorm.validateAutoRerollFilters()
  if not valid then
    if Brainstorm.JokerlessOpeningSearch and Brainstorm.JokerlessOpeningSearch.searching then
      Brainstorm.stopChallengeOpeningSearch('invalidated',validation_message)
    end
    Brainstorm.ar_active = false
    Brainstorm.ar_frames = 0
    if Brainstorm.ar_text then
      Brainstorm.removeAttentionText(Brainstorm.ar_text)
      Brainstorm.ar_text = nil
    end
    saveManagerAlert(validation_message)
    return nil
  end

  if G.GAME.challenge=='c_jokerless_1' and Brainstorm.JokerlessOpeningSearch then
    return Brainstorm.challengeOpeningSearch()
  end
  local seed_found = random_string(
    8,
    G.CONTROLLER.cursor_hover.T.x * 0.33411983
      + G.CONTROLLER.cursor_hover.T.y * 0.874146
      + 0.412311010 * G.CONTROLLER.cursor_hover.time
  )
  if G.GAME.challenge then return Brainstorm.challengeOpeningSearch(seed_found) end
  local search_query = Brainstorm.ar_native_query
    or Brainstorm.refreshAutoRerollQuery()
  if not search_query then
    return nil
  end
  local immolate_lib = ensureImmolateLoaded()
  immolate_lib.brainstorm_set_search_thread_mode(
    Brainstorm.config.ar_prefs.native_cpu_mode == "maximum" and 1 or 0
  )
  local deck_name = getCurrentDeckName()
  local stake_level = getCurrentStakeLevel()
  local raw_result = immolate_lib.brainstorm_v8(
      seed_found,
      search_query.voucher_name,
      search_query.pack_name,
      search_query.tag_name,
      Brainstorm.config.ar_filters.soul_count,
      Brainstorm.config.ar_filters.inst_observatory,
      search_query.observatory_deadline,
      Brainstorm.config.ar_filters.inst_perkeo,
      Brainstorm.config.ar_filters.copy_money,
      Brainstorm.config.ar_filters.retcon,
      Brainstorm.config.ar_filters.bean,
      Brainstorm.config.ar_filters.burglar,
      Brainstorm.config.ar_filters.custom_filter_name,
      search_query.target_rank,
      search_query.target_suit,
      search_query.specific_rank_min,
      search_query.any_rank_min,
      search_query.joker_targets,
      deck_name,
      search_query.joker_target_locations,
      stake_level,
      Brainstorm.config.ar_filters.no_perishable_jokers
    )
  if raw_result ~= nil then
    seed_found = ffi.string(raw_result)
    immolate_lib.free_result(raw_result)
    if seed_found == "" then
      seed_found = nil
    end
  end
  if seed_found then
    local _challenge = G.GAME.challenge and G.GAME.challenge_tab or nil
    G:delete_run()
    G:start_run({
      stake = stake_level,
      seed = seed_found,
      challenge = _challenge,
    })
    G.GAME.used_filter = true
    G.GAME.filter_info = {
      native_api_version = 8,
      stake_level = stake_level,
      soul_count = Brainstorm.config.ar_filters.soul_count,
      required_soul_count = Brainstorm.getRequiredSoulCount(),
      joker_targets = search_query.joker_targets,
      joker_target_locations = search_query.joker_target_locations,
      no_perishable_jokers =
        Brainstorm.config.ar_filters.no_perishable_jokers,
      observatory_deadline = search_query.observatory_deadline,
      deck_name = deck_name,
      multi_soul_pack_consumed = false,
      filter_params = {
        seed_found,
        search_query.voucher_name,
        search_query.pack_name,
        search_query.tag_name,
        Brainstorm.config.ar_filters.soul_count,
        Brainstorm.config.ar_filters.inst_observatory,
        search_query.observatory_deadline,
        Brainstorm.config.ar_filters.inst_perkeo,
        Brainstorm.config.ar_filters.copy_money,
        Brainstorm.config.ar_filters.retcon,
        Brainstorm.config.ar_filters.bean,
        Brainstorm.config.ar_filters.burglar,
        Brainstorm.config.ar_filters.custom_filter_name,
        search_query.target_rank,
        search_query.target_suit,
        search_query.specific_rank_min,
        search_query.any_rank_min,
        search_query.joker_targets,
        deck_name,
        search_query.joker_target_locations,
        stake_level,
        Brainstorm.config.ar_filters.no_perishable_jokers,
      },
    }
    G.GAME.seeded = false
  end
  return seed_found
end

local cursr = create_UIBox_round_scores_row
function create_UIBox_round_scores_row(score, text_colour)
  local ret = cursr(score, text_colour)
  ret.nodes[2].nodes[1].config.colour = (score == "seed" and G.GAME.seeded)
      and G.C.RED
    or (score == "seed" and G.GAME.used_filter) and G.C.BLUE
    or G.C.BLACK
  return ret
end

-- TODO: Rework attention text.
function Brainstorm.attentionText(args)
  args = args or {}
  args.text = args.text or "test"
  args.scale = args.scale or 1
  args.colour = copy_table(args.colour or G.C.WHITE)
  args.hold = (args.hold or 0) + 0.1 * G.SPEEDFACTOR
  args.pos = args.pos or { x = 0, y = 0 }
  args.align = args.align or "cm"
  args.emboss = args.emboss or nil

  args.fade = 1

  if args.cover then
    args.cover_colour = copy_table(args.cover_colour or G.C.RED)
    args.cover_colour_l = copy_table(lighten(args.cover_colour, 0.2))
    args.cover_colour_d = copy_table(darken(args.cover_colour, 0.2))
  else
    args.cover_colour = copy_table(G.C.CLEAR)
  end

  args.uibox_config = {
    align = args.align or "cm",
    offset = args.offset or { x = 0, y = 0 },
    major = args.cover or args.major or nil,
  }

  G.E_MANAGER:add_event(Event({
    trigger = "after",
    delay = 0,
    blockable = false,
    blocking = false,
    func = function()
      args.AT = UIBox({
        T = { args.pos.x, args.pos.y, 0, 0 },
        definition = {
          n = G.UIT.ROOT,
          config = {
            align = args.cover_align or "cm",
            minw = (args.cover and args.cover.T.w or 0.001)
              + (args.cover_padding or 0),
            minh = (args.cover and args.cover.T.h or 0.001)
              + (args.cover_padding or 0),
            padding = 0.03,
            r = 0.1,
            emboss = args.emboss,
            colour = args.cover_colour,
          },
          nodes = {
            {
              n = G.UIT.O,
              config = {
                draw_layer = 1,
                object = DynaText({
                  scale = args.scale,
                  string = args.text,
                  maxw = args.maxw,
                  colours = { args.colour },
                  float = true,
                  shadow = true,
                  silent = not args.noisy,
                  args.scale,
                  pop_in = 0,
                  pop_in_rate = 6,
                  rotate = args.rotate or nil,
                }),
              },
            },
          },
        },
        config = args.uibox_config,
      })
      args.AT.attention_text = true

      args.text = args.AT.UIRoot.children[1].config.object
      args.text:pulse(0.5)

      if args.cover then
        Particles(args.pos.x, args.pos.y, 0, 0, {
          timer_type = "TOTAL",
          timer = 0.01,
          pulse_max = 15,
          max = 0,
          scale = 0.3,
          vel_variation = 0.2,
          padding = 0.1,
          fill = true,
          lifespan = 0.5,
          speed = 2.5,
          attach = args.AT.UIRoot,
          colours = {
            args.cover_colour,
            args.cover_colour_l,
            args.cover_colour_d,
          },
        })
      end
      if args.backdrop_colour then
        args.backdrop_colour = copy_table(args.backdrop_colour)
        Particles(args.pos.x, args.pos.y, 0, 0, {
          timer_type = "TOTAL",
          timer = 5,
          scale = 2.4 * (args.backdrop_scale or 1),
          lifespan = 5,
          speed = 0,
          attach = args.AT,
          colours = { args.backdrop_colour },
        })
      end
      return true
    end,
  }))
  return args
end

function Brainstorm.removeAttentionText(args)
  G.E_MANAGER:add_event(Event({
    trigger = "after",
    delay = 0,
    blockable = false,
    blocking = false,
    func = function()
      if not args.start_time then
        args.start_time = G.TIMERS.TOTAL
        if args.text.pop_out then
          args.text:pop_out(2)
        end
      else
        --args.AT:align_to_attach()
        args.fade = math.max(0, 1 - 3 * (G.TIMERS.TOTAL - args.start_time))
        if args.cover_colour then
          args.cover_colour[4] = math.min(args.cover_colour[4], 2 * args.fade)
        end
        if args.cover_colour_l then
          args.cover_colour_l[4] = math.min(args.cover_colour_l[4], args.fade)
        end
        if args.cover_colour_d then
          args.cover_colour_d[4] = math.min(args.cover_colour_d[4], args.fade)
        end
        if args.backdrop_colour then
          args.backdrop_colour[4] = math.min(args.backdrop_colour[4], args.fade)
        end
        args.colour[4] = math.min(args.colour[4], args.fade)
        if args.fade <= 0 then
          args.AT:remove()
          return true
        end
      end
    end,
  }))
end
