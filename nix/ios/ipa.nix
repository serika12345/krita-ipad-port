{
  coreutils,
  findutils,
  gnugrep,
  krita-ios-app,
  lib,
  python3,
  stdenvNoCC,
  unzip,
  zip,
}:

stdenvNoCC.mkDerivation {
  pname = "krita-ios-unsigned-ipa";
  inherit (krita-ios-app) version;

  dontUnpack = true;
  strictDeps = true;
  nativeBuildInputs = [
    coreutils
    findutils
    gnugrep
    python3
    unzip
    zip
  ];

  installPhase = ''
    runHook preInstall

    stage="$NIX_BUILD_TOP/ipa-stage"
    mkdir -p "$stage/Payload" "$out"
    cp -R ${krita-ios-app}/krita.app "$stage/Payload/krita.app"

    if find "$stage" -type l -print -quit | grep -q .; then
      echo "error: IPA stage contains a symlink" >&2
      exit 1
    fi
    find "$stage" -exec touch -h -t 198001010000 {} +

    entry_list="$NIX_BUILD_TOP/ipa-entries"
    (
      cd "$stage"
      {
        find Payload -type d -exec printf '%s/\n' {} \;
        find Payload -type f -print
      } | LC_ALL=C sort > "$entry_list"
      zip -X -9 "$out/Krita-iPad-unsigned.ipa" -@ < "$entry_list"
    )

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
        runHook preInstallCheck

        ipa="$out/Krita-iPad-unsigned.ipa"
        unzip -tq "$ipa"

        if unzip -Z1 "$ipa" | grep -Eq '(^|/)(__MACOSX|_CodeSignature)(/|$)|embedded\.mobileprovision$'; then
          echo "error: unsigned IPA contains signing or Finder metadata" >&2
          exit 1
        fi

        ${python3}/bin/python3 - "$ipa" <<'PY'
    import hashlib
    import sys
    import zipfile

    ipa = sys.argv[1]
    with zipfile.ZipFile(ipa) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if not names or any(not name.startswith("Payload/") for name in names):
            raise SystemExit("IPA entries must all be below Payload/")
        required = {
            "Payload/krita.app/Info.plist",
            "Payload/krita.app/krita",
            "Payload/krita.app/share/krita/actions/krita.action",
            "Payload/krita.app/share/krita/bundles/Krita_4_Default_Resources.bundle",
        }
        missing = sorted(required.difference(names))
        if missing:
            raise SystemExit(f"IPA is missing required entries: {missing}")
        if names != sorted(names):
            raise SystemExit("IPA central directory is not byte-order sorted")
        if any(entry.date_time != (1980, 1, 1, 0, 0, 0) for entry in entries):
            raise SystemExit("IPA contains a non-normalized ZIP timestamp")

    with open(ipa, "rb") as handle:
        print(f"unsigned IPA sha256: {hashlib.sha256(handle.read()).hexdigest()}")
    PY

        runHook postInstallCheck
  '';

  passthru = {
    app = krita-ios-app;
    bundleIdentifier = krita-ios-app.bundleIdentifier;
    unsigned = true;
  };

  meta = {
    description = "Deterministic unsigned Krita IPA for arm64 iPadOS";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-darwin" ];
  };
}
