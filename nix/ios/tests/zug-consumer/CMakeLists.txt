cmake_minimum_required(VERSION 3.20)

project(KritaIOSZugConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(Zug 0.0...<0.1 QUIET CONFIG)
if(Zug_FOUND)
    message(FATAL_ERROR "Zug 0.1.2 incorrectly satisfied range 0.0...<0.1")
endif()
find_package(Zug 0.1...<0.2 CONFIG REQUIRED)
find_package(Zug ${KRITA_IOS_ZUG_VERSION} EXACT CONFIG REQUIRED)

if(DEFINED _ZUG_PREFIX)
    message(FATAL_ERROR "ZugConfig.cmake leaked its private prefix variable")
endif()

if(NOT TARGET zug)
    message(FATAL_ERROR "The installed Zug package did not define target zug")
endif()

get_target_property(zug_type zug TYPE)
if(NOT zug_type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "zug has type '${zug_type}', expected INTERFACE_LIBRARY")
endif()

get_target_property(zug_includes zug INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_ZUG_PREFIX}/include")
list(FIND zug_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "Zug target includes '${zug_includes}', expected '${expected_include}'"
    )
endif()

get_target_property(zug_features zug INTERFACE_COMPILE_FEATURES)
if(NOT "cxx_std_14" IN_LIST zug_features)
    message(FATAL_ERROR "zug features are '${zug_features}', expected cxx_std_14")
endif()

add_executable(krita-ios-zug-consumer main.cpp)
target_link_libraries(krita-ios-zug-consumer PRIVATE zug)
target_compile_features(krita-ios-zug-consumer PRIVATE cxx_std_17)

install(TARGETS krita-ios-zug-consumer BUNDLE DESTINATION bin)
