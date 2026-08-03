#include <xsimd/xsimd.hpp>

#include <array>
#include <cstddef>
#include <type_traits>

#if !defined(__aarch64__) && !defined(__arm64__)
#  error "The Krita iOS xsimd consumer must compile for arm64"
#endif

using batch_type = xsimd::batch<float>;

static_assert(xsimd::default_arch::supported(), "xsimd must detect a supported architecture");
static_assert(
    std::is_base_of<xsimd::neon64, xsimd::default_arch>::value,
    "the arm64 iOS xsimd batch must use NEON64");
static_assert(batch_type::size == 4, "an arm64 NEON batch<float> must contain four lanes");

int main(int argc, char **)
{
    std::array<float, batch_type::size> values{};
    std::array<float, batch_type::size> scales{};
    std::array<float, batch_type::size> output{};

    for (std::size_t lane = 0; lane < batch_type::size; ++lane) {
        values[lane] = static_cast<float>(argc) + static_cast<float>(lane);
        scales[lane] = 2.0F;
    }

    const batch_type value_batch = batch_type::load_unaligned(values.data());
    const batch_type scale_batch = batch_type::load_unaligned(scales.data());
    const batch_type result = value_batch * scale_batch + batch_type(1.0F);
    result.store_unaligned(output.data());

    return output[batch_type::size - 1]
                == (static_cast<float>(argc) + static_cast<float>(batch_type::size - 1)) * 2.0F + 1.0F
        ? 0
        : 1;
}
