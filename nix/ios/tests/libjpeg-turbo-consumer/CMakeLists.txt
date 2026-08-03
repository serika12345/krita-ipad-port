cmake_minimum_required(VERSION 3.20)

project(KritaIOSLibjpegTurboConsumer LANGUAGES C)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(
    libjpeg-turbo ${KRITA_IOS_LIBJPEG_TURBO_VERSION}
    EXACT
    CONFIG
    REQUIRED
)

function(require_static_import target archive)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "The installed package did not define ${target}")
    endif()

    get_target_property(target_type "${target}" TYPE)
    if(NOT target_type STREQUAL "STATIC_LIBRARY")
        message(FATAL_ERROR "${target} has type '${target_type}', expected STATIC_LIBRARY")
    endif()

    get_target_property(target_location "${target}" IMPORTED_LOCATION_RELEASE)
    if(NOT target_location)
        get_target_property(target_location "${target}" IMPORTED_LOCATION)
    endif()
    set(expected_location "${KRITA_IOS_LIBJPEG_TURBO_PREFIX}/lib/${archive}")
    if(NOT target_location STREQUAL expected_location)
        message(
            FATAL_ERROR
            "${target} resolves to '${target_location}', expected '${expected_location}'"
        )
    endif()

    get_target_property(target_includes "${target}" INTERFACE_INCLUDE_DIRECTORIES)
    set(expected_include "${KRITA_IOS_LIBJPEG_TURBO_PREFIX}/include")
    list(FIND target_includes "${expected_include}" expected_include_index)
    if(expected_include_index EQUAL -1)
        message(
            FATAL_ERROR
            "${target} includes '${target_includes}', expected '${expected_include}'"
        )
    endif()
endfunction()

require_static_import(libjpeg-turbo::jpeg-static libjpeg.a)
require_static_import(libjpeg-turbo::turbojpeg-static libturbojpeg.a)

add_executable(krita-ios-libjpeg-consumer jpeg.c)
target_link_libraries(
    krita-ios-libjpeg-consumer
    PRIVATE
        libjpeg-turbo::jpeg-static
)

add_executable(krita-ios-turbojpeg-consumer turbojpeg.c)
target_link_libraries(
    krita-ios-turbojpeg-consumer
    PRIVATE
        libjpeg-turbo::turbojpeg-static
)

install(
    TARGETS
        krita-ios-libjpeg-consumer
        krita-ios-turbojpeg-consumer
    BUNDLE DESTINATION bin
)
