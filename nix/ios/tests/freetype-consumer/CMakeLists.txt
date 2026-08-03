cmake_minimum_required(VERSION 3.20)

project(KritaIOSFreeTypeConsumer LANGUAGES C)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(Freetype CONFIG REQUIRED)

add_executable(krita-ios-freetype-consumer main.c)
target_link_libraries(krita-ios-freetype-consumer PRIVATE Freetype::Freetype)

install(TARGETS krita-ios-freetype-consumer BUNDLE DESTINATION bin)
