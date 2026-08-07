#include "util.hpp"
#include <array>
#include <cstring>
#include <limits>

namespace {
constexpr uint64_t luaRandomAdvanceWord(uint64_t z, int recurrence) {
  switch (recurrence) {
  case 0:
    return (((z << 31ull) ^ z) >> 45ull) ^
           ((z & (MAX_UINT64 << 1ull)) << 18ull);
  case 1:
    return (((z << 19ull) ^ z) >> 30ull) ^
           ((z & (MAX_UINT64 << 6ull)) << 28ull);
  case 2:
    return (((z << 24ull) ^ z) >> 48ull) ^
           ((z & (MAX_UINT64 << 9ull)) << 7ull);
  default:
    return (((z << 21ull) ^ z) >> 39ull) ^
           ((z & (MAX_UINT64 << 17ull)) << 8ull);
  }
}

uint64_t luaRandomAdvance(uint64_t state[4]) {
  uint64_t z = 0;
  uint64_t r = 0;
  z = state[0];
  z = luaRandomAdvanceWord(z, 0);
  r ^= z;
  state[0] = z;
  z = state[1];
  z = luaRandomAdvanceWord(z, 1);
  r ^= z;
  state[1] = z;
  z = state[2];
  z = luaRandomAdvanceWord(z, 2);
  r ^= z;
  state[2] = z;
  z = state[3];
  z = luaRandomAdvanceWord(z, 3);
  r ^= z;
  state[3] = z;
  return r;
}

// Each Tausworthe word advances independently and the recurrence is linear
// over GF(2). Precomputing the contribution of each input byte after the 11
// advances needed by Lua's first random() call replaces 44 dependent shift/
// xor chains with 32 compact table lookups. The table is constexpr, so it is
// emitted directly in the DLL and has no startup construction cost.
using LuaRandomJump11Table =
    std::array<std::array<std::array<uint64_t, 256>, 8>, 4>;

constexpr LuaRandomJump11Table buildLuaRandomJump11Table() {
  LuaRandomJump11Table table{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int bytePosition = 0; bytePosition < 8; ++bytePosition) {
      for (int byteValue = 0; byteValue < 256; ++byteValue) {
        uint64_t value = static_cast<uint64_t>(byteValue)
                         << (bytePosition * 8);
        for (int step = 0; step < 11; ++step) {
          value = luaRandomAdvanceWord(value, recurrence);
        }
        table[recurrence][bytePosition][byteValue] = value;
      }
    }
  }
  return table;
}

alignas(64) constexpr LuaRandomJump11Table LUA_RANDOM_JUMP_11 =
    buildLuaRandomJump11Table();

inline uint64_t luaRandomJump11(uint64_t value, int recurrence) {
  uint64_t result = 0;
  for (int bytePosition = 0; bytePosition < 8; ++bytePosition) {
    result ^= LUA_RANDOM_JUMP_11[recurrence][bytePosition][value & 0xffu];
    value >>= 8u;
  }
  return result;
}

void luaRandomInit(double seed, uint64_t state[4]) {
  double d = seed;
  uint64_t r = 0x11090601;
  for (int i = 0; i < 4; i++) {
    uint64_t m = 1ull << (r & 255);
    r >>= 8;
    d = d * 3.14159265358979323846 + 2.7182818284590452354;
    dbllong u;
    u.dbl = d;
    if (u.ulong < m)
      u.ulong += m;
    state[i] = u.ulong;
  }
}
} // namespace

LuaRandom::LuaRandom(double seed) {
  luaRandomInit(seed, state);
  for (int i = 0; i < 10; i++) {
    _randint();
  }
}

LuaRandom::LuaRandom() : LuaRandom(0) {}

uint64_t LuaRandom::_randint() {
  return luaRandomAdvance(state);
}

uint64_t LuaRandom::randdblmem() {
  return (_randint() & 4503599627370495ull) | 4607182418800017408ull;
}

double LuaRandom::random() {
  dbllong u;
  u.ulong = randdblmem();
  return u.dbl - 1.0;
}

int LuaRandom::randint(int min, int max) {
  return (int)(random() * (max - min + 1)) + min;
}

double lua_random_from_seed(double seed) {
  uint64_t state[4];
  luaRandomInit(seed, state);
  uint64_t result = 0;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    result ^= luaRandomJump11(state[recurrence], recurrence);
  }
  dbllong u;
  u.ulong = (result & 4503599627370495ull) | 4607182418800017408ull;
  return u.dbl - 1.0;
}

int lua_randint_from_seed(double seed, int min, int max) {
  return (int)(lua_random_from_seed(seed) * (max - min + 1)) + min;
}

int portable_clzll(uint64_t x) {
  if (x == 0)
    return 64; // Undefined for 0, by convention we return 64

#if defined(__GNUC__) || defined(__clang__)
  return __builtin_clzll(x);
#elif defined(_MSC_VER)
  unsigned long index;
  if (_BitScanReverse64(&index, x)) {
    return 63 - index;
  }
  return 64;
#else
  // Fallback for other compilers (manual bit manipulation)
  int n = 0;
  if (x <= 0x00000000FFFFFFFF) {
    n += 32;
    x <<= 32;
  }
  if (x <= 0x0000FFFFFFFFFFFF) {
    n += 16;
    x <<= 16;
  }
  if (x <= 0x00FFFFFFFFFFFFFF) {
    n += 8;
    x <<= 8;
  }
  if (x <= 0x0FFFFFFFFFFFFFFF) {
    n += 4;
    x <<= 4;
  }
  if (x <= 0x3FFFFFFFFFFFFFFF) {
    n += 2;
    x <<= 2;
  }
  if (x <= 0x7FFFFFFFFFFFFFFF) {
    n += 1;
  }
  return n;
#endif
}

double fract(double x) {
  uint64_t x_int;

  std::memcpy(&x_int, &x, sizeof(x_int));

  uint64_t expo = (x_int & DBL_EXPO) >> DBL_MANT_SZ;
  if (expo < DBL_EXPO_BIAS) {
    return x;
  }
  if (expo == ((1 << DBL_EXPO_SZ) - 1)) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  uint64_t expo_biased = expo - DBL_EXPO_BIAS;
  if (expo_biased >= DBL_MANT_SZ) {
    return 0;
  }
  uint64_t mant = x_int & DBL_MANT;
  uint64_t frac_mant = mant & ((1ull << (DBL_MANT_SZ - expo_biased)) - 1);
  if (frac_mant == 0) {
    return 0;
  }
  uint64_t frac_lzcnt = portable_clzll(frac_mant) - (64 - DBL_MANT_SZ);
  uint64_t res_expo = (expo - frac_lzcnt - 1) << DBL_MANT_SZ;
  uint64_t res_mant = (frac_mant << (frac_lzcnt + 1)) & DBL_MANT;
  uint64_t res = res_expo | res_mant;

  double result;
  std::memcpy(&result, &res, sizeof(result));
  return result;
}

double pseudohash(const std::string &s) {
  double num = 1;
  for (size_t i = s.length(); i > 0; i--) {
    num = fract(1.1239285023 / num * s[i - 1] * 3.141592653589793116 +
                3.141592653589793116 * i);
  }
  return num;
}

double pseudohash_from(const std::string &s, double num) {
  // Internal RNG keys are non-empty positive ASCII strings, and their input
  // is a finite non-negative seed pseudohash. The resulting expression stays
  // in fractPositive's exact domain on every production call.
  for (size_t i = s.length(); i > 0; i--) {
    num = fractPositive(
        1.1239285023 / num * s[i - 1] * 3.141592653589793116 +
        3.141592653589793116 * i);
  }
  return num;
}

double pseudostep(char s, int pos, double num) {
  // Seed characters and positions are positive ASCII/integer values, and the
  // prior seed hash is finite and non-negative.
  return fractPositive(
      1.1239285023 / num * s * 3.141592653589793116 +
      3.141592653589793116 * pos);
}

const std::string &anteToString(int a) {
  static const std::array<std::string, 100> cached = []() {
    std::array<std::string, 100> values;
    for (int i = 0; i < 100; ++i) {
      if (i < 10) {
        values[i] = {(char)(0x30 + i)};
      } else {
        values[i] = {(char)(0x30 + i / 10), (char)(0x30 + i % 10)};
      }
    }
    return values;
  }();

  if (a >= 0 && a < static_cast<int>(cached.size())) {
    return cached[a];
  }

  static thread_local std::string fallback;
  fallback.clear();
  if (a < 10) {
    fallback.push_back((char)(0x30 + a));
  } else {
    fallback.push_back((char)(0x30 + a / 10));
    fallback.push_back((char)(0x30 + a % 10));
  }
  return fallback;
}

const double inv_prec = std::pow(10.0, 13);
const double two_inv_prec = std::pow(2.0, 13);
const double five_inv_prec = std::pow(5.0, 13);

double round13(double x) {
  double normal_case = std::round(x * inv_prec) / inv_prec;
  if (normal_case ==
      (std::round(std::nextafter(x, -1) * inv_prec) / inv_prec)) {
    return normal_case;
  }
  double truncated = fract(x * two_inv_prec) * five_inv_prec;
  if (fract(truncated) >= 0.5) {
    return (std::floor(x * inv_prec) + 1) / inv_prec;
  }
  return std::floor(x * inv_prec) / inv_prec;
}
