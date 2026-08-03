cmake_minimum_required(VERSION 3.20)

project(KritaIOSFontconfigConsumer LANGUAGES C)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(PkgConfig REQUIRED)
pkg_check_modules(
    Fontconfig
    REQUIRED
    IMPORTED_TARGET
    "fontconfig=${KRITA_IOS_FONTCONFIG_VERSION}"
)
find_package(EXPAT CONFIG REQUIRED)

add_executable(krita-ios-fontconfig-consumer main.c)
target_link_libraries(
    krita-ios-fontconfig-consumer
    PRIVATE
        PkgConfig::Fontconfig
        expat::expat
)

install(TARGETS krita-ios-fontconfig-consumer BUNDLE DESTINATION bin)
