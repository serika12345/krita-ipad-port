cmake_minimum_required(VERSION 3.24)
project(KritaIOSQtProbe LANGUAGES CXX)

find_package(
    Qt6 6.11 REQUIRED
    COMPONENTS
        Concurrent
        Core
        Core5Compat
        Gui
        Network
        OpenGL
        OpenGLWidgets
        Sql
        Svg
        SvgWidgets
        Widgets
        Xml
)
find_package(QuaZip-Qt6 1.5 REQUIRED)

qt_standard_project_setup()
qt_add_executable(KritaIOSQtProbe MACOSX_BUNDLE main.cpp)
target_link_libraries(
    KritaIOSQtProbe
    PRIVATE
        Qt6::Concurrent
        Qt6::Core
        Qt6::Core5Compat
        Qt6::Gui
        Qt6::Network
        Qt6::OpenGL
        Qt6::OpenGLWidgets
        Qt6::Sql
        Qt6::Svg
        Qt6::SvgWidgets
        Qt6::Widgets
        Qt6::Xml
        QuaZip::QuaZip
)
set_target_properties(
    KritaIOSQtProbe
    PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER org.krita.ios.qt-probe
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
)
