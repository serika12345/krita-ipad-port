#include <boost/circular_buffer.hpp>
#include <boost/mp11.hpp>
#include <boost/version.hpp>

#include <type_traits>

using sample_types = boost::mp11::mp_list<int, double, char>;

static_assert(BOOST_VERSION == 108900);
static_assert(boost::mp11::mp_size<sample_types>::value == 3);
static_assert(std::is_same_v<boost::mp11::mp_at_c<sample_types, 1>, double>);

int main()
{
    boost::circular_buffer<int> values(2);
    values.push_back(1);
    values.push_back(2);
    values.push_back(3);

    return values.front() == 2 && values.back() == 3 ? 0 : 1;
}
