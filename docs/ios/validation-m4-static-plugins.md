# M4 static-plugin foundation validation

Date: 2026-08-02

The first M4 increment links the KRA import and export plugins statically into
the unsigned iPadOS application. This validates the common conversion,
registration, metadata discovery, and dead-stripping path before expanding the
iOS plugin profile to painting, tool, and Docker plugins.

## Reproduction

```sh
nix develop --command packaging/ios/scripts/configure-krita.sh device
nix develop --command cmake --build --preset ios-device --parallel 8
```

The resulting application is:

`build-ios/krita/device-ninja/bin/krita.app`

## Implemented path

- `kis_add_library(... MODULE ...)` becomes `STATIC` only for iOS.
- Every static target receives a target-derived KPlugin factory class name, so
  generic names such as `ImportFactory` cannot collide in the final executable.
- The enabled targets are collected as they are declared. CMake generates one
  application source file that references and registers every factory and links
  the corresponding archive.
- Factory references originate in a directly linked application object. This
  retains the factory object and its MOC-embedded JSON metadata when dead
  stripping is enabled.
- `KoJsonTrader` adds the KCoreAddons static-plugin registry to its existing
  filesystem plugin search and preserves its established metadata interface.
- The current iOS profile enables only `kritakraimport`, `kritakraexport`, and
  their `kritalibkra` support library.

KRA's two plugins now use `K_PLUGIN_CLASS_WITH_JSON`. This is behaviorally
equivalent to their former factory macros, while allowing KCoreAddons' internal
factory-name override to make the static symbols unique.

## Inspection results

The executable contains both complete static plugin paths:

```text
qt_static_plugin_kritakraimport_factory()
qt_plugin_instance_kritakraimport_factory()
qt_plugin_query_metadata_kritakraimport_factory()
qt_static_plugin_kritakraexport_factory()
qt_plugin_instance_kritakraexport_factory()
qt_plugin_query_metadata_kritakraexport_factory()
```

The KRA MIME/service metadata is present in the linked image. The rebuilt app is
Mach-O arm64 for platform IOS, minimum iOS 17.0, built against SDK 26.5. Its
Info.plist passes `plutil -lint`, and `otool -L` shows only iOS system libraries
and frameworks. The unsigned bundle is approximately 77 MiB.

## Deferred validation

Runtime enumeration and factory instantiation require launching the application
and remain part of M5. M4 is not complete: PNG, Pixel Brush, basic tools, Layer
Docker, and the user-facing iOS feature profile still need to be added and
validated. Each older plugin factory macro must be changed to
`K_PLUGIN_CLASS_WITH_JSON` as that plugin enters the iOS profile.
