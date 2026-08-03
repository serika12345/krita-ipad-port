#include <hb-coretext.h>
#include <hb-ft.h>
#include <hb.h>

#include <ft2build.h>
#include FT_FREETYPE_H

namespace
{
hb_font_t *(*volatile createHarfBuzzFont)(FT_Face) = hb_ft_font_create_referenced;
hb_font_t *(*volatile createCoreTextFont)(CTFontRef) = hb_coretext_font_create;
}

int main()
{
    // Taking the function address forces the hb-ft bridge into the link without
    // needing a bundled font or calling it with an invalid FreeType face.
    return createHarfBuzzFont == nullptr || createCoreTextFont == nullptr;
}
