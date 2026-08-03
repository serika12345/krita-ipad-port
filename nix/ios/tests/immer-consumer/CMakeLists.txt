cmake_minimum_required(VERSION 3.20)

project(KritaIOSImmerConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(Immer 0.8...<0.9 QUIET CONFIG)
if(Immer_FOUND)
    message(FATAL_ERROR "Immer 0.9.1 incorrectly satisfied range 0.8...<0.9")
endif()
find_package(Immer 0.9...<0.10 CONFIG REQUIRED)
find_package(Immer ${KRITA_IOS_IMMER_VERSION} EXACT CONFIG REQUIRED)

if(DEFINED _IMMER_PREFIX)
    message(FATAL_ERROR "ImmerConfig.cmake leaked its private prefix variable")
endif()

if(NOT TARGET immer)
    message(FATAL_ERROR "The installed Immer package did not define target immer")
endif()

get_target_property(immer_type immer TYPE)
if(NOT immer_type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "immer has type '${immer_type}', expected INTERFACE_LIBRARY")
endif()

get_target_property(immer_includes immer INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_IMMER_PREFIX}/include")
list(FIND immer_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "Immer target includes '${immer_includes}', expected '${expected_include}'"
    )
endif()

get_target_property(immer_features immer INTERFACE_COMPILE_FEATURES)
if(NOT "cxx_std_14" IN_LIST immer_features)
    message(FATAL_ERROR "immer features are '${immer_features}', expected cxx_std_14")
endif()

add_executable(krita-ios-immer-consumer main.cpp)
target_link_libraries(krita-ios-immer-consumer PRIVATE immer)

install(TARGETS krita-ios-immer-consumer BUNDLE DESTINATION bin)
