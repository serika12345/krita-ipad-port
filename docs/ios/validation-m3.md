# M3 validation record

Date: 2026-08-02

M3 has reached the unsigned-link gate. A reduced Krita application, including
the main window, core painting libraries, Qt resources, and the static Qt/KF6
runtime, configures and links for an arm64 iPadOS device.

## Reproduction

After completing the M2 dependency, Qt, and framework builds:

```sh
nix develop --command packaging/ios/scripts/configure-krita.sh device --build
```

The wrapper validates the host matrix, resolves the pinned host Qt Linguist
tools, supplies only the isolated target prefixes, and uses the Ninja generator.
The Xcode generator is not used because static Qt target object expressions are
not accepted by its cross-compiling compiler checks in this configuration.

## Artifact

`build-ios/krita/device-ninja/bin/krita.app` has these inspected properties:

- executable: Mach-O 64-bit arm64
- platform: IOS
- minimum OS: 17.0
- SDK: 26.5
- bundle identifier: `org.krita.ipad.port`
- device family: iPad only (`2`)
- supported orientations: all four iPad orientations
- signing: none
- bundle size: approximately 76 MiB before plugins and production resources
- non-system dynamic libraries: none

The generated Info.plist passes `plutil -lint`. `otool -L` lists only iOS SDK
frameworks and system libraries; Krita, Qt, KF6, and open-source dependencies
are statically linked.

## Port boundaries applied

- macOS-only packaging, RPATH, AppKit helpers, Finder integration, and Objective-C++
  utility code are excluded with `APPLE AND NOT IOS` conditions.
- shared Krita libraries become static libraries for iOS.
- target Python development libraries and Python/PyQt bindings are disabled;
  host Python remains available for build-time generators.
- PrintSupport, updater code, external plugin trees, and QML modules are disabled.
- FFmpeg video import and animation rendering actions are omitted because Qt
  deletes QProcess on iOS. Animation editing and frame playback remain compiled.
- unavailable desktop OpenGL extension names are mapped to their OpenGL ES
  numeric equivalents in one iOS compatibility header.
- static Fontconfig/Expat and libintl/iconv dependencies are made explicit at
  final link time.

## Deferred validation

This artifact is intentionally unsigned and therefore has not been installed or
launched on a physical iPad. Static initialization, Qt platform startup, main
window presentation, and runtime resource lookup remain M5 checks after the M4
minimum internal-plugin set is linked. The current app has no dynamically loaded
Krita paint-op, tool, Docker, or import/export plugins; those are the M4 scope.
