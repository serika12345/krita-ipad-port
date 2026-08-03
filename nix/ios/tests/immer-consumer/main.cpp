#include <immer/vector.hpp>

#include <cstddef>

#if !defined(__aarch64__) && !defined(__arm64__)
#  error "The Krita iOS Immer consumer must compile for arm64"
#endif

static_assert(__cplusplus >= 201402L, "Immer's exported C++14 requirement was not applied");

int main(int argc, char**)
{
    const immer::vector<int> original{1, 2, 3};
    const auto appended = original.push_back(argc);
    const auto changed  = appended.set(0, 7);

    return original.size() == 3 && original[0] == 1 && changed.size() == 4 &&
                   changed[0] == 7 && changed[3] == argc
        ? 0
        : 1;
}
