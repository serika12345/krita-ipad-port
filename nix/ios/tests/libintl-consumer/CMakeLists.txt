cmake_minimum_required(VERSION 3.20)

project(KritaIOSLibintlConsumer LANGUAGES C)

find_package(Intl ${KRITA_IOS_LIBINTL_VERSION} EXACT REQUIRED)
find_library(ICONV_LIBRARY iconv REQUIRED)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)

if(NOT TARGET Intl::Intl)
    message(FATAL_ERROR "FindIntl did not define target Intl::Intl")
endif()
if(NOT Intl_VERSION STREQUAL KRITA_IOS_LIBINTL_VERSION)
    message(
        FATAL_ERROR
        "FindIntl reports version '${Intl_VERSION}', expected '${KRITA_IOS_LIBINTL_VERSION}'"
    )
endif()
if(NOT Intl_LIBRARY STREQUAL "${KRITA_IOS_LIBINTL_PREFIX}/lib/libintl.a")
    message(
        FATAL_ERROR
        "FindIntl selected '${Intl_LIBRARY}', expected the pinned target archive"
    )
endif()
if(NOT Intl_INCLUDE_DIR STREQUAL "${KRITA_IOS_LIBINTL_PREFIX}/include")
    message(
        FATAL_ERROR
        "FindIntl selected '${Intl_INCLUDE_DIR}', expected the pinned target headers"
    )
endif()

add_executable(krita-ios-libintl-consumer main.c)
target_link_libraries(
    krita-ios-libintl-consumer
    PRIVATE
        Intl::Intl
        ${ICONV_LIBRARY}
        ${COREFOUNDATION_FRAMEWORK}
)

install(TARGETS krita-ios-libintl-consumer BUNDLE DESTINATION bin)
