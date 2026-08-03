#include <turbojpeg.h>

int main(void)
{
    tjhandle instance = tj3Init(TJINIT_COMPRESS);

    if (instance == NULL) {
        return 1;
    }

    tj3Destroy(instance);
    return 0;
}
