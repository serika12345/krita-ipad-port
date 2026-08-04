include_directories(${CMAKE_CURRENT_SOURCE_DIR}/common)

# This helper is used by the TIFF and RAW importers.  Those dependency-backed
# importers are not part of the self-contained iOS profile yet, so do not add
# an otherwise unreferenced static library to the iOS install tree.
if(NOT IOS)
    add_subdirectory(common)
endif()
add_subdirectory(exif)
add_subdirectory(iptc)
add_subdirectory(xmp)

add_subdirectory(tests)
