cmake_minimum_required(VERSION 3.20)

project(KritaIOSHarfBuzzConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(harfbuzz CONFIG REQUIRED)

add_executable(krita-ios-harfbuzz-consumer main.cpp)
target_link_libraries(krita-ios-harfbuzz-consumer PRIVATE harfbuzz::harfbuzz)

install(TARGETS krita-ios-harfbuzz-consumer BUNDLE DESTINATION bin)
