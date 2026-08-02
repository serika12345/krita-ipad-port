cmake_minimum_required(VERSION 3.24)
project(libunibreak VERSION 7.0 LANGUAGES C)

include(GNUInstallDirs)

if(NOT IS_DIRECTORY "${LIBUNIBREAK_SOURCE_DIR}/src")
    message(FATAL_ERROR "LIBUNIBREAK_SOURCE_DIR must point at a libunibreak source tree")
endif()

set(libunibreak_sources
    unibreakbase.c
    unibreakdef.c
    linebreak.c
    linebreakdata.c
    linebreakdef.c
    eastasianwidthdef.c
    emojidef.c
    graphemebreak.c
    wordbreak.c
)
list(TRANSFORM libunibreak_sources PREPEND "${LIBUNIBREAK_SOURCE_DIR}/src/")

add_library(unibreak STATIC ${libunibreak_sources})
target_include_directories(
    unibreak
    PUBLIC
        "$<BUILD_INTERFACE:${LIBUNIBREAK_SOURCE_DIR}/src>"
        "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

set(libunibreak_headers
    unibreakbase.h
    unibreakdef.h
    linebreak.h
    linebreakdef.h
    eastasianwidthdef.h
    graphemebreak.h
    wordbreak.h
)
list(TRANSFORM libunibreak_headers PREPEND "${LIBUNIBREAK_SOURCE_DIR}/src/")

install(TARGETS unibreak ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES ${libunibreak_headers} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

set(prefix "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix "${CMAKE_INSTALL_PREFIX}")
set(libdir "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
set(includedir "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}")
set(VERSION "${PROJECT_VERSION}")
configure_file(
    "${LIBUNIBREAK_SOURCE_DIR}/libunibreak.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/libunibreak.pc"
    @ONLY
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libunibreak.pc" DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
