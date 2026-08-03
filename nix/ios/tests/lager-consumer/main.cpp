#include <lager/event_loop/manual.hpp>
#include <lager/lenses.hpp>
#include <lager/state.hpp>
#include <lager/store.hpp>
#include <lager/watch.hpp>

#include <vector>

#if !defined(__aarch64__) && !defined(__arm64__)
#  error "The Krita iOS Lager consumer must compile for arm64"
#endif

static_assert(__cplusplus >= 201703L,
              "Lager's exported target must enable Krita's C++17 contract");

struct brush_options
{
    int size;
    bool enabled;
};

int main(int argc, char**)
{
    auto options = lager::make_state(
        brush_options{10, true}, lager::automatic_tag{});
    lager::cursor<int> size = options[&brush_options::size];

    int observed_size = 0;
    lager::watch(size, [&](int value) { observed_size = value; });
    size.set(24);

    auto doubled_size = options[&brush_options::size]
                            .zoom(lager::lenses::getset(
                                [](int value) { return value * 2; },
                                [](int, int value) { return value / 2; }))
                            .make();

    auto store = lager::make_store<int>(
        std::vector<int>{1},
        lager::with_manual_event_loop{},
        lager::with_reducer([](std::vector<int> values, int value) {
            values.push_back(value);
            return values;
        }));
    store.dispatch(argc + 1);

    return observed_size == 24 && size.get() == 24
            && doubled_size.get() == 48 && store.get().size() == 2
        ? 0
        : 1;
}
