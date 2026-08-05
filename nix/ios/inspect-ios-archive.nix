{ gawk, toolchain }:

''
  inspect_ios_archive_members() {
    archive="$1"
    expected_member_count="$2"
    archive_metadata="$(${toolchain.otool} -l "$archive")" || {
      echo "error: could not inspect static archive $archive" >&2
      return 1
    }

    ${gawk}/bin/awk \
      -v archive="$archive" \
      -v expected_member_count="$expected_member_count" \
      -v expected_minos="${toolchain.deploymentTarget}" \
      -v expected_sdk="${toolchain.sdkVersion}" '
        function fail(message) {
          printf "error: %s %s\\n", archive, message > "/dev/stderr"
          failed = 1
          exit 1
        }

        function verify_member() {
          if (member == "") {
            return
          }
          if (!has_build_version) {
            fail("member " member " has no LC_BUILD_VERSION command")
          }
          if (!has_ios_platform) {
            fail("member " member " is not an iOS device object")
          }
          if (!has_expected_minos) {
            fail("member " member " does not target iOS " expected_minos)
          }
          if (!has_expected_sdk) {
            fail("member " member " was not built with SDK " expected_sdk)
          }
          member_count++
        }

        /^[^[:space:]].*\):$/ {
          verify_member()
          member = $0
          has_build_version = 0
          has_ios_platform = 0
          has_expected_minos = 0
          has_expected_sdk = 0
          next
        }
        $1 == "cmd" && $2 == "LC_BUILD_VERSION" {
          has_build_version = 1
          next
        }
        $1 == "platform" && $2 == "2" {
          has_ios_platform = 1
          next
        }
        $1 == "minos" && $2 == expected_minos {
          has_expected_minos = 1
          next
        }
        # The Clang integrated assembler writes `sdk n/a` even when the
        # platform and minimum iOS version were selected correctly.
        $1 == "sdk" && ($2 == expected_sdk || $2 == "n/a") {
          has_expected_sdk = 1
        }
        END {
          if (failed) {
            exit 1
          }
          verify_member()
          if (member_count != expected_member_count) {
            fail("contains " member_count " inspected objects; expected " expected_member_count)
          }
        }
      ' <<<"$archive_metadata"
  }
''
