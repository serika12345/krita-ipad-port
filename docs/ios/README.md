# iPadOS port baseline

## Validated matrix

| Component | Pinned value |
|---|---|
| Krita base revision | `7173825999953623d28777a163a65b42a3f26f0a` |
| Host | Apple Silicon macOS |
| Nix | 2.31 or newer |
| Xcode | 26.6 |
| iPhoneOS SDK | 26.5 |
| Qt | 6.11.1 |
| KDE Frameworks/ECM | 6.28.0 |
| Deployment target | iPadOS 17.0 |
| Device architecture | arm64 |

The exact executable host and SDK checks live in `packaging/ios/versions.env`.
Dependency sources are selected by the locked nixpkgs revision and exposed as
flake package outputs. Target packages are being migrated to granular Nix
derivations which use the validated external Xcode SDK without copying it into
the Nix store. See `docs/ios/adr/0002-nix-target-derivations.md`.

## Build boundary

Nix pins host build tools and open-source target dependencies and owns the
cacheable target build recipes. Xcode supplies Apple Clang and the proprietary
SDK. AltStore/AltServer can perform local development signing and device
installation without storing credentials in the repository. See
`docs/ios/adr/0001-nix-xcode-boundary.md` and
`docs/ios/adr/0002-nix-target-derivations.md`.

The validated Darwin daemon uses `sandbox = true` and
`sandbox-fallback = false`. `/Applications/Xcode.app` is allowed only for
derivations that explicitly declare it through `__impureHostDeps`; it is not a
global `sandbox-paths` entry. Target recipes read version identity from Xcode's
plists instead of starting `xcodebuild` inside the sandbox.

## Build the migrated target derivations

The package-by-package Nix migration currently includes zlib, libpng, and
FreeType:

```sh
nix build .#zlib-ios .#libpng-ios .#freetype-ios
```

Their derivations check the complete Xcode/SDK/compiler contract and validate
every member of the resulting static archives. The libpng check also builds a
small iOS consumer through `PNG::PNG` and verifies the transitive zlib package.
The FreeType package requires both target packages, fixes its optional feature
set, and adds their missing CMake dependency discovery. Its direct-only consumer
check links all three archives through `Freetype::Freetype` alone and verifies
that the common builder expands FreeType's propagated zlib/libpng closure into
the target CMake roots. The `.#ios-dependencies` aggregate contains this
migrated subset only. The existing `build-ios/` builders remain authoritative
for packages not yet migrated.

To validate an actual source build rather than a binary-cache substitution:

```sh
nix build .#zlib-ios .#libpng-ios .#freetype-ios --no-link --no-substitute
nix build .#zlib-ios .#libpng-ios .#freetype-ios --no-link --no-substitute --rebuild
```

## Start a development shell

In a normal terminal:

```sh
nix develop
packaging/ios/scripts/check-host.sh
```

The host check also fails if sandboxing is disabled, fallback is enabled, the
Xcode allowlist entry is missing, or Xcode has been exposed globally through
`sandbox-paths`.

In a restricted environment where the user cache is not writable:

```sh
XDG_CACHE_HOME="$PWD/.cache/nix" nix develop
```

## Build the smoke application

The smoke application validates Objective-C++, UIKit, the selected SDK,
deployment target, bundle generation, and target platform metadata. It is not
signed and is not installed on a device.

```sh
nix develop --command packaging/ios/scripts/build-smoke.sh device
nix develop --command packaging/ios/scripts/build-smoke.sh simulator
```

Full Krita presets are available as `ios-device` and `ios-simulator`. Use the
wrapper so the three target prefixes and pinned host translation tools are
resolved consistently:

```sh
nix develop --command packaging/ios/scripts/configure-krita.sh device
nix develop --command packaging/ios/scripts/configure-krita.sh device --build
```

The device result is an unsigned
`build-ios/krita/device-ninja/bin/krita.app`. The iPadOS feature profile links
the current minimum Krita plugins statically and excludes Python/PyQt,
PrintSupport, process-launched FFmpeg features, and the updater.

## Install the current build with AltStore

With AltServer running and AltStore installed on a connected iPad, one command
configures, builds, validates, packages, installs, launches, and collects the
Krita startup log:

```sh
packaging/ios/scripts/deploy-altstore.sh
```

Pass a CoreDevice identifier when more than one device is available. Use
`--skip-build` to repackage the current successful build. See
`docs/ios/altstore-deployment.md` for prerequisites, validations, outputs, and
the physical-device result.

## Build M2 dependencies

Build one dependency and its transitive prerequisites, or omit the package name
to build every dependency currently present in the manifest:

```sh
nix develop --command packaging/ios/scripts/build-dependencies.sh device harfbuzz
nix develop --command packaging/ios/scripts/build-dependencies.sh device
```

Device and Simulator use separate source-independent prefixes. Every installed
static archive is checked member-by-member for architecture and Apple platform
metadata. A stale or host archive is rejected before its build stamp is written.

Link the completed core subset into a single unsigned iOS application:

```sh
nix develop --command packaging/ios/scripts/probe-dependencies.sh device
```

The dependency graph and package-specific options are defined in
`packaging/ios/deps/dependencies.json`. See `docs/ios/validation-m2.md` for the
current validated subset and known limitations.

## Build Qt and Qt-dependent libraries

Qt is built statically from the locked Qt 6.11.1 sources. Build the core
dependencies first, then Qt, then rerun the dependency builder so it can add
Qt-dependent packages such as QuaZip:

```sh
nix develop --command packaging/ios/scripts/build-dependencies.sh device
nix develop --command packaging/ios/scripts/build-qt.sh device
nix develop --command packaging/ios/scripts/build-dependencies.sh device
nix develop --command packaging/ios/scripts/probe-qt.sh device
```

`build-qt.sh` fingerprints the locked source outputs, Xcode/SDK matrix, and
build recipe. A matching build is reused and all installed archives are still
revalidated. If an input changes, rebuild the isolated Qt target directory:

```sh
nix develop --command packaging/ios/scripts/build-qt.sh device --clean
```

The Qt probe links Core, Gui, Widgets, Xml, Network, Svg, Concurrent, Sql,
OpenGL, OpenGLWidgets, Core5Compat, the iOS platform plugin, static support
plugins, and QuaZip into one unsigned iOS application. PrintSupport is
explicitly disabled and is rejected as a required Krita dependency.

## Build KDE Frameworks

Build the locked ECM/KF6 subset after the target dependencies and Qt. The
builder also creates the macOS `kconfig_compiler_kf6` needed while cross
compiling; target-side command-line tools are not built for iOS.

```sh
nix develop --command packaging/ios/scripts/build-frameworks.sh device
nix develop --command packaging/ios/scripts/probe-frameworks.sh device
```

The framework probe runs the host KConfig generator and links Config,
WidgetsAddons, Codecs, Completion, CoreAddons, GuiAddons, I18n, ItemViews, and
ColorScheme with Qt into one unsigned iOS application. Framework sources,
build options, patches, and dependencies are declared in
`packaging/ios/frameworks/frameworks.json`.

## Build output and logs

- Device and Simulator output: `build-ios/`
- Timestamped command logs: `logs/ios/`
- Plugin inventory: `packaging/ios/manifests/plugins.json`
- Dependency inventory: `packaging/ios/manifests/dependencies.json`

Regenerate the plugin inventory after adding or removing plugin targets:

```sh
python3 packaging/ios/scripts/inventory-plugins.py
```

## Local cache

The local Nix store is the first-level build cache. A GC-independent local Nix
binary cache can be populated with:

```sh
packaging/ios/scripts/publish-nix-cache.sh .#zlib-ios
```

Restore a local cache object without rebuilding it, for example after Nix GC:

```sh
packaging/ios/scripts/restore-nix-cache.sh .#zlib-ios
```

The default repository is the ignored
`build-ios/nix-binary-cache`. Set `KRITA_IOS_NIX_CACHE_URI` to a private,
writable Nix store URI supported by `nix copy`. A non-file destination also
requires `KRITA_IOS_NIX_CACHE_SIGNING_KEY`; keep that private key outside the
repository. Services with their own push protocol require their own client
rather than this generic script.

Inspect a closure with:

```sh
nix path-info --recursive .#devShells.aarch64-darwin.default
```

For multiple Macs, configure the private cache as a substituter with its trusted
public key in the normal Nix configuration. Do not publish these SDK-derived
artifacts to a public cache, and never cache Apple signing material. The exact
Xcode build, SDK build, and Apple Clang build are derivation inputs, so a
different validated toolchain selects a different cache key.

## Existing platform baseline

- Android has a maintained packaging tree and extensive `Q_OS_ANDROID`
  adaptations, but the historical `README.android.md` is not a current source
  of dependency versions.
- macOS is the closest Apple compilation baseline, but its packaging, RPATH,
  icon, process, and filesystem assumptions must not leak into iOS.
- The repository does not currently configure on this host outside the Nix
  shell because CMake and Ninja are intentionally not globally installed.
- A full macOS/Android build is not an M0 acceptance test; those builds need
  their separate prebuilt dependency environments.
