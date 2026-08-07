#ifndef BRAINSTORM_SEED_ANCHOR_INDEX_HPP
#define BRAINSTORM_SEED_ANCHOR_INDEX_HPP

#include <cstdint>
#include <vector>

// Returns a validated, strictly increasing list of canonical seed IDs whose
// starting Charm pack can yield Perkeo and Invisible Joker. The list is only
// a priority hint: callers must authoritatively recheck every ID and retain an
// exhaustive fallback when no indexed candidate satisfies the full query.
const std::vector<std::uint64_t>& perkeoInvisibleAnchorCandidateIds();
bool perkeoInvisibleAnchorIndexComplete();

// Narrow child of the index above: the same starting-pack pair followed by an
// exact no-reroll Invisible Joker occurrence in Ante 2.
const std::vector<std::uint64_t>&
perkeoInvisibleAnteTwoInvisibleAnchorCandidateIds();
bool perkeoInvisibleAnteTwoInvisibleAnchorIndexComplete();

// Complete parent index for the reusable rare opening shared by the
// high-ceiling Plasma/Gold route: a skipped-Small-Blind Charm Tag, one Soul
// yielding Perkeo, and Mega Spectral as the first searched shop pack. Every
// candidate is still revalidated against the active query by the caller.
const std::vector<std::uint64_t>&
charmPerkeoMegaSpectralAnchorCandidateIds();
bool charmPerkeoMegaSpectralAnchorIndexComplete();

// Exact child of the parent above for the Plasma/Gold five-Joker route:
// Perkeo in the starting Soul, Blueprint and Brainstorm by Ante 4, then Baron
// and Mime by Ante 8, all at any edition and with no rerolls.
const std::vector<std::uint64_t>&
charmPerkeoMegaNaneinfPlasmaGoldCandidateIds();
bool charmPerkeoMegaNaneinfPlasmaGoldIndexComplete();

#endif
