#include <ft2build.h>
#include FT_FREETYPE_H

int main(void)
{
    FT_Library library = NULL;
    if (FT_Init_FreeType(&library) != 0) {
        return 1;
    }

    FT_Done_FreeType(library);
    return 0;
}
