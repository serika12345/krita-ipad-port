cmake_minimum_required(VERSION 3.20)

project(KritaIOSLittleCMSConsumer LANGUAGES C)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(lcms2 CONFIG REQUIRED)

add_executable(krita-ios-lcms2-consumer main.c)
target_link_libraries(krita-ios-lcms2-consumer PRIVATE lcms2::lcms2)
