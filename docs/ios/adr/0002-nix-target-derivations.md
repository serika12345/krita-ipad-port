# ADR 0002: Build iOS target artifacts as granular Nix derivations

- Status: accepted
- Date: 2026-08-03

## Context

The first iPadOS build pipeline pinned sources and host tools with Nix but
installed all target libraries into mutable prefixes under `build-ios/`. Its
fingerprints avoided many local rebuilds, but the artifacts could not be
substituted from a Nix binary cache or recovered after local garbage
collection. A shared prefix also made the rebuild boundary larger than the
package that actually changed.

The proprietary iPhoneOS SDK and Apple toolchain must remain external. Their
identity nevertheless has to participate in every target derivation key so an
artifact built by a different SDK is never accepted under the same cache key.

## Decision

1. Each open-source iOS library is built into an independent Nix store path.
   Sources, patches, flags, and direct target dependencies are package-local.
2. Aggregated prefixes are made with `symlinkJoin`; packages never install into
   a shared mutable prefix.
3. The exact Xcode, Xcode build, SDK, SDK build, Apple Clang, deployment target,
   and architecture form a checked toolchain contract and are derivation
   inputs.
4. Xcode remains outside the Nix store. A target derivation reads only the
   validated Xcode application and SDK. It must fail before configuration if
   the installed toolchain does not match the contract.
5. All Apple static archives are created with `ZERO_AR_DATE=1` and normalized
   with deterministic `ranlib`. Every archive member is checked for arm64,
   platform IOS, minimum OS, SDK version, and duplicate member names.
6. Outputs must not retain references to the Xcode installation or temporary
   build directories.
7. Target store paths are published only to a private Nix binary cache. Shared
   caches require a Nix cache signature; this is unrelated to Apple application
   signing. Cache private keys and Apple credentials are never committed.
8. AltStore signing, USB device installation, launch, and device log collection
   stay outside Nix because they mutate external state and require credentials.
9. The script-driven build remains available until equivalent Nix packages and
   probes have been validated. Migration is package-by-package, not a flag day.

## Xcode sandbox boundary

The validated host runs the Darwin Nix daemon with sandboxing enabled and
fallback disabled. Xcode is not in `sandbox-paths`; it is the only project-
specific addition to the administrator-controlled impure host dependency
allowlist:

```nix
nix.settings.sandbox = true;
nix.settings.sandbox-fallback = false;
nix.settings.extra-allowed-impure-host-deps = [
  "/Applications/Xcode.app"
];
```

Using the `extra-` setting preserves Nix's required Darwin defaults. The common
iOS builder declares `toolchain.impureHostDeps` through `__impureHostDeps`, so
only those derivations can see Xcode. A negative test derivation without that
declaration confirmed that `/Applications/Xcode.app` is absent from its build
sandbox.

Target derivations read the canonical Xcode and iPhoneOS platform XML plists
directly for version and build identity. They do not invoke `xcodebuild`:
although `xcodebuild -version` appears read-only, it initializes IDE/DVT file
watchers and crashes when their unrelated Mach services and host paths are
denied. Apple Clang and the SDK work in the strict sandbox without widening the
host allowlist. Host-side configure, bundling, signing, and installation scripts
may still use `xcodebuild` outside a Nix build sandbox.

The common builders reserve their phase, fixed-output, network, and impure-host
attributes so a package recipe cannot weaken that boundary accidentally.
Package-specific passthru data cannot replace the checked toolchain identity,
and every compiled member of a propagated target dependency closure must carry
the same identity. Pure header packages use a separate builder without Xcode,
SDK, compiler, or impure host inputs and carry `iosTargetIndependent = true`.
Target builders accept a dependency only when it either has that marker and no
toolchain identity, or carries the exact current toolchain identity. Header
trees reject symlinks, special files, compiled artifacts, and mutations by
package check hooks before they can enter a target closure. Autoconf cache
entries are validated strings exported only to `configure`; they are never
merged into derivation attributes. Autotools pkg-config lookup uses only
declared target closures, with a private empty directory as the search root when
a package has no target dependency.

The restricted daemon settings cannot be changed by an untrusted client or a
flake. They are installed through the host's nix-darwin configuration. On
2026-08-03 the active policy was verified with `nix config show`, followed by:

```sh
nix build .#zlib-ios .#libpng-ios --no-link --no-substitute
nix build .#zlib-ios .#libpng-ios --no-link --no-substitute --rebuild
nix build .#ios-dependencies --no-link --no-substitute
nix flake check
```

The first command rebuilt both packages from source, including archive checks
and the libpng consumer link probe. The second command matched both existing
outputs, establishing determinism under the enforced sandbox.

## First proof

`zlib-ios` 1.3.2 is the first package using this design. It is built with Xcode
26.6 build 17F113, iPhoneOS SDK 26.5 build 23F81a, Apple Clang 21.0.0 build
2100.1.1.101, deployment target 17.0, and arm64. The following gates passed:

- Nix store build from the locked zlib source;
- all 15 archive members validated as arm64/IOS;
- relative CMake and pkg-config installation metadata;
- no retained Xcode path;
- `nix build --rebuild` produced an identical output;
- copy to and verification from a local Nix binary cache.

The local proof cache is intentionally unsigned and is restored explicitly by
`packaging/ios/scripts/restore-nix-cache.sh`. A shared cache must use normal Nix
signature verification instead of the local `--no-check-sigs` exception.

## Second proof

libpng 1.6.58 is the first package to consume another migrated target
derivation. Its zlib input is propagated into the output closure, and the
installed CMake package is tested by linking a small iOS executable through
`PNG::PNG` and the transitive `ZLIB::ZLIB` target. All 18 archive members,
including the arm64 NEON implementation, passed the same architecture and
platform checks. Forced rebuilds of zlib and libpng matched their existing
outputs, and the two-path closure was restored and recursively verified in an
isolated Nix store from the local binary cache.

## Third proof

FreeType 2.14.3 is the first package with two direct migrated target
dependencies. Its feature contract requires zlib and libpng while disabling
BZip2, HarfBuzz, and Brotli. The generated `ftoption.h` is checked against that
contract, and all 42 object members in the archive pass the iOS metadata gates.
A consumer declares only FreeType as its direct target dependency but discovers
and links all three archives through `Freetype::Freetype` alone. The installed
config adds the `ZLIB::ZLIB` and `PNG::PNG` dependency discovery missing from
upstream's export. That consumer also proves that the common builder recursively
adds propagated target dependencies to CMake's search roots. A forced rebuild
matched the existing output. The three-path
zlib/libpng/FreeType closure was then published to the local binary cache,
restored into a separate temporary Nix store, and verified recursively without
rebuilding.

## Further target proofs

Expat 2.8.2 fixes the XML character, DTD, general-entity, namespace, and context
features and validates both its CMake target and static pkg-config contract.
Little CMS 2.19.1 keeps thread support while suppressing an unnecessary Apple
`libm` lookup that otherwise embeds the external SDK path in its exported CMake
target. Eigen 3.4.1 is header-only, so its proof builds an iOS C++ consumer
through `Eigen3::Eigen` instead of inspecting an archive.

HarfBuzz 13.2.1 consumes only FreeType directly; the common target closure adds
zlib and libpng. Its installed CMake export replaces upstream's raw FreeType
archive and absolute SDK framework paths with `Freetype::Freetype` and portable
CoreFoundation/CoreText/CoreGraphics link items. A direct-only consumer forces
both the FreeType and CoreText bridges into the link. Source and forced rebuilds
matched for all four packages. Their outputs and the four-path HarfBuzz closure
were published to the local cache and restored into isolated stores.

Fontconfig 2.18.2 is the first package using the common Autotools target
builder. Target compilation and pkg-config lookup see only its direct Expat and
FreeType dependencies and their propagated libpng/zlib closure. Build-machine
configure probes use the Nix host compiler with `SDKROOT` removed, while target
objects use the validated Apple compiler and iPhoneOS SDK. The release
`configure` omits expansion of its `AX_FUNC_SNPRINTF` check, so the recipe fixes
the generated script and records the known iOS C99 snprintf/vsnprintf contract
as configure-cache inputs. A second upstream Autotools omission leaves
`fcconffile.c` out of the archive despite exporting `FcConfigFileGenerate`; the
package patches both source and generated Makefile bookkeeping. Its consumer
forces that symbol, the Expat parser, and the FreeType query path into one iOS
link and checks the exact five-archive closure. A forced rebuild matched the
existing output, and the five-path closure was restored into an isolated store
from the local cache.

xsimd 14.3.0 adds a source- and toolchain-keyed header-only package. Its
consumer uses the installed CMake target to compile a real vector batch for the
pinned arm64 iOS target, so the absence of an archive does not weaken the target
contract. libunibreak 7.0 builds through the same repository CMake wrapper used
by the legacy dependency pipeline. Its consumer resolves
`libunibreak::libunibreak` through Krita's find module and links the UTF-8 line-
breaking API, keeping the Nix package aligned with the actual application
discovery path. Source and forced rebuilds matched for both packages. The
updated ten-package aggregate and its complete 11-path runtime closure were
published to the local binary cache, restored into an empty isolated Nix store,
and recursively verified without access to the primary store.

libjpeg-turbo 3.1.4.1 fixes its static JPEG and TurboJPEG outputs, requires the
arm64 NEON implementation, and pins the embedded build identity to the existing
iOS dependency baseline date `19800101`. Two separate consumers use the
installed `libjpeg-turbo::jpeg-static` and
`libjpeg-turbo::turbojpeg-static` targets so overlapping codec objects never
make the proof depend on archive order. Krita's active iOS JPEG file plugin
continues to use Qt's bundled JPEG implementation; migrating this dependency
does not reintroduce the external codec into that crash-sensitive path. Its
source and forced rebuilds matched, and the resulting 12-path aggregate closure
was restored and verified in an empty store from the local cache.

Exiv2 0.28.8 fixes its audited library-only feature contract instead of
inheriting the relevant upstream defaults. It keeps the SDK-provided Iconv
implementation without exporting a host or SDK path: the static CMake and pkg-config metadata carries
the portable `-liconv` item required by final iOS links. It propagates only the
migrated zlib target as a store dependency. Its consumer compiles and links the
creation and reopening of an in-memory JPEG with Exif metadata plus the public
character-conversion API through `Exiv2::exiv2lib`. Every archive member and the
resulting executable use the pinned arm64 iOS target. The resulting 12-package
aggregate and its complete 13-path closure were restored into an empty store
from the local cache.

Boost 1.89.0 is the first package built by the pure header path. It copies the
locked upstream headers and generates the same relocatable `Boost::headers`,
`Boost::boost`, and `Boost::disable_autolinking` CMake contract used by the
legacy prefix. The package output contains no Xcode, SDK, toolchain identity, or
other Nix store reference. A separate pinned-toolchain consumer compiles real
Boost.MP11 and circular-buffer APIs for arm64 iOS. The resulting 13-package
aggregate and its complete 14-path target closure were restored into an empty
store from the local cache.

Immer 0.9.1 and Zug 0.1.2 also use the pure header path. Their generated
package metadata corrects the older versions declared by upstream CMake,
retains Krita's plain `immer` and `zug` target names, and exports their C++14
minimum. Separate consumers exercise rejected and accepted same-major ranges,
resolve the exact versions, and compile real APIs. The Zug proof uses a
filtering transducer under C++17 so `std::variant`, rather than an undeclared
Boost.Variant dependency, implements its skip state. The resulting 15-package
aggregate and its complete 16-path target closure were restored into an empty
store from the local cache.

## Consequences

- A normal Krita source edit does not rebuild target dependencies.
- A package source, patch, recipe, flag, direct dependency, or toolchain
  contract change rebuilds that package and its reverse dependencies.
- Static consumers intentionally rebuild when an input library store path
  changes; bypassing that invalidation would be unsafe.
- A matching private-cache object avoids compilation even after local GC or on
  another compatible Apple Silicon Mac.
- Fully reproducing a cache miss still requires the validated proprietary
  Xcode installation.
