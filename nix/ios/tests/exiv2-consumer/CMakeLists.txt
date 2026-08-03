cmake_minimum_required(VERSION 3.20)

project(KritaIOSExiv2Consumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(
    exiv2 ${KRITA_IOS_EXIV2_VERSION}
    EXACT
    CONFIG
    REQUIRED
)

if(NOT TARGET Exiv2::exiv2lib)
    message(FATAL_ERROR "The installed package did not define Exiv2::exiv2lib")
endif()
if(NOT TARGET exiv2lib)
    message(FATAL_ERROR "The installed package did not define its exiv2lib compatibility alias")
endif()
if(NOT TARGET ZLIB::ZLIB)
    message(FATAL_ERROR "The installed static package did not resolve ZLIB::ZLIB")
endif()

get_target_property(exiv2_type Exiv2::exiv2lib TYPE)
if(NOT exiv2_type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "Exiv2::exiv2lib has type '${exiv2_type}', expected STATIC_LIBRARY")
endif()

get_target_property(exiv2_location Exiv2::exiv2lib IMPORTED_LOCATION_RELEASE)
if(NOT exiv2_location)
    get_target_property(exiv2_location Exiv2::exiv2lib IMPORTED_LOCATION)
endif()
set(expected_location "${KRITA_IOS_EXIV2_PREFIX}/lib/libexiv2.a")
if(NOT exiv2_location STREQUAL expected_location)
    message(
        FATAL_ERROR
        "Exiv2::exiv2lib resolves to '${exiv2_location}', expected '${expected_location}'"
    )
endif()

get_target_property(exiv2_includes Exiv2::exiv2lib INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_EXIV2_PREFIX}/include")
list(FIND exiv2_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "Exiv2::exiv2lib includes '${exiv2_includes}', expected '${expected_include}'"
    )
endif()

get_target_property(exiv2_links Exiv2::exiv2lib INTERFACE_LINK_LIBRARIES)
list(FIND exiv2_links "$<LINK_ONLY:ZLIB::ZLIB>" zlib_link_index)
if(zlib_link_index EQUAL -1)
    message(
        FATAL_ERROR
        "Exiv2::exiv2lib links '${exiv2_links}', expected private ZLIB::ZLIB propagation"
    )
endif()

get_target_property(compatibility_target exiv2lib ALIASED_TARGET)
if(NOT compatibility_target STREQUAL "Exiv2::exiv2lib")
    message(
        FATAL_ERROR
        "exiv2lib aliases '${compatibility_target}', expected Exiv2::exiv2lib"
    )
endif()

add_executable(krita-ios-exiv2-consumer main.cpp)
target_compile_features(krita-ios-exiv2-consumer PRIVATE cxx_std_17)
target_link_libraries(krita-ios-exiv2-consumer PRIVATE Exiv2::exiv2lib)

install(TARGETS krita-ios-exiv2-consumer BUNDLE DESTINATION bin)
