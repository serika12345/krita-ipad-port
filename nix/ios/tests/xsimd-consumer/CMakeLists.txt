cmake_minimum_required(VERSION 3.20)

project(KritaIOSXsimdConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(xsimd ${KRITA_IOS_XSIMD_VERSION} EXACT CONFIG REQUIRED)

if(NOT TARGET xsimd)
    message(FATAL_ERROR "The installed xsimd package did not define target xsimd")
endif()

get_target_property(xsimd_includes xsimd INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_XSIMD_PREFIX}/include")
list(FIND xsimd_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "xsimd target includes '${xsimd_includes}', expected '${expected_include}'"
    )
endif()

add_executable(krita-ios-xsimd-consumer main.cpp)
target_link_libraries(krita-ios-xsimd-consumer PRIVATE xsimd)
target_compile_features(krita-ios-xsimd-consumer PRIVATE cxx_std_17)

install(TARGETS krita-ios-xsimd-consumer BUNDLE DESTINATION bin)
