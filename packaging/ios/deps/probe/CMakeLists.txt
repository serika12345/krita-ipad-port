cmake_minimum_required(VERSION 3.24)
project(KritaIOSDependenciesProbe LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${KRITA_SOURCE_DIR}/cmake/modules")

find_package(ZLIB REQUIRED)
find_package(PNG 1.2.6 REQUIRED)
find_package(Boost 1.69 CONFIG REQUIRED)
find_package(Immer CONFIG REQUIRED)
find_package(Zug CONFIG REQUIRED)
find_package(Lager CONFIG REQUIRED)
find_package(Eigen3 CONFIG REQUIRED)
find_package(xsimd CONFIG REQUIRED)
find_package(Threads REQUIRED)
find_package(lcms2 CONFIG REQUIRED)
find_package(exiv2 CONFIG REQUIRED)
find_package(Freetype REQUIRED)
find_package(harfbuzz CONFIG REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Fontconfig REQUIRED IMPORTED_TARGET fontconfig)
find_package(libunibreak 5.0 REQUIRED)
find_package(EXPAT CONFIG REQUIRED)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
find_library(CORETEXT_FRAMEWORK CoreText REQUIRED)
find_library(ICONV_LIBRARY iconv REQUIRED)

add_executable(KritaIOSDependenciesProbe main.cpp)
target_compile_features(KritaIOSDependenciesProbe PRIVATE cxx_std_17)
target_link_libraries(
    KritaIOSDependenciesProbe
    PRIVATE
        ZLIB::ZLIB
        PNG::PNG
        Boost::boost
        Boost::disable_autolinking
        immer
        zug
        lager
        Eigen3::Eigen
        xsimd
        lcms2::lcms2
        Exiv2::exiv2lib
        Freetype::Freetype
        harfbuzz::harfbuzz
        PkgConfig::Fontconfig
        libunibreak::libunibreak
        expat::expat
        ${COREFOUNDATION_FRAMEWORK}
        ${COREGRAPHICS_FRAMEWORK}
        ${CORETEXT_FRAMEWORK}
        ${ICONV_LIBRARY}
)
set_target_properties(
    KritaIOSDependenciesProbe
    PROPERTIES
        MACOSX_BUNDLE TRUE
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
)
