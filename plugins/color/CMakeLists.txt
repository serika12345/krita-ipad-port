add_subdirectory( lcms2engine )

if(IOS AND NOT KRITA_IOS_PLUGIN_COLORSPACE_EXTENSIONS)
    # The LittleCMS engine is required for startup. Optional color-space
    # extensions remain separately switchable in the iOS profile.
    return()
endif()

add_subdirectory( colorspaceextensions )
