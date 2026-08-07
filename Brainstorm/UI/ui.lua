local lovely = require("lovely")
local nativefs = require("nativefs")

local tag_list = {
  ["None"] = "",
  ["Uncommon Tag"] = "tag_uncommon",
  ["Rare Tag"] = "tag_rare",
  ["Holographic Tag"] = "tag_holo",
  ["Foil Tag"] = "tag_foil",
  ["Polychrome Tag"] = "tag_polychrome",
  ["Investment Tag"] = "tag_investment",
  ["Voucher Tag"] = "tag_voucher",
  ["Boss Tag"] = "tag_boss",
  ["Charm Tag"] = "tag_charm",
  ["Juggle Tag"] = "tag_juggle",
  ["Double Tag"] = "tag_double",
  ["Coupon Tag"] = "tag_coupon",
  ["Economy Tag"] = "tag_economy",
  ["Skip Tag"] = "tag_skip",
  ["D6 Tag"] = "tag_d_six",
}

local custom_filter_list = {
  ["No Filter"] = "No Filter",
  ["Negative Blueprint"] = "Negative Blueprint",
  ["Negative Perkeo"] = "Negative Perkeo",
  ["N_Perk_Blueprint"] = "N_Perk_Blueprint",
  ["Perkeo Baseball"] = "Perkeo Baseball",
}

local voucher_list = {
  ["None"] = "",
  ["Overstock"] = "v_overstock_norm",
  ["Clearance Sale"] = "v_clearance_sale",
  ["Hone"] = "v_hone",
  ["Reroll Surplus"] = "v_reroll_surplus",
  ["Crystal Ball"] = "v_crystal_ball",
  ["Telescope"] = "v_telescope",
  ["Grabber"] = "v_grabber",
  ["Wasteful"] = "v_wasteful",
  ["Tarot Merchant"] = "v_tarot_merchant",
  ["Planet Merchant"] = "v_planet_merchant",
  ["Seed Money"] = "v_seed_money",
  ["Blank"] = "v_blank",
  ["Magic Trick"] = "v_magic_trick",
  ["Hieroglyph"] = "v_hieroglyph",
  ["Director's Cut"] = "v_directors_cut",
  ["Paint Brush"] = "v_paint_brush",
}
local pack_list = {
  ["None"] = {},
  ["Normal Arcana"] = {
    "p_arcana_normal_1",
    "p_arcana_normal_2",
    "p_arcana_normal_3",
    "p_arcana_normal_4",
  },
  ["Jumbo Arcana"] = { "p_arcana_jumbo_1", "p_arcana_jumbo_2" },
  ["Mega Arcana"] = { "p_arcana_mega_1", "p_arcana_mega_2" },
  ["Normal Celestial"] = {
    "p_celestial_normal_1",
    "p_celestial_normal_2",
    "p_celestial_normal_3",
    "p_celestial_normal_4",
  },
  ["Jumbo Celestial"] = { "p_celestial_jumbo_1", "p_celestial_jumbo_2" },
  ["Mega Celestial"] = { "p_celestial_mega_1", "p_celestial_mega_2" },
  ["Normal Standard"] = {
    "p_standard_normal_1",
    "p_standard_normal_2",
    "p_standard_normal_3",
    "p_standard_normal_4",
  },
  ["Jumbo Standard"] = { "p_standard_jumbo_1", "p_standard_jumbo_2" },
  ["Mega Standard"] = { "p_standard_mega_1", "p_standard_mega_2" },
  ["Normal Buffoon"] = { "p_buffoon_normal_1", "p_buffoon_normal_2" },
  ["Jumbo Buffoon"] = { "p_buffoon_jumbo_1" },
  ["Mega Buffoon"] = { "p_buffoon_mega_1" },
  ["Normal Spectral"] = { "p_spectral_normal_1", "p_spectral_normal_2" },
  ["Jumbo Spectral"] = { "p_spectral_jumbo_1" },
  ["Mega Spectral"] = { "p_spectral_mega_1" },
}
local rank_list = {
  ["2"] = "2",
  ["3"] = "3",
  ["4"] = "4",
  ["5"] = "5",
  ["6"] = "6",
  ["7"] = "7",
  ["8"] = "8",
  ["9"] = "9",
  ["10"] = "10",
  ["Jack"] = "Jack",
  ["Queen"] = "Queen",
  ["King"] = "King",
  ["Ace"] = "Ace",
  ["Kings or Queens"] = "Kings or Queens",
  ["Royals"] = "Royals",
}
local suit_list = {
  ["Any Suit"] = "Any Suit",
  ["Any One Suit"] = "Any One Suit",
  ["Clubs"] = "Clubs",
  ["Diamonds"] = "Diamonds",
  ["Hearts"] = "Hearts",
  ["Spades"] = "Spades",
}

local rank_keys = {
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "10",
  "Jack",
  "Queen",
  "King",
  "Ace",
  "Kings or Queens",
  "Royals",
}
local suit_keys = {
  "Any Suit",
  "Any One Suit",
  "Clubs",
  "Diamonds",
  "Hearts",
  "Spades",
}
local count_keys = {}
for i = 0, 52 do
  count_keys[#count_keys + 1] = tostring(i)
end

local voucher_keys = {
  "None",
  "Overstock",
  "Clearance Sale",
  "Hone",
  "Reroll Surplus",
  "Crystal Ball",
  "Telescope",
  "Grabber",
  "Wasteful",
  "Tarot Merchant",
  "Planet Merchant",
  "Seed Money",
  "Blank",
  "Magic Trick",
  "Hieroglyph",
  "Director's Cut",
  "Paint Brush",
}

local tag_keys = {
  "None",
  "Charm Tag",
  "Double Tag",
  "Uncommon Tag",
  "Rare Tag",
  "Holographic Tag",
  "Foil Tag",
  "Polychrome Tag",
  "Investment Tag",
  "Voucher Tag",
  "Boss Tag",
  "Juggle Tag",
  "Coupon Tag",
  "Economy Tag",
  "Skip Tag",
  "D6 Tag",
}

local custom_filter_keys = {
  "No Filter",
  "Negative Blueprint",
  "Negative Perkeo",
  "N_Perk_Blueprint",
  "Perkeo Baseball"
}
local pack_keys = {
  "None",
  "Normal Arcana",
  "Jumbo Arcana",
  "Mega Arcana",
  "Normal Celestial",
  "Jumbo Celestial",
  "Mega Celestial",
  "Normal Standard",
  "Jumbo Standard",
  "Mega Standard",
  "Normal Buffoon",
  "Jumbo Buffoon",
  "Mega Buffoon",
  "Normal Spectral",
  "Jumbo Spectral",
  "Mega Spectral",
}

local joker_keys = {
  "None",
  "8 Ball",
  "Abstract Joker",
  "Acrobat",
  "Ancient Joker",
  "Arrowhead",
  "Astronomer",
  "Banner",
  "Baron",
  "Baseball Card",
  "Blackboard",
  "Bloodstone",
  "Blue Joker",
  "Blueprint",
  "Bootstraps",
  "Brainstorm",
  "Bull",
  "Burglar",
  "Burnt Joker",
  "Business Card",
  "Canio",
  "Campfire",
  "Card Sharp",
  "Cartomancer",
  "Castle",
  "Cavendish",
  "Ceremonial Dagger",
  "Certificate",
  "Chaos the Clown",
  "Chicot",
  "Clever Joker",
  "Cloud 9",
  "Constellation",
  "Crafty Joker",
  "Crazy Joker",
  "Credit Card",
  "Delayed Gratification",
  "Devious Joker",
  "Diet Cola",
  "DNA",
  "Driver's License",
  "Droll Joker",
  "Drunkard",
  "The Duo",
  "Dusk",
  "Egg",
  "Erosion",
  "Even Steven",
  "Faceless Joker",
  "The Family",
  "Fibonacci",
  "Flash Card",
  "Flower Pot",
  "Fortune Teller",
  "Four Fingers",
  "Gift Card",
  "Glass Joker",
  "Gluttonous Joker",
  "Golden Joker",
  "Greedy Joker",
  "Green Joker",
  "Gros Michel",
  "Hack",
  "Half Joker",
  "Hallucination",
  "Hanging Chad",
  "Hiker",
  "Hit the Road",
  "Hologram",
  "Ice Cream",
  "The Idol",
  "Invisible Joker",
  "Joker",
  "Jolly Joker",
  "Juggler",
  "Loyalty Card",
  "Luchador",
  "Lucky Cat",
  "Lusty Joker",
  "Mad Joker",
  "Madness",
  "Mail-In Rebate",
  "Marble Joker",
  "Matador",
  "Merry Andy",
  "Midas Mask",
  "Mime",
  "Misprint",
  "Mr. Bones",
  "Mystic Summit",
  "Obelisk",
  "Odd Todd",
  "Onyx Agate",
  "Oops! All 6s",
  "The Order",
  "Pareidolia",
  "Perkeo",
  "Photograph",
  "Popcorn",
  "Raised Fist",
  "Ramen",
  "Red Card",
  "Reserved Parking",
  "Ride the Bus",
  "Riff-Raff",
  "Showman",
  "Rocket",
  "Rough Gem",
  "Runner",
  "Satellite",
  "Scary Face",
  "Scholar",
  "Séance",
  "Seeing Double",
  "Seltzer",
  "Shoot the Moon",
  "Shortcut",
  "Sixth Sense",
  "Sly Joker",
  "Smeared Joker",
  "Smiley Face",
  "Sock and Buskin",
  "Space Joker",
  "Splash",
  "Square Joker",
  "Steel Joker",
  "Joker Stencil",
  "Stone Joker",
  "Stuntman",
  "Supernova",
  "Superposition",
  "Swashbuckler",
  "Throwback",
  "Golden Ticket",
  "To the Moon",
  "To Do List",
  "Trading Card",
  "The Tribe",
  "Triboulet",
  "The Trio",
  "Troubadour",
  "Spare Trousers",
  "Turtle Bean",
  "Vagabond",
  "Vampire",
  "Walkie Talkie",
  "Wee Joker",
  "Wily Joker",
  "Wrathful Joker",
  "Yorick",
  "Zany Joker",
}

local joker_key_ids = { [""] = 1, None = 1 }
for i, joker_name in ipairs(joker_keys) do
  joker_key_ids[joker_name] = i
end
local joker_edition_keys = { "Any Edition", "Negative" }
local joker_location_keys = {
  "Ante 1 Early",
  "Starting Charm Pack",
  "By End of Ante 2",
  "By End of Ante 3",
  "By End of Ante 4",
  "By End of Ante 5",
  "By End of Ante 6",
  "By End of Ante 7",
  "By End of Ante 8",
  "Exact Ante 2 (No Rerolls)",
  "Charm Pack or Exact Ante 2",
  "Exact Ante 3 (No Rerolls)",
  "Exact Ante 4 (No Rerolls)",
}
local joker_location_ids = {
  ["Ante 1 Early"] = "ante_1",
  ["Starting Charm Pack"] = "soul_pack",
  ["By End of Ante 2"] = "by_ante_2",
  ["By End of Ante 3"] = "by_ante_3",
  ["By End of Ante 4"] = "by_ante_4",
  ["By End of Ante 5"] = "by_ante_5",
  ["By End of Ante 6"] = "by_ante_6",
  ["By End of Ante 7"] = "by_ante_7",
  ["By End of Ante 8"] = "by_ante_8",
  ["Exact Ante 2 (No Rerolls)"] = "ante_2",
  ["Charm Pack or Exact Ante 2"] = "soul_or_ante_2",
  ["Exact Ante 3 (No Rerolls)"] = "ante_3",
  ["Exact Ante 4 (No Rerolls)"] = "ante_4",
}
local joker_location_option_ids = {
  ante_1 = 1,
  soul_pack = 2,
  by_ante_2 = 3,
  by_ante_3 = 4,
  by_ante_4 = 5,
  by_ante_5 = 6,
  by_ante_6 = 7,
  by_ante_7 = 8,
  by_ante_8 = 9,
  ante_2 = 10,
  soul_or_ante_2 = 11,
  ante_3 = 12,
  ante_4 = 13,
}

local observatory_deadline_keys = {
  "Disabled",
  "By End of Ante 2",
  "By End of Ante 3",
  "By End of Ante 4",
  "By End of Ante 5",
  "By End of Ante 6",
  "By End of Ante 7",
  "By End of Ante 8",
}
local observatory_deadline_values = {
  ["Disabled"] = 0,
  ["By End of Ante 2"] = 2,
  ["By End of Ante 3"] = 3,
  ["By End of Ante 4"] = 4,
  ["By End of Ante 5"] = 5,
  ["By End of Ante 6"] = 6,
  ["By End of Ante 7"] = 7,
  ["By End of Ante 8"] = 8,
}
local native_cpu_mode_keys = { "Balanced", "Maximum" }

G.FUNCS.change_target_voucher = function(x)
  Brainstorm.config.ar_filters.voucher_id = x.to_key
  Brainstorm.config.ar_filters.voucher_name = voucher_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_pack = function(x)
  Brainstorm.config.ar_filters.pack_id = x.to_key
  Brainstorm.config.ar_filters.pack = pack_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_tag = function(x)
  Brainstorm.config.ar_filters.tag_id = x.to_key
  Brainstorm.config.ar_filters.tag_name = tag_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_custom_filter = function(x)
  Brainstorm.config.ar_filters.custom_filter_id = x.to_key
  Brainstorm.config.ar_filters.custom_filter_name = custom_filter_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_rank = function(x)
  Brainstorm.config.ar_filters.rank_id = x.to_key
  Brainstorm.config.ar_filters.rank_name = rank_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_suit = function(x)
  Brainstorm.config.ar_filters.suit_id = x.to_key
  Brainstorm.config.ar_filters.suit_name = suit_list[x.to_val]
  Brainstorm.writeConfig()
end

G.FUNCS.change_target_rank_min = function(x)
  Brainstorm.config.ar_filters.rank_min_id = x.to_key
  Brainstorm.config.ar_filters.rank_min = tonumber(x.to_val) or 0
  Brainstorm.writeConfig()
end

G.FUNCS.change_any_rank_min = function(x)
  Brainstorm.config.ar_filters.any_rank_min_id = x.to_key
  Brainstorm.config.ar_filters.any_rank_min = tonumber(x.to_val) or 0
  Brainstorm.writeConfig()
end

G.FUNCS.change_soul_count = function(x)
  Brainstorm.config.ar_filters.soul_count = tonumber(x.to_val) or 0
  Brainstorm.writeConfig()
end

G.FUNCS.change_observatory_deadline = function(x)
  local deadline = observatory_deadline_values[x.to_val] or 0
  Brainstorm.config.ar_filters.observatory_deadline = deadline
  -- Preserve the legacy flag for old saved-run consumers. The deadline is
  -- authoritative in the v6 native search API.
  Brainstorm.config.ar_filters.inst_observatory = deadline > 0
  Brainstorm.writeConfig()
end

G.FUNCS.change_native_cpu_mode = function(x)
  Brainstorm.config.ar_prefs.native_cpu_mode = x.to_val == "Maximum"
      and "maximum"
    or "balanced"
  Brainstorm.writeConfig()
end

local joker_cycle_configs = {}
local joker_edition_cycle_configs = {}
local joker_location_cycle_configs = {}

local function ensure_joker_target_config(filters)
  filters.joker_targets = type(filters.joker_targets) == "table"
      and filters.joker_targets
    or {}
  filters.joker_target_editions =
    type(filters.joker_target_editions) == "table"
      and filters.joker_target_editions
      or {}
  filters.joker_target_locations =
    type(filters.joker_target_locations) == "table"
      and filters.joker_target_locations
      or {}
  for i = 1, 5 do
    if type(filters.joker_targets[i]) ~= "string" then
      filters.joker_targets[i] = ""
    end
    if
      filters.joker_targets[i] == ""
      or filters.joker_target_editions[i] ~= "Negative"
    then
      filters.joker_target_editions[i] = "Any Edition"
    end
    if
      filters.joker_targets[i] == ""
      or not joker_location_option_ids[filters.joker_target_locations[i]]
    then
      filters.joker_target_locations[i] = "ante_1"
    end
  end
end

local function reset_joker_target_edition(filters, slot)
  filters.joker_target_editions[slot] = "Any Edition"
  local edition_cycle = joker_edition_cycle_configs[slot]
  if edition_cycle then
    edition_cycle.current_option = 1
    edition_cycle.current_option_val = "Any Edition"
  end
end

local function reset_joker_target_location(filters, slot)
  filters.joker_target_locations[slot] = "ante_1"
  local location_cycle = joker_location_cycle_configs[slot]
  if location_cycle then
    location_cycle.current_option = 1
    location_cycle.current_option_val = "Ante 1 Early"
  end
end

for slot = 1, 5 do
  local target_slot = slot
  G.FUNCS["change_target_joker_" .. target_slot] = function(x)
    local filters = Brainstorm.config.ar_filters
    ensure_joker_target_config(filters)

    local target_name = x.to_val == "None" and "" or x.to_val
    filters.joker_targets[target_slot] = target_name
    if target_name == "" then
      reset_joker_target_edition(filters, target_slot)
      reset_joker_target_location(filters, target_slot)
    end
    Brainstorm.writeConfig()
  end

  G.FUNCS["change_target_joker_edition_" .. target_slot] = function(x)
    local filters = Brainstorm.config.ar_filters
    ensure_joker_target_config(filters)
    if filters.joker_targets[target_slot] == "" then
      reset_joker_target_edition(filters, target_slot)
    else
      filters.joker_target_editions[target_slot] = x.to_val == "Negative"
          and "Negative"
        or "Any Edition"
    end
    Brainstorm.writeConfig()
  end

  G.FUNCS["change_target_joker_location_" .. target_slot] = function(x)
    local filters = Brainstorm.config.ar_filters
    ensure_joker_target_config(filters)
    if filters.joker_targets[target_slot] == "" then
      reset_joker_target_location(filters, target_slot)
    else
      filters.joker_target_locations[target_slot] =
        joker_location_ids[x.to_val] or "ante_1"
    end
    Brainstorm.writeConfig()
  end
end

local function create_brainstorm_column(nodes)
  return {
    n = G.UIT.C,
    config = {
      align = "cm",
      padding = 0.05,
      r = 0.1,
      colour = darken(G.C.UI.TRANSPARENT_DARK, 0.25),
    },
    nodes = nodes,
  }
end

local function create_search_page()
  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      create_brainstorm_column({
        create_option_cycle({
          label = "AR: TAG SEARCH",
          scale = 0.8,
          w = 4,
          options = tag_keys,
          opt_callback = "change_target_tag",
          current_option = Brainstorm.config.ar_filters.tag_id or 1,
        }),
        create_option_cycle({
          label = "AR: CUSTOM FILTERS",
          scale = 0.8,
          w = 4,
          options = custom_filter_keys,
          opt_callback = "change_target_custom_filter",
          current_option = Brainstorm.config.ar_filters.custom_filter_id or 1,
        }),
        create_option_cycle({
          label = "AR: VOUCHER SEARCH",
          scale = 0.8,
          w = 4,
          options = voucher_keys,
          opt_callback = "change_target_voucher",
          current_option = Brainstorm.config.ar_filters.voucher_id or 1,
        }),
      }),
      create_brainstorm_column({
        create_option_cycle({
          label = "AR: PACK SEARCH",
          scale = 0.8,
          w = 4,
          options = pack_keys,
          opt_callback = "change_target_pack",
          current_option = Brainstorm.config.ar_filters.pack_id or 1,
        }),
        create_option_cycle({
          label = "MIN SOULS IN CHARM PACK",
          scale = 0.8,
          w = 4,
          options = { 0, 1, 2, 3, 4 },
          opt_callback = "change_soul_count",
          current_option = (Brainstorm.config.ar_filters.soul_count or 0) + 1,
        }),
      }),
    },
  }
end

local function create_cards_page()
  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      create_brainstorm_column({
        create_option_cycle({
          label = "AR: TARGET RANK",
          scale = 0.8,
          w = 4,
          options = rank_keys,
          opt_callback = "change_target_rank",
          current_option = Brainstorm.config.ar_filters.rank_id or 12,
        }),
        create_option_cycle({
          label = "AR: TARGET SUIT",
          scale = 0.8,
          w = 4,
          options = suit_keys,
          opt_callback = "change_target_suit",
          current_option = Brainstorm.config.ar_filters.suit_id or 1,
        }),
        create_option_cycle({
          label = "AR: MIN TARGET COUNT",
          scale = 0.8,
          w = 4,
          options = count_keys,
          opt_callback = "change_target_rank_min",
          current_option = Brainstorm.config.ar_filters.rank_min_id or 1,
        }),
        create_option_cycle({
          label = "AR: MIN ANY RANK",
          scale = 0.8,
          w = 4,
          options = count_keys,
          opt_callback = "change_any_rank_min",
          current_option = Brainstorm.config.ar_filters.any_rank_min_id or 1,
        }),
      }),
    },
  }
end

local function create_joker_target_cycle(slot)
  local targets = Brainstorm.config.ar_filters.joker_targets or {}
  local cycle_config = {
    label = "TARGET JOKER " .. slot,
    scale = 0.64,
    w = 4.6,
    options = joker_keys,
    opt_callback = "change_target_joker_" .. slot,
    current_option = joker_key_ids[targets[slot] or ""] or 1,
    no_pips = true,
  }
  joker_cycle_configs[slot] = cycle_config
  return create_option_cycle(cycle_config)
end

local function create_joker_edition_cycle(slot)
  local editions = Brainstorm.config.ar_filters.joker_target_editions or {}
  local cycle_config = {
    label = "EDITION " .. slot,
    scale = 0.64,
    w = 2.4,
    options = joker_edition_keys,
    opt_callback = "change_target_joker_edition_" .. slot,
    current_option = editions[slot] == "Negative" and 2 or 1,
    no_pips = true,
  }
  joker_edition_cycle_configs[slot] = cycle_config
  return create_option_cycle(cycle_config)
end

local function create_joker_location_cycle(slot)
  local locations =
    Brainstorm.config.ar_filters.joker_target_locations or {}
  local cycle_config = {
    label = "WHEN JOKER " .. slot .. " APPEARS",
    scale = 0.64,
    w = 7,
    options = joker_location_keys,
    opt_callback = "change_target_joker_location_" .. slot,
    current_option = joker_location_option_ids[locations[slot]] or 1,
    no_pips = true,
  }
  joker_location_cycle_configs[slot] = cycle_config
  return create_option_cycle(cycle_config)
end

local function create_joker_target_row(slot)
  return {
    n = G.UIT.R,
    config = { align = "cm", padding = 0.01 },
    nodes = {
      create_joker_target_cycle(slot),
      create_joker_edition_cycle(slot),
    },
  }
end

local function create_jokers_page(first_slot, last_slot)
  joker_cycle_configs = {}
  joker_edition_cycle_configs = {}
  joker_location_cycle_configs = {}
  local target_rows = {}
  for slot = first_slot, last_slot do
    target_rows[#target_rows + 1] = create_joker_target_row(slot)
    target_rows[#target_rows + 1] = create_joker_location_cycle(slot)
  end

  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      create_brainstorm_column(target_rows),
    },
  }
end

local function create_jokers_one_to_two_page()
  return create_jokers_page(1, 2)
end

local function create_jokers_three_to_four_page()
  return create_jokers_page(3, 4)
end

local function create_joker_five_page()
  return create_jokers_page(5, 5)
end

G.FUNCS.run_brainstorm_search_estimate = function()
  Brainstorm.requestSearchEstimate()
end

local function create_estimate_text_row(ref_value, scale, colour, shadow)
  return {
    n = G.UIT.R,
    config = { align = "cm", minh = 0.28, padding = 0.01 },
    nodes = {
      {
        n = G.UIT.T,
        config = {
          ref_table = Brainstorm.search_estimate,
          ref_value = ref_value,
          scale = scale,
          colour = colour,
          shadow = shadow,
        },
      },
    },
  }
end

local function create_estimate_page()
  Brainstorm.ensureSearchEstimateCurrent()
  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      create_brainstorm_column({
        {
          n = G.UIT.C,
          config = {
            align = "cm",
            minw = 7.2,
            minh = 3.1,
            padding = 0.1,
            r = 0.1,
            colour = darken(G.C.BLUE, 0.35),
            emboss = 0.05,
          },
          nodes = {
            {
              n = G.UIT.R,
              config = { align = "cm", minh = 0.25 },
              nodes = {
                {
                  n = G.UIT.T,
                  config = {
                    text = "SELECTED CONFIGURATION",
                    scale = 0.34,
                    colour = G.C.UI.TEXT_LIGHT,
                  },
                },
              },
            },
            create_estimate_text_row(
              "headline",
              0.5,
              G.C.WHITE,
              true
            ),
            create_estimate_text_row(
              "detail",
              0.34,
              G.C.UI.TEXT_LIGHT,
              false
            ),
            create_estimate_text_row(
              "method_line",
              0.3,
              G.C.UI.TEXT_LIGHT,
              false
            ),
            create_estimate_text_row(
              "sample_line",
              0.3,
              G.C.UI.TEXT_LIGHT,
              false
            ),
            create_estimate_text_row(
              "speed_line",
              0.3,
              G.C.UI.TEXT_LIGHT,
              false
            ),
            create_estimate_text_row(
              "evidence_line",
              0.29,
              G.C.UI.TEXT_LIGHT,
              false
            ),
            create_estimate_text_row(
              "note_line",
              0.27,
              G.C.ORANGE,
              false
            ),
            create_estimate_text_row(
              "warning_line",
              0.27,
              G.C.RED,
              true
            ),
          },
        },
        UIBox_button({
          label = { "ESTIMATE SEARCH TIME (~1 SEC)" },
          button = "run_brainstorm_search_estimate",
          colour = G.C.RED,
          minw = 6.8,
          minh = 0.8,
          scale = 0.4,
          focus_args = { snap_to = true },
        }),
      }),
    },
  }
end

local function create_native_search_info()
  return {
    n = G.UIT.C,
    config = {
      align = "cm",
      minw = 4,
      minh = 1.05,
      padding = 0.08,
      r = 0.1,
      colour = darken(G.C.BLUE, 0.35),
    },
    nodes = {
      {
        n = G.UIT.R,
        config = { align = "cm", minh = 0.28 },
        nodes = {
          {
            n = G.UIT.T,
            config = {
              text = "NATIVE SEARCH RUNS OUTSIDE LUA",
              scale = 0.32,
              colour = G.C.WHITE,
              shadow = true,
            },
          },
        },
      },
      {
        n = G.UIT.R,
        config = { align = "cm", minh = 0.24 },
        nodes = {
          {
            n = G.UIT.T,
            config = {
              text = "Maximum is faster but reduces responsiveness",
              scale = 0.25,
              colour = G.C.UI.TEXT_LIGHT,
            },
          },
        },
      },
    },
  }
end

local function create_advanced_page()
  local observatory_deadline =
    tonumber(Brainstorm.config.ar_filters.observatory_deadline) or 0
  local observatory_deadline_option = observatory_deadline >= 2
      and observatory_deadline <= 8
      and math.floor(observatory_deadline)
    or 1

  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      create_brainstorm_column({
        create_option_cycle({
          label = "OBSERVATORY DEADLINE",
          scale = 0.8,
          w = 4,
          options = observatory_deadline_keys,
          opt_callback = "change_observatory_deadline",
          current_option = observatory_deadline_option,
          no_pips = true,
        }),
        create_option_cycle({
          label = "NATIVE CPU MODE",
          scale = 0.8,
          w = 4,
          options = native_cpu_mode_keys,
          opt_callback = "change_native_cpu_mode",
          current_option =
            Brainstorm.config.ar_prefs.native_cpu_mode == "maximum" and 2
              or 1,
          no_pips = true,
        }),
        create_native_search_info(),
        create_toggle({
          label = "EARLY COPY + MONEY",
          scale = 0.8,
          ref_table = Brainstorm.config.ar_filters,
          ref_value = "copy_money",
          callback = function(_set_toggle)
            Brainstorm.writeConfig()
          end,
        }),
      }),
      create_brainstorm_column({
        create_toggle({
          label = "EARLY RETCON",
          scale = 0.8,
          ref_table = Brainstorm.config.ar_filters,
          ref_value = "retcon",
          callback = function(_set_toggle)
            Brainstorm.writeConfig()
          end,
        }),
        create_toggle({
          label = "ANTE 8 BEAN",
          scale = 0.8,
          ref_table = Brainstorm.config.ar_filters,
          ref_value = "bean",
          callback = function(_set_toggle)
            Brainstorm.writeConfig()
          end,
        }),
        create_toggle({
          label = "LATE BURGLAR",
          scale = 0.8,
          ref_table = Brainstorm.config.ar_filters,
          ref_value = "burglar",
          callback = function(_set_toggle)
            Brainstorm.writeConfig()
          end,
        }),
      }),
    },
  }
end

local brainstorm_page_labels = {
  "Search",
  "Cards",
  "Jokers 1-2",
  "Jokers 3-4",
  "Joker 5",
  "Estimate",
  "Advanced",
}
local brainstorm_page_builders = {
  create_search_page,
  create_cards_page,
  create_jokers_one_to_two_page,
  create_jokers_three_to_four_page,
  create_joker_five_page,
  create_estimate_page,
  create_advanced_page,
}
local brainstorm_page_index = 1
local brainstorm_page_holder_id = "brainstorm_reroll_page_contents"

G.FUNCS.change_brainstorm_page = function(args)
  if not args or not args.cycle_config then
    return
  end

  local page_index = tonumber(args.cycle_config.current_option) or 1
  if not brainstorm_page_builders[page_index] then
    page_index = 1
  end
  brainstorm_page_index = page_index

  if not G.OVERLAY_MENU then
    return
  end
  local page_holder = G.OVERLAY_MENU:get_UIE_by_ID(brainstorm_page_holder_id)
  if not page_holder then
    return
  end

  if page_holder.config.object then
    page_holder.config.object:remove()
  end
  page_holder.config.object = UIBox({
    definition = brainstorm_page_builders[page_index](),
    config = {
      offset = { x = 0, y = 0 },
      align = "cm",
      parent = page_holder,
    },
  })
  page_holder.UIBox:recalculate()
end

local function create_brainstorm_tab()
  G.E_MANAGER:add_event(Event({
    func = function()
      G.FUNCS.change_brainstorm_page({
        cycle_config = { current_option = brainstorm_page_index },
      })
      return true
    end,
  }))

  return {
    n = G.UIT.ROOT,
    config = {
      align = "cm",
      padding = 0.05,
      colour = G.C.CLEAR,
    },
    nodes = {
      {
        n = G.UIT.C,
        config = { align = "cm", padding = 0.02 },
        nodes = {
          {
            n = G.UIT.R,
            config = { align = "cm", minh = 5.7, minw = 8 },
            nodes = {
              {
                n = G.UIT.O,
                config = {
                  id = brainstorm_page_holder_id,
                  object = Moveable(),
                },
              },
            },
          },
          {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.02 },
            nodes = {
              create_option_cycle({
                id = "brainstorm_reroll_page_cycle",
                scale = 0.75,
                h = 0.4,
                w = 4.8,
                options = brainstorm_page_labels,
                opt_callback = "change_brainstorm_page",
                current_option = brainstorm_page_index,
                colour = G.C.RED,
                no_pips = true,
                focus_args = { snap_to = true },
              }),
            },
          },
        },
      },
    },
  }
end

Brainstorm.opt_ref = G.FUNCS.options
G.FUNCS.options = function(e)
  Brainstorm.opt_ref(e)
end

local ct = create_tabs
function create_tabs(args)
  if args and args.tab_h == 7.05 then
    args.tabs[#args.tabs + 1] = {
      label = "Brainstorm",
      tab_definition_function = create_brainstorm_tab,
      tab_definition_function_args = "Brainstorm",
    }
  end
  return ct(args)
end
