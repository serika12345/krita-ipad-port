{
  lib,
  stdenvNoCC,
  coreutils,
  findutils,
  gnugrep,
  writeText,
}:

{
  pname,
  version,
  src,
  headerTrees,
  generatedFiles ? { },
  requiredPaths ? [ ],
  postInstallCheck ? "",
  passthru ? { },
  meta ? { },
}:

let
  relativePathIsSafe =
    path:
    lib.isString path
    && path != ""
    && builtins.match "[A-Za-z0-9][A-Za-z0-9._+/-]*" path != null
    && !(lib.hasPrefix "/" path)
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" path
    );
  headerTreeIsValid =
    tree:
    lib.isAttrs tree
    &&
      builtins.attrNames tree == [
        "destination"
        "source"
      ]
    && relativePathIsSafe tree.source
    && relativePathIsSafe tree.destination;
  headerDestinations = map (tree: tree.destination) headerTrees;
  generatedPaths = builtins.attrNames generatedFiles;
  generatedFileEntries = lib.imap0 (index: path: {
    inherit path;
    source = writeText "${pname}-generated-${toString index}" generatedFiles.${path};
  }) generatedPaths;
  copyHeaderTree =
    tree:
    let
      source = lib.escapeShellArg tree.source;
      destination = lib.escapeShellArg tree.destination;
    in
    ''
      source_path=${source}
      destination_path="$out"/${destination}
      if ! test -d "$source_path"; then
        echo "error: header source tree is missing: $source_path" >&2
        exit 1
      fi
      unexpected_source_entry="$(find "$source_path" \( \
        -type l -o \( ! -type d ! -type f \) \
      \) -print -quit)"
      if test -n "$unexpected_source_entry"; then
        echo "error: header source tree contains a symlink or special file: $unexpected_source_entry" >&2
        exit 1
      fi
      if test -e "$destination_path"; then
        echo "error: header destination already exists: $destination_path" >&2
        exit 1
      fi
      mkdir -p "$(dirname "$destination_path")"
      cp -R -- "$source_path" "$destination_path"
    '';
  installGeneratedFile = entry: ''
    generated_path="$out"/${lib.escapeShellArg entry.path}
    if test -e "$generated_path"; then
      echo "error: generated destination already exists: $generated_path" >&2
      exit 1
    fi
    install -D -m 0444 -- ${lib.escapeShellArg (toString entry.source)} "$generated_path"
  '';
in
assert lib.assertMsg (
  lib.isString pname && pname != ""
) "iOS header package pname must be a non-empty string";
assert lib.assertMsg (
  lib.isString version && version != ""
) "iOS header package version must be a non-empty string";
assert lib.assertMsg
  (lib.isList headerTrees && headerTrees != [ ] && lib.all headerTreeIsValid headerTrees)
  "iOS header package headerTrees must contain only exact source/destination relative-path mappings";
assert lib.assertMsg (
  lib.length (lib.unique headerDestinations) == lib.length headerDestinations
) "iOS header package destinations must be unique";
assert lib.assertMsg (lib.isAttrs generatedFiles)
  "iOS header package generatedFiles must be an attribute set";
assert lib.assertMsg (lib.all relativePathIsSafe generatedPaths)
  "iOS header package generated file paths must be safe relative paths";
assert lib.assertMsg (lib.all lib.isString (
  builtins.attrValues generatedFiles
)) "iOS header package generated file contents must all be strings";
assert lib.assertMsg (
  lib.isList requiredPaths && lib.all relativePathIsSafe requiredPaths
) "iOS header package requiredPaths must contain only safe relative paths";
assert lib.assertMsg (lib.isString postInstallCheck)
  "iOS header package postInstallCheck must be a string";
assert lib.assertMsg (lib.isAttrs passthru) "iOS header package passthru must be an attribute set";
assert lib.assertMsg (
  !(passthru ? iosTargetIndependent) && !(passthru ? iosToolchainIdentity)
) "iOS header package target-independence passthru is fixed by the builder";
assert lib.assertMsg (lib.isAttrs meta) "iOS header package meta must be an attribute set";

stdenvNoCC.mkDerivation {
  inherit
    pname
    version
    src
    postInstallCheck
    ;

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  dontStrip = true;

  phases = [
    "unpackPhase"
    "installPhase"
    "installCheckPhase"
  ];

  nativeBuildInputs = [
    coreutils
    findutils
    gnugrep
  ];

  installPhase = ''
    runHook preInstall

    ${lib.concatMapStringsSep "\n" copyHeaderTree headerTrees}
    ${lib.concatMapStringsSep "\n" installGeneratedFile generatedFileEntries}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # Package checks are observational. Hash the complete output before and
    # after the hook so a caller cannot accidentally mutate files after the
    # common invariants have inspected them.
    snapshot_output() {
      find "$out" -type f -print0 \
        | sort -z \
        | xargs -0 -r sha256sum --zero
    }
    expected_snapshot="$NIX_BUILD_TOP/header-package-output.sha256"
    actual_snapshot="$NIX_BUILD_TOP/header-package-output-after-check.sha256"
    snapshot_output > "$expected_snapshot"
    runHook postInstallCheck
    snapshot_output > "$actual_snapshot"
    expected_digest="$(sha256sum "$expected_snapshot" | cut -d ' ' -f 1)"
    actual_digest="$(sha256sum "$actual_snapshot" | cut -d ' ' -f 1)"
    if test "$expected_digest" != "$actual_digest"; then
      echo "error: iOS header package check hook modified the output" >&2
      exit 1
    fi

    for relative_path in ${lib.escapeShellArgs requiredPaths}; do
      if ! test -e "$out/$relative_path"; then
        echo "error: required header-package output is missing: $relative_path" >&2
        exit 1
      fi
    done

    unexpected_artifact="$(find "$out" \( \
      -type f \( \
        -name '*.a' -o -name '*.o' -o -name '*.dylib' -o \
        -name '*.so' -o -name '*.so.*' \
      \) -o -type d -name '*.framework' \
    \) -print -quit)"
    if test -n "$unexpected_artifact"; then
      echo "error: pure header package contains a compiled artifact: $unexpected_artifact" >&2
      exit 1
    fi

    unexpected_output_entry="$(find "$out" \( \
      -type l -o \( ! -type d ! -type f \) \
    \) -print -quit)"
    if test -n "$unexpected_output_entry"; then
      echo "error: pure header package contains a symlink or special file: $unexpected_output_entry" >&2
      exit 1
    fi

    for relative_path in ${lib.escapeShellArgs generatedPaths}; do
      if grep -a -l -F "$NIX_BUILD_TOP" "$out/$relative_path"; then
        echo "error: generated header-package metadata contains its temporary build directory" >&2
        exit 1
      fi
    done

  '';

  passthru = passthru // {
    iosTargetIndependent = true;
  };

  meta = {
    platforms = lib.platforms.all;
  }
  // meta;
}
