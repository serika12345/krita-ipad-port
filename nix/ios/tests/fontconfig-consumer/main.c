#include <fontconfig/fontconfig.h>
#include <fontconfig/fcfreetype.h>

#include <stddef.h>

static FcBool (*volatile parse_from_memory)(FcConfig *, const FcChar8 *, FcBool) =
    FcConfigParseAndLoadFromMemory;
static FcChar8 *(*volatile generate_config)(FcConfig *, FcPattern *, const FcChar8 *) =
    FcConfigFileGenerate;
static FcPattern *(*volatile query_freetype)(const FcChar8 *, unsigned int, FcBlanks *, int *) =
    FcFreeTypeQuery;

int main(void)
{
    return parse_from_memory == NULL || generate_config == NULL || query_freetype == NULL;
}
