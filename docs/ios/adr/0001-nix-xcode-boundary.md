# ADR 0001: Keep a strict Nix/Xcode boundary

- Status: accepted
- Date: 2026-08-02

## Context

Krita needs a large reproducible dependency graph, while iPadOS compilation,
bundling, signing, and installation depend on proprietary Xcode components and
the developer keychain. Treating the whole build as either an unmanaged Xcode
project or a pure Nix derivation makes one side unnecessarily fragile.

## Decision

1. Nix pins CMake, Ninja, Python, pkg-config, text tools, source revisions,
   patches, and open-source libraries compiled for iOS.
2. Xcode supplies Apple Clang, iPhoneOS/iPhoneSimulator SDKs, final bundle
   generation, development signing, and device installation.
3. The final Xcode step is deliberately not claimed to be a pure Nix build.
4. Xcode and SDK versions are explicit validated inputs. A mismatch fails
   before compilation unless an upgrade engineer opts in with
   `KRITA_IOS_ALLOW_UNVALIDATED_HOST=1`.
5. Host executables belong in Nix `nativeBuildInputs`; iOS libraries belong in
   target `buildInputs` or an explicit iOS prefix. Toolchain search modes reject
   host libraries and headers.
6. iOS plugins are statically linked from an explicit profile. Downloaded or
   runtime-installed executable plugins are out of scope.

## Consequences

- Dependency builds and patches are repeatable and cacheable.
- Signing identities and Apple SDK contents never enter the repository/cache.
- Reproducing the final app still requires the validated Xcode installation.
- Xcode upgrades require an explicit validation cycle and cache separation.
