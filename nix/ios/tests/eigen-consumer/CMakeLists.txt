cmake_minimum_required(VERSION 3.20)

project(KritaIOSEigenConsumer LANGUAGES CXX)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(Eigen3 CONFIG REQUIRED)

add_executable(krita-ios-eigen-consumer main.cpp)
target_link_libraries(krita-ios-eigen-consumer PRIVATE Eigen3::Eigen)
target_compile_features(krita-ios-eigen-consumer PRIVATE cxx_std_17)
