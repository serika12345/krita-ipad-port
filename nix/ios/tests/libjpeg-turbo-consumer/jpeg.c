#include <stddef.h>
#include <stdio.h>

#include <jpeglib.h>

int main(void)
{
    struct jpeg_error_mgr error_manager;

    return jpeg_std_error(&error_manager) == &error_manager ? 0 : 1;
}
