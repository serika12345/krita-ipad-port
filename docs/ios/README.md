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
flake package outputs. Target artifacts are built locally against the validated
Xcode SDK rather than importing the proprietary SDK into the Nix store.

## Build boundary

Nix pins host build tools and open-source target dependencies. Xcode supplies
Apple Clang, the proprietary SDK, the Xcode generator, development signing,
and device installation. See `docs/ios/adr/0001-nix-xcode-boundary.md`.

## Start a development shell

In a normal terminal:

```sh
nix develop
packaging/ios/scripts/check-host.sh
```

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

Full Krita presets are available as `ios-device` and `ios-simulator`. They are
expected to stop on missing target dependencies until M2 is complete:

```sh
cmake --preset ios-device
```

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

The local Nix store is the default build cache. Inspect the closure with:

```sh
nix path-info --recursive .#devShells.aarch64-darwin.default
```

For multiple Macs, configure a private substituter and trusted public key in
the normal Nix configuration. Do not publish Apple SDK-derived or signing
material. The flake pins tools; `packaging/ios/versions.env` prevents silently
reusing a cache under an unvalidated Xcode/SDK combination.

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
