#include <zug/transduce.hpp>
#include <zug/transducer/filter.hpp>
#include <zug/transducer/map.hpp>

#include <functional>
#include <vector>

#if !defined(__aarch64__) && !defined(__arm64__)
#  error "The Krita iOS Zug consumer must compile for arm64"
#endif

static_assert(__cplusplus >= 201703L, "The Zug consumer must exercise Krita's C++17 path");

int main(int argc, char**)
{
    const std::vector<int> values{1, 2, argc};
    const auto even = zug::filter([](int value) { return value % 2 == 0; });
    const auto doubled = zug::map([](int value) { return value * 2; });
    const auto result = zug::transduce(
        zug::comp(even, doubled), std::plus<int>{}, 0, values);

    const int expected = 4 + (argc % 2 == 0 ? argc * 2 : 0);
    return result == expected ? 0 : 1;
}
