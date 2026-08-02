# M2 validation record

Date: 2026-08-02

M2 is in progress. The core dependency set, Qt, and QuaZip are validated;
ECM and KDE Frameworks remain to be built and validated.

## Build boundary

The locked nixpkgs revision selects and fetches dependency source derivations
and provides host tools. Each target library is then compiled outside a Nix
derivation with Apple Clang and the validated Xcode SDK. This prevents the
proprietary SDK and its absolute paths from entering the Nix store while keeping
the open-source inputs pinned by `flake.lock`.

The standard nixpkgs `arm64-apple-ios` cross package set was evaluated first.
It currently requires importing Xcode 12.3 into the Nix store, so it was rejected
for this port: the pinned SDK is both obsolete for this matrix and contrary to
the boundary in ADR 0001.

## Validated target libraries

| Dependency | Version | Result |
|---|---:|---|
| zlib | 1.3.2 | static arm64/IOS archive |
| libpng | 1.6.58 | static arm64/IOS archive |
| Expat | 2.8.2 | static arm64/IOS archive |
| Boost | 1.89.0 | headers installed |
| Immer | 0.9.1 | headers installed |
| Zug | 0.1.2 | headers installed |
| Lager | 0.1.3 | headers installed |
| Eigen | 3.4.1 | headers installed |
| xsimd | 14.3.0 | headers installed |
| LCMS2 | 2.19.1 | static arm64/IOS archive |
| Exiv2 | 0.28.8 | static arm64/IOS archive |
| FreeType | 2.14.3 | static arm64/IOS archive |
| HarfBuzz | 13.2.1 | static arm64/IOS archive |
| Fontconfig | 2.18.2 | static arm64/IOS archive |
| libunibreak | 7.0 | static arm64/IOS archive |
| Qt | 6.11.1 | 39 static arm64/IOS archives |
| QuaZip | 1.5 | static arm64/IOS archive |

JPEG has a pinned flake source output but remains a P1 validation task.

## Commands and results

```sh
nix develop --command packaging/ios/scripts/build-dependencies.sh device
nix develop --command packaging/ios/scripts/build-qt.sh device
nix develop --command packaging/ios/scripts/build-dependencies.sh device
nix develop --command packaging/ios/scripts/probe-dependencies.sh device
nix develop --command packaging/ios/scripts/probe-qt.sh device
```

The dependency probe compiled and linked all libraries listed above into one
Mach-O application with these properties:

- architecture: arm64
- platform: IOS
- minimum OS: 17.0
- SDK: 26.5
- unresolved symbols: none

The Qt/QuaZip probe additionally linked Qt Core, Gui, Widgets, Xml, Network,
Svg, Concurrent, Sql, OpenGL, OpenGLWidgets, Core5Compat, QuaZip, and the static
iOS platform and support plugins. Its executable has the same arm64/IOS/minimum
OS/SDK metadata. Qt's configuration summary reports `Qt PrintSupport ... no`,
and no PrintSupport archive is installed.

A separate zlib/libpng Simulator build produced `platform IOSSIMULATOR` archives.
The archive inspector's negative test correctly rejected a Simulator archive
when it was presented as a device artifact.

## Portability fixes exercised

- CMake and pkg-config lookup are isolated from Homebrew, `/usr/local`, and host
  dependency paths.
- Generated HarfBuzz and Boost CMake packages use their installation prefix
  instead of embedding the local checkout path.
- The combined probe supplies CoreText/CoreGraphics for HarfBuzz's static
  CoreText backend and the SDK's iconv library for Exiv2.
- Fontconfig 2.18.2 requires Meson 1.11 or newer, while the locked host Meson is
  1.10.2. Its official Autotools build is used instead, limited to the target
  library and generated data needed by the install.
- Build fingerprints include the source path, build recipe, platform matrix,
  toolchain file, and builder schema. Changed inputs invalidate their stamps.
- Qt is built from the locked Qt 6.11.1 source outputs with the Nix-provided
  host Qt tools. Its target prefix is isolated from the non-Qt dependency
  prefix, and QuaZip fingerprints the exact target Qt build input.
- Qt 6.11.1 emits iOS API deprecation warnings under the Xcode 26.5 SDK, chiefly
  around older permission APIs. They do not prevent compilation or linking and
  remain an M5 runtime review item.

## Remaining M2 gate

M2 is not complete until ECM 6.28.0 and the selected KDE Frameworks build for
iOS and pass a combined link test. Cross-compilation probes such as `try_run()`
must also be resolved there.
