#include <lcms2.h>

int main(void)
{
    cmsHPROFILE profile = cmsCreate_sRGBProfile();
    if (profile == NULL) {
        return 1;
    }

    cmsCloseProfile(profile);
    return 0;
}
