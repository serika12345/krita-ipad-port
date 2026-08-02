#include <boost/version.hpp>
#include <exiv2/version.hpp>
#include <fontconfig/fontconfig.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <harfbuzz/hb.h>
#include <immer/vector.hpp>
#include <jpeglib.h>
#include <lager/store.hpp>
#include <lcms2.h>
#include <linebreak.h>
#include <png.h>
#include <xsimd/xsimd.hpp>
#include <zug/transduce.hpp>
#include <zlib.h>

#include <Eigen/Core>

int main()
{
    const immer::vector<int> values{1, 2, 3};
    const Eigen::Vector2i size{static_cast<int>(values.size()), BOOST_VERSION};
    const xsimd::batch<float> pixels(1.0F);
    FT_Library freetype = nullptr;
    const auto freetype_result = FT_Init_FreeType(&freetype);
    jpeg_error_mgr jpeg_error{};
    const auto jpeg_handler = jpeg_std_error(&jpeg_error);
    if (freetype != nullptr) {
        FT_Done_FreeType(freetype);
    }
    char breaks[2]{};
    set_linebreaks_utf8(reinterpret_cast<const utf8_t*>("a"), 1, "en", breaks);
    return size.x() == 3 && pixels.get(0) == 1.0F && png_access_version_number() != 0
            && zlibVersion() != nullptr && cmsGetEncodedCMMversion() != 0
            && Exiv2::versionNumber() != 0 && freetype_result == 0
            && jpeg_handler != nullptr
            && hb_version_atleast(1, 0, 0) && FcGetVersion() != 0
        ? 0
        : 1;
}
