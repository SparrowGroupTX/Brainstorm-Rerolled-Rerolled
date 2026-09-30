#ifndef BRAINSTORM_COLLECTION_TARGETS_HPP
#define BRAINSTORM_COLLECTION_TARGETS_HPP

#include "items.hpp"
#include <bitset>

// Visible offers on one prescribed route, not purchases, retention or wins.
struct BrainstormCollectionQuery {
    static constexpr std::size_t size = static_cast<std::size_t>(Item::J_END);
    std::bitset<size> eligible;
    int minimum = 0;
    int firstAnte = 1;
    int lastAnte = 8;
    bool interchangeableCopies = false;

    bool identityMatches(Item requested, Item actual) const {
        return requested == actual || (interchangeableCopies
            && (requested == Item::Blueprint || requested == Item::Brainstorm)
            && (actual == Item::Blueprint || actual == Item::Brainstorm));
    }
    bool active() const { return minimum > 0 || interchangeableCopies; }
};

struct BrainstormCollectionProgress {
    std::bitset<BrainstormCollectionQuery::size> seen;
    int count = 0;

    bool complete(const BrainstormCollectionQuery& query) const {
        return count >= query.minimum;
    }
    void observe(const BrainstormCollectionQuery& query, Item joker, int ante,
                 bool perishable, bool rejectPerishable) {
        // Once the requested count is reached, stop checking other targets.
        if (complete(query) || ante < query.firstAnte || ante > query.lastAnte
            || (rejectPerishable && perishable)) return;
        const auto index = static_cast<std::size_t>(joker);
        if (index < query.size && query.eligible[index] && !seen[index]) {
            seen.set(index);
            ++count;
        }
    }
};

#endif
