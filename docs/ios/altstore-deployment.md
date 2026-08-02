# AltStore physical-device deployment

Date: 2026-08-02

`packaging/ios/scripts/deploy-altstore.sh` automates the path from the current
source tree to a launched physical-device build. The unsigned CMake product is
never modified in place, and no signing identity or Apple credential is stored
by this repository.

## Prerequisites

- The validated Xcode/iOS SDK and Nix environment are installed.
- Developer Mode is enabled on the iPad.
- AltServer is running on the Mac.
- AltStore is installed and configured on the iPad.
- The Mac and iPad can reach each other over the local network while deploying.

AltStore performs the development signing required by iPadOS. No notarization,
App Store submission, or distribution profile is involved.

## One-command flow

```sh
packaging/ios/scripts/deploy-altstore.sh
```

The first available CoreDevice is selected. An explicit identifier can be
passed as the only positional argument:

```sh
packaging/ios/scripts/deploy-altstore.sh \
  216CE849-760C-5BFF-8835-CF7C6A1AD431
```

To package and reinstall an already successful build:

```sh
packaging/ios/scripts/deploy-altstore.sh --skip-build \
  216CE849-760C-5BFF-8835-CF7C6A1AD431
```

The script performs these operations in order:

1. Configure and build Krita inside `nix develop` unless `--skip-build` is set.
2. Reject a binary with the wrong architecture, Apple platform, or deployment target.
3. Compare every static archive's Qt resource initializers with the final executable.
4. Generate Krita's declared install-time data tree and copy it into the staged app.
5. Compare every staged runtime file with the app and require bundles, brush presets, ICC profiles, and actions.
6. Generate and test a timestamp-versioned IPA under `build-ios/deploy/`.
7. Open an AltStore install URL, wait for its download, and wait for the new bundle version on-device.
8. Launch Krita and copy its startup log back to `build-ios/deploy/`.

Optional environment variables are `KRITA_IOS_DEVICE`,
`KRITA_IOS_BUNDLE_VERSION`, `KRITA_IOS_DEPLOY_PORT`, and
`KRITA_IOS_LAUNCH_SETTLE_SECONDS`.

## Runtime data handling

On iOS, Krita resolves its installation prefix from the application bundle.
The deployment stage includes the exact CMake-installed `share` tree inside the
signed app. Current validation covers 496 files, including four resource
bundles, 32 ICC profiles, and seven action definitions. The action set includes
the core `krita.action` and `kritamenu.action` registries; packaging fails if
either file or a representative core menu action is missing.

AltStore updates preserve the application data container. Development builds
can add packaged bundles without changing Krita's semantic version, so the iOS
resource locator checks for missing packaged bundle names and imports only new
ones. Existing resources and user data are preserved.

## Validated result

The physical-device run `20260802121956` completed the automated flow and
reached Krita's main window without a fatal dialog. The existing data container
was migrated without deletion. Its resource database contained:

- four bundle storages, three active by their defaults;
- 169 paint-op presets;
- 256 brushes;
- 274 patterns;
- 36 gradients and 25 palettes.

A subsequent launch reached an existing 2480 x 3508 canvas within five seconds
and displayed rendered brush strokes, the Freehand Brush tools, Tool Options,
and the Layer Docker. The capture does not distinguish finger input from Apple
Pencil input, so pressure and native input-event validation remain M5 work.

The first synchronization of approximately 36 MiB of bundled resources showed
the splash screen for about 20 seconds on the tested device. Later launches do
not repeat that import unless the packaged bundle set changes.

The follow-up physical-device run `20260802123518` validated 496 runtime files
and restored every Edit-menu label that had been blank when the two core action
registries were absent. Disabled entries remain visible in gray as expected.

The physical-device run `20260802124350` disabled Qt's UIKit-native combo-box
picker at the Krita application-style boundary. Qt 6.11 otherwise presents a
`UIPickerView` whose Done/Cancel input toolbar is not visible in this window
layout, leaving choices impossible to commit or dismiss. Combo boxes now use
Qt's inline popup list on iPadOS. `Settings > Configure Krita > General > Tools`
was used to verify that `Touch Painting` opens all three choices, commits
`Enabled` with one tap, and closes the list while keeping the dialog's OK and
Cancel buttons reachable. The override is application-wide and is preserved
when Krita's widget style changes.

The physical-device run `20260802125200` fixed the startup splash position in
landscape. UIKit can publish the initial portrait screen geometry before the
application scene settles into its requested orientation. Krita now recenters
the splash after its native view is attached and whenever Qt reports updated
screen geometry. The centered result was confirmed on the connected iPad.
