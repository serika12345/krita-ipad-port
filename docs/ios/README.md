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
Dependency source hashes will be added as each M2 derivation is implemented.

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
