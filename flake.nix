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
        ];

        profile = ''
          export USE_CCACHE=1
          export ANDROID_JAVA_HOME=${pkgs.jdk11.home}
          export JAVA_HOME=${pkgs.jdk11.home}
          # this fix nvim terminal report error
          # since default one /nix/store/.../bash-5.3p9/bin/bash without readline support
          export SHELL=/usr/bin/bash
        '';

      }).env;
    };
}
