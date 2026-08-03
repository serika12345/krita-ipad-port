#include <exiv2/exiv2.hpp>

#include <cstddef>
#include <cstdint>
#include <string>

int main()
{
    auto image = Exiv2::ImageFactory::create(Exiv2::ImageType::jpeg);
    if (!image || image->imageType() != Exiv2::ImageType::jpeg) {
        return 1;
    }

    Exiv2::ExifData exif;
    exif["Exif.Image.Make"] = "Krita iPad";
    exif["Exif.Image.ImageWidth"] = static_cast<std::uint32_t>(1);
    exif["Exif.Image.ImageLength"] = static_cast<std::uint32_t>(1);
    image->setExifData(exif);
    image->writeMetadata();

    Exiv2::BasicIo &memory = image->io();
    const std::size_t encodedSize = memory.size();
    const Exiv2::byte *encoded = memory.mmap();
    if (encoded == nullptr || encodedSize == 0) {
        return 2;
    }

    auto reopened = Exiv2::ImageFactory::open(encoded, encodedSize);
    reopened->readMetadata();
    const auto make = reopened->exifData().findKey(Exiv2::ExifKey("Exif.Image.Make"));
    if (make == reopened->exifData().end() || make->toString() != "Krita iPad") {
        return 3;
    }

    std::string latin1(1, static_cast<char>(0xe9));
    if (!Exiv2::convertStringCharset(latin1, "ISO-8859-1", "UTF-8")) {
        return 4;
    }

    return Exiv2::versionNumber() == EXIV2_VERSION ? 0 : 5;
}
