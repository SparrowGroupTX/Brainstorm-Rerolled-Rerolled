#ifndef UTIL_HPP
#define UTIL_HPP

#include <cmath>
#include <cstdint>
#include <string>

const uint64_t MAX_UINT64 = 18446744073709551615ull;

typedef union DoubleLong {
  double dbl;
  uint64_t ulong;
} dbllong;

struct LuaRandom {
  uint64_t state[4];
  LuaRandom(double seed);
  LuaRandom();
  uint64_t _randint();
  uint64_t randdblmem();
  double random();
  int randint(int min, int max);
};

#define DBL_EXPO 0x7FF0000000000000
#define DBL_MANT 0x000FFFFFFFFFFFFF

#define DBL_EXPO_SZ 11
#define DBL_MANT_SZ 52

#define DBL_EXPO_BIAS 1023

#if defined(_MSC_VER)
#include <intrin.h>
#pragma intrinsic(_BitScanReverse64)
#endif

int portable_clzll(uint64_t x);
double fract(double x);

// Fast exact fractional part for callers whose value is known to be finite
// and non-negative. For that domain, x - floor(x) is bit-identical to fract()
// (Sterbenz's lemma) and maps directly to hardware rounding on modern CPUs.
// Keep the general fract() helper for values that do not satisfy this contract.
inline double fractPositive(double x) {
#if defined(__SSE4_1__)
  return x - std::floor(x);
#else
  // Baseline x86-64 has no scalar floor instruction. The established bitwise
  // helper is faster there; native builds select the hardware path above.
  return fract(x);
#endif
}

double pseudohash(const std::string &s);
double pseudohash_from(const std::string &s, double num);
double pseudostep(char s, int pos, double num);
const std::string &anteToString(int a);
double round13(double x);
double lua_random_from_seed(double seed);
int lua_randint_from_seed(double seed, int min, int max);

#endif // UTIL_HPP
