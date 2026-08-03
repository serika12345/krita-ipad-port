cmake_minimum_required(VERSION 3.24)

project(KritaIOSLagerConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(Lager 0.0...<0.1 QUIET CONFIG)
if(Lager_FOUND)
    message(FATAL_ERROR "Lager 0.1.3 incorrectly satisfied range 0.0...<0.1")
endif()
find_package(Lager 0.1...<0.2 CONFIG REQUIRED)
find_package(Lager ${KRITA_IOS_LAGER_VERSION} EXACT CONFIG REQUIRED)

foreach(private_variable IN ITEMS _BOOST_PREFIX _LAGER_PREFIX _ZUG_PREFIX)
    if(DEFINED ${private_variable})
        message(FATAL_ERROR "Lager dependency config leaked ${private_variable}")
    endif()
endforeach()

if(NOT Lager_VERSION STREQUAL KRITA_IOS_LAGER_VERSION)
    message(
        FATAL_ERROR
        "Lager reports version '${Lager_VERSION}', expected '${KRITA_IOS_LAGER_VERSION}'"
    )
endif()

foreach(required_target IN ITEMS Boost::boost lager lager::lager zug)
    if(NOT TARGET ${required_target})
        message(FATAL_ERROR "Lager package did not provide target ${required_target}")
    endif()
endforeach()

get_target_property(lager_alias_target lager::lager ALIASED_TARGET)
if(NOT lager_alias_target STREQUAL "lager")
    message(FATAL_ERROR "lager::lager aliases '${lager_alias_target}', expected lager")
endif()

get_target_property(lager_type lager TYPE)
if(NOT lager_type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "lager has type '${lager_type}', expected INTERFACE_LIBRARY")
endif()

get_target_property(lager_includes lager INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_LAGER_PREFIX}/include")
list(FIND lager_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "Lager target includes '${lager_includes}', expected '${expected_include}'"
    )
endif()

get_target_property(lager_features lager INTERFACE_COMPILE_FEATURES)
if(NOT "cxx_std_17" IN_LIST lager_features)
    message(FATAL_ERROR "lager features are '${lager_features}', expected cxx_std_17")
endif()

get_target_property(lager_links lager INTERFACE_LINK_LIBRARIES)
foreach(required_link IN ITEMS Boost::boost zug)
    if(NOT required_link IN_LIST lager_links)
        message(
            FATAL_ERROR
            "lager links '${lager_links}', expected transitive target ${required_link}"
        )
    endif()
endforeach()

add_executable(krita-ios-lager-consumer main.cpp)
target_link_libraries(krita-ios-lager-consumer PRIVATE lager)

install(TARGETS krita-ios-lager-consumer BUNDLE DESTINATION bin)
