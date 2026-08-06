{
  python3,
  runCommand,
  zip,
}:

runCommand "krita-ios-ipa-permissions-check"
  {
    nativeBuildInputs = [
      python3
      zip
    ];
  }
  ''
    python3 ${./test-ipa-permissions.py} ${../ipa-permissions.py} ${zip}/bin/zip
    touch "$out"
  ''
