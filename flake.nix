{
  description = "A minimal development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = (pkgs.buildFHSEnv {
        name = "aosp-env";
        targetPkgs = pkgs: with pkgs; [
          # unix
          bash
          bashdb

          # Version Control
          git
          git-repo

          # Build System and Code Generation
          gnumake
          m4
          bison
          flex
          gperf
          ccache

          # System Administration and Performance
          procps
          nettools
          schedtool
          util-linux

          # Network, Security, and Synchronization
          curl
          openssl
          gnupg
          rsync

          # Compression Tools
          zip
          unzip
          lzop

          # Programming Languages and Runtimes
          python3
          perl
          jdk11
          xmlstarlet

          # Development Libraries
          libxml2
          zlib  # libz.so.1 required by the prebuilt clang (build/kati/build.sh)
          gcc  # crtbegin.o + libgcc for linking with the prebuilt clang
          glibc.dev  # /usr/include (glibc headers) + crt1.o for the prebuilt clang
        ];

        profile = ''
          export USE_CCACHE=1
          export ANDROID_JAVA_HOME=${pkgs.jdk11.home}
          export JAVA_HOME=${pkgs.jdk11.home}
          # this fix nvim terminal report error
          # since default one /nix/store/.../bash-5.3p9/bin/bash without readline support
          export SHELL=/usr/bin/bash
          tcd() {
            local target="$1"
            local current_dir="$(pwd)"

            while [ "$current_dir" != "/" ]; do
              if [ -e "$current_dir/$target" ]; then
                cd "$current_dir"
                return 0
              fi
              current_dir="$(dirname "$current_dir")"
            done

            echo "No parent directory containing $target found; staying in $(pwd)."
            return 1
          }

          export PATH="$(tcd flake.nix && readlink --canonicalize-missing code/prebuilts/go/linux-x86/bin):$PATH"
          export PATH="$(tcd flake.nix && readlink --canonicalize-missing bin):$PATH"
        '';

      }).env;
    };
}
