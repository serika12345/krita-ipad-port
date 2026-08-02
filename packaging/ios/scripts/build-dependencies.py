#!/usr/bin/env python3
"""Build pinned open-source dependencies with the installed Xcode iOS SDK."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
from typing import Any

BUILDER_SCHEMA = 3


def run(command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def capture(command: list[str], *, cwd: Path | None = None) -> str:
    return subprocess.check_output(command, cwd=cwd, text=True).strip()


def fingerprint(package: dict[str, Any], source: Path, toolchain: Path, mode: str, repo: Path) -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(package, sort_keys=True).encode())
    digest.update(str(source.resolve()).encode())
    digest.update(toolchain.read_bytes())
    digest.update(str(BUILDER_SCHEMA).encode())
    for relative_path in package.get("fingerprint_files", []):
        digest.update((repo / relative_path).read_bytes())
    digest.update(mode.encode())
    digest.update(capture(["xcodebuild", "-version"]).encode())
    digest.update(capture(["xcrun", "--sdk", "iphoneos" if mode == "device" else "iphonesimulator", "--show-sdk-version"]).encode())
    return digest.hexdigest()


def make_tree_writable(root: Path) -> None:
    """Make a Nix-derived working copy removable and patchable by its owner."""
    if not root.exists():
        return
    for directory, _, filenames in os.walk(root):
        directory_path = Path(directory)
        directory_path.chmod(directory_path.stat().st_mode | stat.S_IWUSR | stat.S_IXUSR)
        for filename in filenames:
            path = directory_path / filename
            if not path.is_symlink():
                path.chmod(path.stat().st_mode | stat.S_IWUSR)


def materialize_source(source: Path, destination: Path) -> Path:
    if destination.exists():
        make_tree_writable(destination)
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True, symlinks=True)
        make_tree_writable(destination)
        return destination

    # Inputs are trusted, content-addressed Nix source derivations.
    shutil.unpack_archive(str(source), str(destination))
    make_tree_writable(destination)

    children = list(destination.iterdir())
    if len(children) == 1 and children[0].is_dir():
        return children[0]
    return destination


def resolve_packages(all_packages: dict[str, dict[str, Any]], requested: list[str]) -> list[dict[str, Any]]:
    resolved: list[dict[str, Any]] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name not in all_packages:
            raise SystemExit(f"unknown dependency: {name}")
        if name in visited:
            return
        if name in visiting:
            raise SystemExit(f"dependency cycle at: {name}")
        visiting.add(name)
        for dependency in all_packages[name]["dependencies"]:
            visit(dependency)
        visiting.remove(name)
        visited.add(name)
        resolved.append(all_packages[name])

    for name in requested:
        visit(name)
    return resolved


def remove_previous_install(build_dir: Path, prefix: Path) -> None:
    manifest = build_dir / "install_manifest.txt"
    if not manifest.exists():
        return
    for entry in manifest.read_text().splitlines():
        installed = Path(entry)
        try:
            installed.relative_to(prefix)
        except ValueError as error:
            raise SystemExit(f"refusing to remove path outside dependency prefix: {installed}") from error
        if installed.is_file() or installed.is_symlink():
            installed.unlink()
    for directory in sorted(prefix.rglob("*"), key=lambda path: len(path.parts), reverse=True):
        if directory.is_dir():
            try:
                directory.rmdir()
            except OSError:
                pass


def record_meson_install(build_dir: Path, prefix: Path) -> None:
    meson_log = build_dir / "meson-logs/install-log.txt"
    if not meson_log.exists():
        raise SystemExit(f"Meson install log is missing: {meson_log}")
    installed: list[str] = []
    for line in meson_log.read_text().splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        path = Path(entry)
        try:
            path.relative_to(prefix)
        except ValueError as error:
            raise SystemExit(f"Meson installed outside dependency prefix: {path}") from error
        if path.is_file() or path.is_symlink():
            installed.append(str(path))
    (build_dir / "install_manifest.txt").write_text("\n".join(installed) + "\n")


def write_meson_cross_file(build_dir: Path, prefix: Path, sdk: str, mode: str) -> Path:
    sdk_path = capture(["xcrun", "--sdk", sdk, "--show-sdk-path"])
    compiler = capture(["xcrun", "--sdk", sdk, "--find", "clang"])
    compiler_cxx = capture(["xcrun", "--sdk", sdk, "--find", "clang++"])
    ar = capture(["xcrun", "--sdk", sdk, "--find", "ar"])
    strip = capture(["xcrun", "--sdk", sdk, "--find", "strip"])
    pkg_config = shutil.which("pkg-config")
    if not pkg_config:
        raise SystemExit("pkg-config is required")
    minimum_flag = "-miphoneos-version-min=17.0" if mode == "device" else "-mios-simulator-version-min=17.0"
    flags = f"['-arch', 'arm64', '-isysroot', '{sdk_path}', '{minimum_flag}']"
    cross_file = build_dir.parent / f"{build_dir.name}-cross.ini"
    cross_file.write_text(
        "[binaries]\n"
        f"c = '{compiler}'\n"
        f"cpp = '{compiler_cxx}'\n"
        f"ar = '{ar}'\n"
        f"strip = '{strip}'\n"
        f"pkg-config = '{pkg_config}'\n\n"
        "[host_machine]\n"
        "system = 'darwin'\n"
        "cpu_family = 'aarch64'\n"
        "cpu = 'arm64'\n"
        "endian = 'little'\n\n"
        "[properties]\n"
        f"sys_root = '{sdk_path}'\n"
        f"pkg_config_libdir = ['{prefix}/lib/pkgconfig', '{prefix}/share/pkgconfig']\n\n"
        "[built-in options]\n"
        f"c_args = {flags}\n"
        f"c_link_args = {flags}\n"
        f"cpp_args = {flags}\n"
        f"cpp_link_args = {flags}\n"
    )
    return cross_file


def install_boost_headers(source_dir: Path, build_dir: Path, prefix: Path, version: str) -> None:
    source_headers = source_dir / "boost"
    if not source_headers.is_dir():
        raise SystemExit(f"Boost source has no boost/ header directory: {source_dir}")
    include_dir = prefix / "include"
    destination_headers = include_dir / "boost"
    shutil.copytree(source_headers, destination_headers, symlinks=True)

    cmake_dir = prefix / "lib/cmake" / f"Boost-{version}"
    cmake_dir.mkdir(parents=True, exist_ok=True)
    config = cmake_dir / "BoostConfig.cmake"
    config.write_text(
        "get_filename_component(_BOOST_PREFIX \"${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)\n"
        "set(Boost_FOUND TRUE)\n"
        f"set(Boost_VERSION \"{version}\")\n"
        f"set(Boost_VERSION_STRING \"{version}\")\n"
        "if(NOT TARGET Boost::headers)\n"
        "  add_library(Boost::headers INTERFACE IMPORTED)\n"
        "  set_target_properties(Boost::headers PROPERTIES INTERFACE_INCLUDE_DIRECTORIES \"${_BOOST_PREFIX}/include\")\n"
        "endif()\n"
        "if(NOT TARGET Boost::boost)\n"
        "  add_library(Boost::boost INTERFACE IMPORTED)\n"
        "  set_target_properties(Boost::boost PROPERTIES INTERFACE_LINK_LIBRARIES Boost::headers)\n"
        "endif()\n"
        "if(NOT TARGET Boost::disable_autolinking)\n"
        "  add_library(Boost::disable_autolinking INTERFACE IMPORTED)\n"
        "  set_target_properties(Boost::disable_autolinking PROPERTIES INTERFACE_COMPILE_DEFINITIONS BOOST_ALL_NO_LIB)\n"
        "endif()\n"
    )
    version_config = cmake_dir / "BoostConfigVersion.cmake"
    version_config.write_text(
        f"set(PACKAGE_VERSION \"{version}\")\n"
        "if(PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)\n"
        "  set(PACKAGE_VERSION_COMPATIBLE FALSE)\n"
        "else()\n"
        "  set(PACKAGE_VERSION_COMPATIBLE TRUE)\n"
        "  if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)\n"
        "    set(PACKAGE_VERSION_EXACT TRUE)\n"
        "  endif()\n"
        "endif()\n"
    )
    build_dir.mkdir(parents=True, exist_ok=True)
    installed_files = [path for path in destination_headers.rglob("*") if path.is_file() or path.is_symlink()]
    installed_files.extend((config, version_config))
    (build_dir / "install_manifest.txt").write_text("\n".join(map(str, installed_files)) + "\n")


def merge_staged_install(stage: Path, prefix: Path, build_dir: Path) -> None:
    staged_prefix = stage / prefix.relative_to("/")
    if not staged_prefix.is_dir():
        raise SystemExit(f"staged install did not contain dependency prefix: {staged_prefix}")
    installed: list[str] = []
    for source in staged_prefix.rglob("*"):
        relative = source.relative_to(staged_prefix)
        destination = prefix / relative
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        elif source.is_symlink():
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists() or destination.is_symlink():
                destination.unlink()
            destination.symlink_to(os.readlink(source))
            installed.append(str(destination))
        elif source.is_file():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            installed.append(str(destination))
    (build_dir / "install_manifest.txt").write_text("\n".join(installed) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("device", "simulator"))
    parser.add_argument("packages", nargs="*", help="package names; defaults to all")
    parser.add_argument("--clean", action="store_true", help="discard matching build directories")
    args = parser.parse_args()

    repo = Path(capture(["git", "rev-parse", "--show-toplevel"]))
    ios = repo / "packaging/ios"
    toolchain = ios / "cmake/KritaIOSPlatform.cmake"
    manifest_path = ios / "deps/dependencies.json"
    manifest = json.loads(manifest_path.read_text())
    packages_by_name = {package["name"]: package for package in manifest["packages"]}
    requested = args.packages or list(packages_by_name)
    packages = resolve_packages(packages_by_name, requested)

    run([str(ios / "scripts/check-host.sh")])

    target_root = repo / "build-ios/deps" / args.mode
    source_root = repo / "build-ios/deps/sources"
    prefix = target_root / "prefix"
    build_root = target_root / "build"
    stamp_root = target_root / "stamps"
    for directory in (source_root, prefix, build_root, stamp_root):
        directory.mkdir(parents=True, exist_ok=True)

    platform = "DEVICE" if args.mode == "device" else "SIMULATOR"
    sdk = "iphoneos" if args.mode == "device" else "iphonesimulator"
    environment = os.environ.copy()
    environment.update(
        {
            "PKG_CONFIG_PATH": "",
            "PKG_CONFIG_LIBDIR": f"{prefix}/lib/pkgconfig:{prefix}/share/pkgconfig",
            "PKG_CONFIG_SYSROOT_DIR": capture(["xcrun", "--sdk", sdk, "--show-sdk-path"]),
        }
    )

    for package in packages:
        name = package["name"]
        source_output = capture(
            ["nix", "build", "--no-link", "--print-out-paths", f".#{package['source_flake_attr']}"],
            cwd=repo,
        ).splitlines()[-1]
        source = Path(source_output)
        stamp = stamp_root / f"{name}.json"
        package_fingerprint = fingerprint(package, source, toolchain, args.mode, repo)
        artifacts = [prefix / artifact for artifact in package.get("artifacts", [])]
        required_paths = artifacts + [prefix / path for path in package.get("required_paths", [])]

        if not args.clean and stamp.exists() and all(path.exists() for path in required_paths):
            state = json.loads(stamp.read_text())
            if state.get("fingerprint") == package_fingerprint:
                print(f"skip {name}: fingerprint and artifacts match")
                continue

        source_dir = materialize_source(source, source_root / f"{name}-{package['version']}")
        build_dir = build_root / name
        if build_dir.exists():
            remove_previous_install(build_dir, prefix)
            shutil.rmtree(build_dir)

        build_system = package.get("build_system", "cmake")
        if build_system == "cmake":
            cmake_source = repo / package["cmake_source_dir"] if "cmake_source_dir" in package else source_dir
            cmake_args = [argument.format(source_dir=source_dir) for argument in package["cmake_args"]]
            configure = [
                "cmake",
                "-S",
                str(cmake_source),
                "-B",
                str(build_dir),
                "-G",
                "Ninja",
                f"-DCMAKE_TOOLCHAIN_FILE={toolchain}",
                f"-DKRITA_IOS_PLATFORM={platform}",
                f"-DCMAKE_INSTALL_PREFIX={prefix}",
                f"-DCMAKE_PREFIX_PATH={prefix}",
                f"-DCMAKE_FIND_ROOT_PATH={prefix}",
                "-DCMAKE_IGNORE_PREFIX_PATH=/usr/local;/opt/homebrew",
                "-DCMAKE_BUILD_TYPE=Release",
                "-DCMAKE_INSTALL_LIBDIR=lib",
                "-DCMAKE_INSTALL_INCLUDEDIR=include",
                "-DCMAKE_INSTALL_BINDIR=bin",
                "-DCMAKE_INSTALL_DATADIR=share",
                "-DBUILD_SHARED_LIBS=OFF",
                "-DBUILD_TESTING=OFF",
                *cmake_args,
            ]
            run(configure, env=environment)
            run(["cmake", "--build", str(build_dir), "--parallel"], env=environment)
            run(["cmake", "--install", str(build_dir)], env=environment)
        elif build_system == "boost_headers":
            print(f"+ install Boost headers {source_dir} -> {prefix}", flush=True)
            install_boost_headers(source_dir, build_dir, prefix, package["version"])
        elif build_system == "meson":
            build_dir.mkdir(parents=True)
            cross_file = write_meson_cross_file(build_dir, prefix, sdk, args.mode)
            meson_args = [argument.format(source_dir=source_dir) for argument in package["meson_args"]]
            run(
                [
                    "meson",
                    "setup",
                    str(build_dir),
                    str(source_dir),
                    "--cross-file",
                    str(cross_file),
                    "--prefix",
                    str(prefix),
                    "--libdir",
                    "lib",
                    "--buildtype",
                    "release",
                    "--default-library",
                    "static",
                    *meson_args,
                ],
                env=environment,
            )
            run(["meson", "compile", "-C", str(build_dir)], env=environment)
            run(["meson", "install", "-C", str(build_dir), "--no-rebuild"], env=environment)
            record_meson_install(build_dir, prefix)
        elif build_system == "autotools":
            build_dir.mkdir(parents=True)
            sdk_path = capture(["xcrun", "--sdk", sdk, "--show-sdk-path"])
            minimum_flag = "-miphoneos-version-min=17.0" if args.mode == "device" else "-mios-simulator-version-min=17.0"
            target_flags = f"-arch arm64 -isysroot {sdk_path} {minimum_flag}"
            autotools_environment = environment.copy()
            autotools_environment.update(
                {
                    "CC": capture(["xcrun", "--sdk", sdk, "--find", "clang"]),
                    "CXX": capture(["xcrun", "--sdk", sdk, "--find", "clang++"]),
                    "AR": capture(["xcrun", "--sdk", sdk, "--find", "ar"]),
                    "RANLIB": capture(["xcrun", "--sdk", sdk, "--find", "ranlib"]),
                    "STRIP": capture(["xcrun", "--sdk", sdk, "--find", "strip"]),
                    "CFLAGS": target_flags,
                    "CXXFLAGS": target_flags,
                    "CPPFLAGS": f"-I{prefix}/include -I{prefix}/include/freetype2",
                    "LDFLAGS": f"{target_flags} -L{prefix}/lib",
                    "SDKROOT": sdk_path,
                }
            )
            autotools_environment["CPP"] = f"{autotools_environment['CC']} -E {target_flags}"
            autotools_environment.update(package.get("configure_cache", {}))
            configure_args = [argument.format(source_dir=source_dir, prefix=prefix) for argument in package["configure_args"]]
            run(
                [
                    str(source_dir / "configure"),
                    "--host=arm-apple-darwin",
                    f"--prefix={prefix}",
                    f"--libdir={prefix}/lib",
                    "--disable-shared",
                    "--enable-static",
                    *configure_args,
                ],
                cwd=build_dir,
                env=autotools_environment,
            )
            make_targets = package.get("make_targets", [[]])
            for target in make_targets:
                run(["make", f"-j{os.cpu_count() or 1}", *target], cwd=build_dir, env=autotools_environment)
            stage = build_dir / "stage"
            stage.mkdir()
            install_targets = package.get("make_install_targets", [["install"]])
            for target in install_targets:
                run(["make", *target, f"DESTDIR={stage}"], cwd=build_dir, env=autotools_environment)
            merge_staged_install(stage, prefix, build_dir)
        else:
            raise SystemExit(f"unsupported build system for {name}: {build_system}")

        for relative_path in package.get("relocate_cmake", []):
            cmake_file = prefix / relative_path
            if not cmake_file.is_file():
                raise SystemExit(f"CMake relocation file is missing: {cmake_file}")
            cmake_file.write_text(cmake_file.read_text().replace(str(prefix), "${_IMPORT_PREFIX}"))

        missing = [path for path in required_paths if not path.exists()]
        if missing:
            raise SystemExit(f"{name} did not install required paths: {', '.join(map(str, missing))}")

        for artifact in artifacts:
            run([str(ios / "scripts/inspect-apple-archive.sh"), args.mode, str(artifact)])

        stamp.write_text(
            json.dumps(
                {
                    "name": name,
                    "version": package["version"],
                    "mode": args.mode,
                    "source": str(source.resolve()),
                    "fingerprint": package_fingerprint,
                    "artifacts": [str(path.relative_to(prefix)) for path in artifacts],
                    "required_paths": [str(path.relative_to(prefix)) for path in required_paths],
                },
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )

    print(f"dependency prefix: {prefix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
