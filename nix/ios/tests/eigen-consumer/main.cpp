#include <Eigen/Core>

int main()
{
    const Eigen::Vector2i value{1, 2};
    return value.squaredNorm() == 5 ? 0 : 1;
}
