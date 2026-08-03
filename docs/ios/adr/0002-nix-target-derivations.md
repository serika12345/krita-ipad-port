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
