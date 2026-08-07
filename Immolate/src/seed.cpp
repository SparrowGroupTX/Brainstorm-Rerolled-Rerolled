#include "seed.hpp"
#include "util.hpp"
#include <iostream>

Seed::Seed() { 
  seed.fill(-1);
  length = 0;
  cacheValid.fill(0);
}

Seed::Seed(std::string strSeed) {
  seed.fill(-1);
  length = strSeed.size();
  cacheValid.fill(0);
  // Note: Assumes this is safe
  for (long unsigned int i = 0; i < strSeed.size(); i++) {
    seed[strSeed.size() - 1 - i] = charSeeds[strSeed[i]];
  }
}

Seed::Seed(long long id) {
  length = 0;
  cacheValid.fill(0);
  for (int i = 0; i < 8; i++) {
    if (id > 0) {
      length++;
      seed[i] = (id - 1) / idCoeff[i];
      id -= 1 + seed[i] * idCoeff[i];
    } else {
      seed[i] = -1;
    }
  }
}

std::string Seed::tostring() {
  std::string strSeed;
  for (int i = 7; i >= 0; i--) {
    if (seed[i] != -1) {
      strSeed.push_back(seedChars[seed[i]]);
    }
  }
  return strSeed;
}

void Seed::debugprint() {
  for (int i = 0; i < 8; i++) {
    std::cout << seed[i] << " ";
  }
  std::cout << std::endl;
}

long long Seed::getID() {
  long long id = 0;
  for (int i = 0; i <= 7; i++) {
    if (seed[i] >= 0) {
      id += idCoeff[i] * seed[i] + 1;
    }
  }
  return id;
}

void Seed::next() {
  if (length < 8) {
    seed[length] = 0;
    length++;
  } else {
    int i = 7;
    while (i >= 0) {
      cacheValid[i] = 0;
      if (seed[i] == 34) {
        seed[i] = -1;
        length--;
      } else {
        seed[i]++;
        break;
      }
      i--;
    }
  }
}

// Not optimized for performance
// I don't think this will need to be implemented in searching
void Seed::next(int x) {
  long long newID = normalizeSeedId(getID() + x);
  *this = Seed(newID);
}

double Seed::pseudohash(int prefixLength) {
  if (length == 0) return 1; //Empty seed edge case

  const int cacheColumn = prefixLength + length - 1;
  const std::uint64_t cacheBit = std::uint64_t{1} << cacheColumn;
  if ((cacheValid[length - 1] & cacheBit) == 0) {
    int i = length - 2;
    while (i >= 0 && (cacheValid[i] & cacheBit) == 0) {
      i--;
    }
    if (i == -1) {
      cache[0][cacheColumn] = pseudostep(
          seedChars[seed[0]], prefixLength + length, 1);
      cacheValid[0] |= cacheBit;
      i = 0;
    }
    for (int j = i+1; j < length; j++) {
      cache[j][cacheColumn] = pseudostep(
          seedChars[seed[j]], prefixLength + length - j,
          cache[j - 1][cacheColumn]);
      cacheValid[j] |= cacheBit;
    }
  }
  return cache[length - 1][cacheColumn];
}
