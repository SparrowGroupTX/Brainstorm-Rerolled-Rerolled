#include <array>
#include <cstdint>
#include <iomanip>
#include <iostream>

namespace {

constexpr std::uint64_t allBits = ~std::uint64_t{0};
constexpr std::uint64_t mantissa = (std::uint64_t{1} << 52) - 1;

std::uint64_t step(std::uint64_t value, int recurrence) {
  switch (recurrence) {
  case 0:
    return (((value << 31) ^ value) >> 45)
        ^ ((value & (allBits << 1)) << 18);
  case 1:
    return (((value << 19) ^ value) >> 30)
        ^ ((value & (allBits << 6)) << 28);
  case 2:
    return (((value << 24) ^ value) >> 48)
        ^ ((value & (allBits << 9)) << 7);
  default:
    return (((value << 21) ^ value) >> 39)
        ^ ((value & (allBits << 17)) << 8);
  }
}

std::uint64_t jump11(std::uint64_t value, int recurrence) {
  for (int iteration = 0; iteration < 11; ++iteration) {
    value = step(value, recurrence);
  }
  return value & mantissa;
}

} // namespace

int main() {
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    std::array<std::uint64_t, 127> masks{};
    for (int inputBit = 0; inputBit < 64; ++inputBit) {
      const std::uint64_t transformed =
          jump11(std::uint64_t{1} << inputBit, recurrence);
      for (int outputBit = 0; outputBit < 52; ++outputBit) {
        if ((transformed & (std::uint64_t{1} << outputBit)) != 0) {
          masks[static_cast<std::size_t>(inputBit - outputBit + 63)]
              |= std::uint64_t{1} << outputBit;
        }
      }
    }
    int termCount = 0;
    std::cout << "recurrence " << recurrence << "\n";
    for (int index = 0; index < 127; ++index) {
      if (masks[static_cast<std::size_t>(index)] == 0) {
        continue;
      }
      ++termCount;
      const int shift = index - 63;
      std::cout << "  " << (shift < 0 ? "L" : "R")
                << std::abs(shift) << " 0x" << std::hex
                << std::setw(16) << std::setfill('0')
                << masks[static_cast<std::size_t>(index)]
                << std::dec << std::setfill(' ') << "\n";
    }
    std::cout << "terms " << termCount << "\n";
  }
}
