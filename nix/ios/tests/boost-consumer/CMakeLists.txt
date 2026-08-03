cmake_minimum_required(VERSION 3.20)

project(KritaIOSBoostConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(
    Boost ${KRITA_IOS_BOOST_VERSION}
    EXACT
    CONFIG
    REQUIRED
)

if(NOT Boost_VERSION STREQUAL KRITA_IOS_BOOST_VERSION)
    message(
        FATAL_ERROR
        "Boost reports version '${Boost_VERSION}', expected '${KRITA_IOS_BOOST_VERSION}'"
    )
endif()

foreach(required_target IN ITEMS Boost::headers Boost::boost Boost::disable_autolinking)
    if(NOT TARGET "${required_target}")
        message(FATAL_ERROR "The installed Boost package did not define ${required_target}")
    endif()
    get_target_property(target_type "${required_target}" TYPE)
    if(NOT target_type STREQUAL "INTERFACE_LIBRARY")
        message(
            FATAL_ERROR
            "${required_target} has type '${target_type}', expected INTERFACE_LIBRARY"
        )
    endif()
endforeach()

get_target_property(boost_includes Boost::headers INTERFACE_INCLUDE_DIRECTORIES)
set(expected_include "${KRITA_IOS_BOOST_PREFIX}/include")
list(FIND boost_includes "${expected_include}" expected_include_index)
if(expected_include_index EQUAL -1)
    message(
        FATAL_ERROR
        "Boost::headers includes '${boost_includes}', expected '${expected_include}'"
    )
endif()

get_target_property(boost_links Boost::boost INTERFACE_LINK_LIBRARIES)
if(NOT "Boost::headers" IN_LIST boost_links)
    message(FATAL_ERROR "Boost::boost links '${boost_links}', expected Boost::headers")
endif()

get_target_property(
    boost_disable_definitions
    Boost::disable_autolinking
    INTERFACE_COMPILE_DEFINITIONS
)
if(NOT "BOOST_ALL_NO_LIB" IN_LIST boost_disable_definitions)
    message(
        FATAL_ERROR
        "Boost::disable_autolinking definitions are '${boost_disable_definitions}'"
    )
endif()

add_executable(krita-ios-boost-consumer main.cpp)
target_link_libraries(
    krita-ios-boost-consumer
    PRIVATE
        Boost::boost
        Boost::disable_autolinking
)
target_compile_features(krita-ios-boost-consumer PRIVATE cxx_std_17)

install(TARGETS krita-ios-boost-consumer BUNDLE DESTINATION bin)
