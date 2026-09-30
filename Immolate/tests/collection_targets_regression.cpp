// Synthetic observations only: no native seed traversal or source execution.
#include "../src/immolate.cpp"

int main() {
    int checks = 0;
    auto check = [&](bool pass, const char* message) {
        ++checks;
        if (!pass) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
    };
    const std::string us(1, BRAINSTORM_JOKER_TARGET_SEPARATOR);
    check(configureBrainstormCollection("Joker" + us + "Burnt Joker", 2, 3, 8, true), "valid collection");
    auto query = BRAINSTORM_COLLECTION;
    check(query.identityMatches(Item::Blueprint, Item::Brainstorm), "Blueprint can be Brainstorm");
    check(query.identityMatches(Item::Brainstorm, Item::Blueprint), "Brainstorm can be Blueprint");
    check(!query.identityMatches(Item::Brainstorm, Item::Burnt_Joker), "other Joker is not copy");
    query.interchangeableCopies = false;
    check(!query.identityMatches(Item::Brainstorm, Item::Blueprint), "exact mode preserved");
    BrainstormCollectionProgress progress;
    progress.observe(query, Item::Joker, 2, false, true);
    check(progress.count == 0, "before requested Ante excluded");
    progress.observe(query, Item::Joker, 3, true, true);
    check(progress.count == 0, "Perishable excluded");
    progress.observe(query, Item::Joker, 3, false, true);
    progress.observe(query, Item::Joker, 4, false, true);
    check(progress.count == 1, "same Joker counted once across Antes");
    progress.observe(query, Item::Burnt_Joker, 9, false, true);
    check(progress.count == 1, "after deadline excluded");
    progress.observe(query, Item::Burnt_Joker, 8, false, true);
    check(progress.complete(query), "inclusive deadline and count completion");
    query.eligible.set(static_cast<std::size_t>(Item::Perkeo));
    progress.observe(query, Item::Perkeo, 8, false, true);
    check(progress.count == 2 && !progress.seen[static_cast<std::size_t>(Item::Perkeo)], "stop counting at requested total");
    check(!configureBrainstormCollection("Joker" + us + "Joker", 2, 1, 8, false), "duplicate names cannot inflate count");
    check(!configureBrainstormCollection("Joker", 1, 0, 8, false), "invalid first Ante");
    check(!configureBrainstormCollection("Joker", 1, 8, 7, false), "reversed Ante window");
    check(!configureBrainstormCollection("Joker" + us, 1, 1, 8, false), "trailing empty target rejected");
    check(!configureBrainstormCollection("not a joker", 1, 1, 8, false), "unknown target rejected");
    check(configureBrainstormCollection("", 0, 1, 8, true), "zero quota permits pure copy query");

    check(configureBrainstormSearch("", "", "", 0, false, 0, false, false,
        false, false, false, "", "", "", 0, 0, "Brainstorm", "Red Deck",
        "by_ante_5", true, true, 8, true), "normal configuration");
    check(!BRAINSTORM_COLLECTION.active(), "normal configuration clears extension");
    check(configureBrainstormCollection("Joker", 1, 1, 8, true), "collection configuration");
    check(brainstormV5MaximumRequestedAnte() == 8, "quota extends timeline past named target deadline");
    check(brainstormV5TimelineStickerGeneration() == JokerStickerGeneration::EternalPerishableOnly,
        "Gold quota retains Perishable generation");

    JokerData blueprint{}; blueprint.joker = Item::Blueprint;
    JokerData brainstorm{}; brainstorm.joker = Item::Brainstorm;
    JokerData joker{}; joker.joker = Item::Joker;
    BrainstormV5JokerMatcher matcher;
    check(matcher.requirementMatches(0, blueprint, BrainstormJokerObservationSource::AnteFive), "OR match within deadline");
    check(!matcher.requirementMatches(0, blueprint, BrainstormJokerObservationSource::AnteSix), "OR does not weaken deadline");
    blueprint.stickers.perishable = true;
    check(!matcher.requirementMatches(0, blueprint, BrainstormJokerObservationSource::AnteFive), "OR retains no-Perishable guard");
    blueprint.stickers.perishable = false;
    BRAINSTORM_TARGET_JOKER_EDITIONS[0] = BrainstormJokerEditionRequirement::Negative;
    check(!matcher.requirementMatches(0, blueprint, BrainstormJokerObservationSource::AnteFive), "OR retains edition guard");
    blueprint.edition = Item::Negative;
    check(matcher.requirementMatches(0, blueprint, BrainstormJokerObservationSource::AnteFive), "negative OR target accepted");
    BRAINSTORM_TARGET_JOKER_EDITIONS[0] = BrainstormJokerEditionRequirement::Any;

    Seed containerSeed("1");
    Instance instance(containerSeed); // State container only; no random methods run.
    BrainstormV5TimelineState state(instance, JokerStickerGeneration::None);
    BrainstormV5VisibleJokers visible; visible.push_back(blueprint);
    const auto before = brainstormV5PlanVisibleAcquisition(state, visible,
        BrainstormJokerObservationSource::AnteFive, 1);
    check(before.kind != BrainstormV5AcquisitionPlanKind::ImmediateSuccess,
        "named-target success cannot bypass unmet collection quota");
    BrainstormV5VisibleJokers bothCopies = visible; bothCopies.push_back(brainstorm);
    check(brainstormV5PlanVisibleAcquisition(state, bothCopies,
        BrainstormJokerObservationSource::AnteFive, 1).kind == BrainstormV5AcquisitionPlanKind::General,
        "both visible copy identities must branch when future quota depends on locks");
    state.observe(joker, 5);
    const auto after = brainstormV5PlanVisibleAcquisition(state, visible,
        BrainstormJokerObservationSource::AnteFive, 1);
    check(after.kind == BrainstormV5AcquisitionPlanKind::ImmediateSuccess,
        "complete joint comparison can short circuit");
    auto left = state, right = state;
    left.acquireRequirement(0, blueprint);
    right.acquireRequirement(0, brainstorm);
    std::vector<BrainstormV5TimelineState> branches;
    appendBrainstormV5UniqueBranch(branches, left);
    appendBrainstormV5UniqueBranch(branches, right);
    check(branches.size() == 2, "different copy centers preserve independent pool locks");
    appendBrainstormV5UniqueBranch(branches, right);
    check(branches.size() == 2, "exact duplicate branch still deduplicates");
    check(left.complete() && right.complete(), "both complete OR routes accepted");
    check(state.ownedJokerCount == 0, "collection observation does not acquire Joker");
    BRAINSTORM_V9_RUNNING = true;
    BRAINSTORM_V9_DEADLINE = std::chrono::steady_clock::now() - std::chrono::seconds(1);
    check(brainstormV9Stopped(), "expired clock stops recursive timeline");
    BRAINSTORM_V9_DEADLINE = std::chrono::steady_clock::now() + std::chrono::seconds(1);
    brainstorm_cancel_v9();
    check(brainstormV9Stopped(), "explicit cancellation stops recursive timeline");
    BRAINSTORM_V9_RUNNING = false;
    check(!brainstormV9Stopped(), "inactive deadline never affects legacy APIs");
    check(configureBrainstormSearch("", "", "Charm Tag", 2, false, 0,
        false, false, false, false, false, "No Filter", "Kings", "Any Suit",
        0, 0, "Yorick" + us + "Brainstorm" + us + "Burnt Joker" + us + "Perkeo",
        "Red Deck", "soul_pack" + us + "by_ante_5" + us + "by_ante_5" + us + "soul_pack",
        true, true, 8, true), "exact requested four-target slot order is valid");
    check(!BRAINSTORM_V5_ORDERED_MODE, "distinct target slots do not require acquisition order");
    BrainstormV5JokerMatcher four;
    JokerData perkeo{}; perkeo.joker = Item::Perkeo;
    JokerData burnt{}; burnt.joker = Item::Burnt_Joker;
    check(four.requirementMatches(3, perkeo, BrainstormJokerObservationSource::Soul),
        "slot-four Perkeo may be the first Soul");
    check(four.requirementMatches(2, burnt, BrainstormJokerObservationSource::AnteTwo),
        "Burnt may precede Brainstorm");
    std::cout << checks << " synthetic collection/native contract checks passed\n";
}
