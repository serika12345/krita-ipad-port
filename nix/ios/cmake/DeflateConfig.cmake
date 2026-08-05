get_filename_component(_DEFLATE_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(NOT TARGET Deflate::Deflate)
    add_library(Deflate::Deflate STATIC IMPORTED)
    set_target_properties(Deflate::Deflate PROPERTIES
        IMPORTED_LOCATION "${_DEFLATE_PREFIX}/lib/libdeflate.a"
        INTERFACE_INCLUDE_DIRECTORIES "${_DEFLATE_PREFIX}/include"
    )
endif()

unset(_DEFLATE_PREFIX)
