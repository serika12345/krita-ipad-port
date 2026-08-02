add_subdirectory( lcms2engine )

if(IOS)
    # The LittleCMS engine is required for startup. Optional color-space
    # extensions are added to the iOS profile separately.
    return()
endif()

add_subdirectory( colorspaceextensions )
