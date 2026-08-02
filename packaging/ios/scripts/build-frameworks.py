#!/usr/bin/env python3
"""Build the pinned ECM and KDE Frameworks subset for iOS."""

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

BUILDER_SCHEMA = 1


def run(command: list[str], *, cwd: Path | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, check=True)


def capture(command: list[str], *, cwd: Path | None = None) -> str:
    return subprocess.check_output(command, cwd=cwd, text=True).strip()


def make_tree_writable(root: Path) -> None:
    if not root.exists():
        return
    for directory, _, filenames in os.walk(root):
        directory_path = Path(directory)
        directory_path.chmod(directory_path.stat().st_mode | stat.S_IWUSR | stat.S_IXUSR)
        for filename in filenames:
            path = directory_path / filename
            if not path.is_symlink():
                path.chmod(path.stat().st_mode | stat.S_IWUSR)


def remove_tree(path: Path, allowed_parent: Path) -> None:
    if path == allowed_parent:
        raise SystemExit(f"refusing to remove allowed parent itself: {path}")
    try:
        path.relative_to(allowed_parent)
    except ValueError as error:
        raise SystemExit(f"refusing to remove path outside {allowed_parent}: {path}") from error
    if path.exists():
        make_tree_writable(path)
        shutil.rmtree(path)


def materialize_source(source: Path, destination: Path) -> Path:
    remove_tree(destination, destination.parent)
    destination.mkdir(parents=True)
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True, symlinks=True)
    else:
        shutil.unpack_archive(str(source), str(destination))
    make_tree_writable(destination)
    children = list(destination.iterdir())
    if len(children) == 1 and children[0].is_dir():
        return children[0]
    return destination


def resolve_packages(
    all_packages: dict[str, dict[str, Any]], requested: list[str]
) -> list[dict[str, Any]]:
    resolved: list[dict[str, Any]] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name not in all_packages:
            raise SystemExit(f"unknown framework: {name}")
        if name in visited:
            return
        if name in visiting:
            raise SystemExit(f"framework dependency cycle at: {name}")
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
    if not manifest.is_file():
        return
    for entry in manifest.read_text().splitlines():
        installed = Path(entry)
        try:
            installed.relative_to(prefix)
        except ValueError as error:
            raise SystemExit(f"framework installed outside prefix: {installed}") from error
        if installed.is_file() or installed.is_symlink():
            installed.unlink()
    for directory in sorted(prefix.rglob("*"), key=lambda path: len(path.parts), reverse=True):
        if directory.is_dir():
            try:
                directory.rmdir()
            except OSError:
                pass


def package_fingerprint(
    package: dict[str, Any],
    source: Path,
    repo: Path,
    mode: str,
    dependency_stamps: list[Path],
) -> str:
    digest = hashlib.sha256()
    digest.update(str(BUILDER_SCHEMA).encode())
    digest.update(json.dumps(package, sort_keys=True).encode())
    digest.update(str(source.resolve()).encode())
    digest.update((repo / "packaging/ios/cmake/KritaIOSPlatform.cmake").read_bytes())
    digest.update((repo / "packaging/ios/scripts/build-frameworks.py").read_bytes())
    digest.update(mode.encode())
    digest.update(capture(["xcodebuild", "-version"]).encode())
    sdk = "iphoneos" if mode == "device" else "iphonesimulator"
    digest.update(capture(["xcrun", "--sdk", sdk, "--show-sdk-version"]).encode())
    for stamp in dependency_stamps:
        if not stamp.is_file():
            raise SystemExit(f"required build stamp is missing: {stamp}")
        digest.update(stamp.read_bytes())
    for patch in package.get("patches", []):
        digest.update((repo / patch).read_bytes())
    return digest.hexdigest()


def ensure_host_kconfig_compiler(
    repo: Path,
    source_dir: Path,
    source_output: Path,
    host_qt: Path,
    host_qttools: Path,
    host_ecm: Path,
) -> Path:
    host_root = repo / "build-ios/frameworks/host-tools"
    build_dir = host_root / "kconfig-build"
    cmake_dir = host_root / "cmake/KF6Config"
    targets_file = cmake_dir / "KF6ConfigCompilerTargets.cmake"
    stamp = host_root / "kconfig-input.sha256"
    digest = hashlib.sha256()
    digest.update(str(BUILDER_SCHEMA).encode())
    digest.update(str(source_output.resolve()).encode())
    digest.update(str(source_dir.resolve()).encode())
    digest.update(str(host_qt.resolve()).encode())
    digest.update(str(host_qttools.resolve()).encode())
    digest.update(str(host_ecm.resolve()).encode())
    expected = digest.hexdigest()

    if not stamp.is_file() or stamp.read_text().strip() != expected:
        remove_tree(build_dir, host_root)
        remove_tree(cmake_dir, host_root)
    build_dir.mkdir(parents=True, exist_ok=True)
    run(
        [
            "cmake",
            "-S",
            str(source_dir),
            "-B",
            str(build_dir),
            "-G",
            "Ninja",
            f"-DCMAKE_PREFIX_PATH={host_qt};{host_qttools};{host_ecm}",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS=OFF",
            "-DBUILD_TESTING=OFF",
            "-DBUILD_QCH=OFF",
            "-DKCONFIG_USE_GUI=OFF",
            "-DKCONFIG_USE_QML=OFF",
            "-DUSE_DBUS=OFF",
        ]
    )
    run(["cmake", "--build", str(build_dir), "--target", "kconfig_compiler", "--parallel"])
    candidates = [
        path
        for path in build_dir.rglob("kconfig_compiler_kf6")
        if path.is_file() and os.access(path, os.X_OK)
    ]
    if len(candidates) != 1:
        raise SystemExit(f"expected one host kconfig compiler, found: {candidates}")
    compiler = candidates[0]
    cmake_dir.mkdir(parents=True, exist_ok=True)
    targets_file.write_text(
        "if(NOT TARGET KF6::kconfig_compiler)\n"
        "  add_executable(KF6::kconfig_compiler IMPORTED GLOBAL)\n"
        f'  set_target_properties(KF6::kconfig_compiler PROPERTIES IMPORTED_LOCATION "{compiler}")\n'
        "endif()\n"
    )
    stamp.write_text(expected + "\n")
    return host_root / "cmake"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("device", "simulator"))
    parser.add_argument("packages", nargs="*", help="framework names; defaults to all")
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    repo = Path(capture(["git", "rev-parse", "--show-toplevel"]))
    ios = repo / "packaging/ios"
    manifest_path = ios / "frameworks/frameworks.json"
    manifest = json.loads(manifest_path.read_text())
    packages_by_name = {package["name"]: package for package in manifest["packages"]}
    requested = args.packages or list(packages_by_name)
    packages = resolve_packages(packages_by_name, requested)
    run([str(ios / "scripts/check-host.sh")])

    target_root = repo / "build-ios/frameworks" / args.mode
    prefix = target_root / "prefix"
    build_root = target_root / "build"
    stamp_root = target_root / "stamps"
    source_root = repo / "build-ios/frameworks/sources"
    qt_prefix = repo / "build-ios/qt" / args.mode / "prefix"
    dependency_prefix = repo / "build-ios/deps" / args.mode / "prefix"
    qt_stamp = repo / "build-ios/qt" / args.mode / "build-input.sha256"
    libintl_stamp = repo / "build-ios/deps" / args.mode / "stamps/libintl.json"

    if not (qt_prefix / "lib/cmake/Qt6/Qt6Config.cmake").is_file():
        raise SystemExit(f"target Qt is missing; run build-qt.sh {args.mode} first")
    if not (dependency_prefix / "lib/libintl.a").is_file():
        raise SystemExit(f"target libintl is missing; build dependency libintl for {args.mode}")
    for directory in (prefix, build_root, stamp_root, source_root):
        directory.mkdir(parents=True, exist_ok=True)

    platform = "DEVICE" if args.mode == "device" else "SIMULATOR"
    sources: dict[str, tuple[Path, Path]] = {}
    for package in packages:
        output = Path(
            capture(
                ["nix", "build", "--no-link", "--print-out-paths", f".#{package['source_flake_attr']}"],
                cwd=repo,
            ).splitlines()[-1]
        )
        destination = source_root / f"{package['name']}-{package['version']}"
        source_dir = materialize_source(output, destination)
        for patch in package.get("patches", []):
            run(["patch", "-p1", "-i", str(repo / patch)], cwd=source_dir)
        sources[package["name"]] = (output, source_dir)

    kconfig_output = Path(
        capture(["nix", "build", "--no-link", "--print-out-paths", ".#source-kconfig"], cwd=repo).splitlines()[-1]
    )
    kconfig_source = materialize_source(
        kconfig_output,
        source_root / f"host-kconfig-{packages_by_name['kconfig']['version']}",
    )
    host_qt = Path(
        capture(["nix", "build", "--no-link", "--print-out-paths", ".#host-qtbase"], cwd=repo).splitlines()[-1]
    )
    host_qttools = Path(
        capture(["nix", "build", "--no-link", "--print-out-paths", ".#host-qttools"], cwd=repo).splitlines()[-1]
    )
    host_ecm = Path(
        capture(["nix", "build", "--no-link", "--print-out-paths", ".#host-ecm"], cwd=repo).splitlines()[-1]
    )
    host_tooling = ensure_host_kconfig_compiler(
        repo, kconfig_source, kconfig_output, host_qt, host_qttools, host_ecm
    )

    common_stamps = [qt_stamp, libintl_stamp]
    for package in packages:
        name = package["name"]
        source_output, source_dir = sources[name]
        dependency_stamps = common_stamps + [
            stamp_root / f"{dependency}.json" for dependency in package["dependencies"]
        ]
        fingerprint = package_fingerprint(
            package, source_output, repo, args.mode, dependency_stamps
        )
        stamp = stamp_root / f"{name}.json"
        artifacts = [prefix / path for path in package.get("artifacts", [])]
        required_paths = artifacts + [prefix / path for path in package.get("required_paths", [])]
        if not args.clean and stamp.is_file() and all(path.exists() for path in required_paths):
            if json.loads(stamp.read_text()).get("fingerprint") == fingerprint:
                print(f"skip {name}: fingerprint and artifacts match")
                continue

        build_dir = build_root / name
        if build_dir.exists():
            remove_previous_install(build_dir, prefix)
            remove_tree(build_dir, build_root)
        configure = [
            "cmake",
            "-S",
            str(source_dir),
            "-B",
            str(build_dir),
            "-G",
            "Ninja",
            f"-DCMAKE_INSTALL_PREFIX={prefix}",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_TESTING=OFF",
            "-DBUILD_SHARED_LIBS=OFF",
            "-DBUILD_QCH=OFF",
            "-DBUILD_PYTHON_BINDINGS=OFF",
            "-DBUILD_DESIGNERPLUGIN=OFF",
            "-DKDE_INSTALL_LIBDIR=lib",
            "-DKDE_INSTALL_LIBEXECDIR=libexec",
            "-DKDE_INSTALL_INCLUDEDIR=include",
            *package["cmake_args"],
        ]
        if not package.get("host_only"):
            configure.extend(
                [
                    f"-DCMAKE_TOOLCHAIN_FILE={ios / 'cmake/KritaIOSPlatform.cmake'}",
                    f"-DKRITA_IOS_PLATFORM={platform}",
                    f"-DCMAKE_PREFIX_PATH={prefix};{qt_prefix};{dependency_prefix}",
                    f"-DCMAKE_FIND_ROOT_PATH={prefix};{qt_prefix};{dependency_prefix}",
                    "-DCMAKE_IGNORE_PREFIX_PATH=/usr/local;/opt/homebrew",
                    "-DKF_IGNORE_PLATFORM_CHECK=ON",
                    f"-DKF6_HOST_TOOLING={host_tooling}",
                    f"-DQt6LinguistTools_DIR={host_qttools / 'lib/cmake/Qt6LinguistTools'}",
                ]
            )
        run(configure)
        run(["cmake", "--build", str(build_dir), "--parallel"])
        run(["cmake", "--install", str(build_dir)])

        missing = [path for path in required_paths if not path.exists()]
        if missing:
            raise SystemExit(f"{name} did not install required paths: {missing}")
        for artifact in artifacts:
            run([str(ios / "scripts/inspect-apple-archive.sh"), args.mode, str(artifact)])
        stamp.write_text(
            json.dumps(
                {
                    "name": name,
                    "version": package["version"],
                    "mode": args.mode,
                    "source": str(source_output.resolve()),
                    "fingerprint": fingerprint,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )

    print(f"framework prefix: {prefix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
