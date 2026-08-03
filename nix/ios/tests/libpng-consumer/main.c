#include <png.h>
#include <zlib.h>

int main(void)
{
    return png_access_version_number() == 0 || zlibVersion()[0] == '\0';
}
