{
  lib,
  writeShellScriptBin,
  toolchain,
}:

assert lib.assertMsg (toolchain ? sdkRoot) "qt-xcrun-shim requires toolchain.sdkRoot";
assert lib.assertMsg (toolchain ? sdkVersion) "qt-xcrun-shim requires toolchain.sdkVersion";
assert lib.assertMsg (toolchain ? xcodeVersion) "qt-xcrun-shim requires toolchain.xcodeVersion";
assert lib.assertMsg (
  toolchain ? xcodeBuildVersion
) "qt-xcrun-shim requires toolchain.xcodeBuildVersion";

writeShellScriptBin "xcrun" ''
  set -eu

  fail_unsafe_log_path() {
    printf 'qt-xcrun-shim: unsafe invocation log path: %s\n' "$log_path" >&2
    exit 64
  }

  build_top="''${NIX_BUILD_TOP:-}"
  if [ "''${KRITA_IOS_QT_XCRUN_LOG+x}" = "x" ]; then
    log_path="$KRITA_IOS_QT_XCRUN_LOG"
  else
    log_path="$build_top/qt-xcrun-shim.log"
  fi

  if [ -z "$log_path" ] || [ -z "$build_top" ]; then
    fail_unsafe_log_path
  fi

  case "$build_top" in
    /*) ;;
    *) fail_unsafe_log_path ;;
  esac

  case "$log_path" in
    "$build_top"/*) ;;
    *) fail_unsafe_log_path ;;
  esac

  case "$log_path" in
    *$'\n'* | *$'\r'* | */../* | */.. | */./* | */.) fail_unsafe_log_path ;;
  esac

  log_dir="''${log_path%/*}"
  if [ ! -d "$log_dir" ] \
    || [ -L "$log_path" ] \
    || { [ -e "$log_path" ] && [ ! -f "$log_path" ]; }; then
    fail_unsafe_log_path
  fi

  case "$*" in
    *$'\n'* | *$'\r'*)
      printf 'qt-xcrun-shim: invocation contains a line break\n' >&2
      exit 64
      ;;
  esac

  if ! printf '%s\n' "$*" >> "$log_path"; then
    printf 'qt-xcrun-shim: cannot append invocation log\n' >&2
    exit 73
  fi

  # Qt uses --sdk while CMake's Darwin platform module uses -sdk. Keep
  # their observed calls separate so a new query fails closed.
  if [ "$#" -eq 3 ] && [ "$2" = "iphoneos" ]; then
    case "$1:$3" in
      --sdk:--show-sdk-path | -sdk:--show-sdk-path)
        printf '%s\n' ${lib.escapeShellArg toolchain.sdkRoot}
        exit 0
        ;;
      --sdk:--show-sdk-version)
        printf '%s\n' ${lib.escapeShellArg toolchain.sdkVersion}
        exit 0
        ;;
    esac
  fi

  if [ "$#" -eq 2 ] \
    && [ "$1" = "xcodebuild" ] \
    && [ "$2" = "-version" ]; then
    printf 'Xcode %s\nBuild version %s\n' \
      ${lib.escapeShellArg toolchain.xcodeVersion} \
      ${lib.escapeShellArg toolchain.xcodeBuildVersion}
    exit 0
  fi

  printf 'qt-xcrun-shim: unsupported invocation:' >&2
  printf ' %s' "$@" >&2
  printf '\n' >&2
  exit 64
''
