# M4 static-plugin foundation validation

Date: 2026-08-02

The first M4 increments link the P0 minimum plugin set statically into the
unsigned iPadOS application: KRA and PNG import/export, the default Pixel Brush
paint-op, basic canvas tools, and the Layer Docker. This validates the common
conversion, registration, metadata discovery, and dead-stripping path before
expanding the iOS plugin profile.

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
- The current iOS profile enables `kritakraimport`, `kritakraexport`,
  `kritapngimport`, `kritapngexport`, and `kritadefaultpaintops`, plus their
  support libraries. `kritadefaulttools` supplies Freehand Brush, Fill,
  Gradient, Color Sampler, Line, Rectangle, Ellipse, Move, Pan, and the other
  basic canvas tools. `kritalayerdocker` supplies the minimum layer UI.

KRA's two plugins now use `K_PLUGIN_CLASS_WITH_JSON`. This is behaviorally
equivalent to their former factory macros, while allowing KCoreAddons' internal
factory-name override to make the static symbols unique.

## Inspection results

The executable contains all seven complete static plugin paths. The relevant
factory entry points are:

```text
qt_static_plugin_kritakraimport_factory()
qt_plugin_instance_kritakraimport_factory()
qt_plugin_query_metadata_kritakraimport_factory()
qt_static_plugin_kritakraexport_factory()
qt_plugin_instance_kritakraexport_factory()
qt_plugin_query_metadata_kritakraexport_factory()
qt_static_plugin_kritapngimport_factory()
qt_static_plugin_kritapngexport_factory()
qt_static_plugin_kritadefaultpaintops_factory()
qt_static_plugin_kritadefaulttools_factory()
qt_static_plugin_kritalayerdocker_factory()
```

The KRA, PNG, paint-op, tool, and Docker service metadata is present in the
linked image. The rebuilt app is Mach-O arm64 for platform IOS, minimum iOS
17.0, built against SDK 26.5. Its Info.plist passes `plutil -lint`, and
`otool -L` shows only iOS system libraries and frameworks. The unsigned bundle
is approximately 84 MiB.

Static linking exposed two non-inline function definitions in
`kis_paintop_plugin_utils.h`. Marking those header implementations `inline`
resolves the ODR violation for every static paint-op without adding an iOS-only
code path.

## Deferred validation

Runtime enumeration and factory instantiation require launching the application
and remain part of M5. M4 is not complete: the user-facing iOS feature profile
and P1 plugin set still need to be added and validated. Each older plugin factory
macro must be changed to
`K_PLUGIN_CLASS_WITH_JSON` as that plugin enters the iOS profile.
