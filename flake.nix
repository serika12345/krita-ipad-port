{
  description = "Reproducible host tools for the Krita iPadOS port";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          bash
          cmake
          coreutils
          file
          git
          gnugrep
          gnused
          jq
          ninja
          nixfmt
          pkg-config
          python3
        ];

        shellHook = ''
          export KRITA_IOS_REPO_ROOT="$PWD"
          export KRITA_IOS_BUILD_ROOT="$PWD/build-ios"
          export KRITA_IOS_LOG_ROOT="$PWD/logs/ios"
          echo "Krita iPadOS development shell"
          echo "  host check: packaging/ios/scripts/check-host.sh"
          echo "  smoke test: packaging/ios/scripts/build-smoke.sh device"
        '';
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
