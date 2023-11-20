# Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  description = "Ghaf - Documentation and implementation for TII SSRC Secure Technologies Ghaf Framework";

  nixConfig = {
    extra-trusted-substituters = [
      "https://cache.vedenemo.dev"
      "https://cache.ssrcdevops.tii.ae"
    ];
    extra-trusted-public-keys = [
      "cache.vedenemo.dev:8NhplARANhClUSWJyLVk4WMyy1Wb4rhmWW2u8AejH9E="
      "cache.ssrcdevops.tii.ae:oOrzj9iCppf+me5/3sN/BxEkp5SaFkHfKTPPZ97xXQk="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    jetpack-nixos = {
      url = "github:anduril/jetpack-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    flake-parts,
    nixos-generators,
    nixos-hardware,
    microvm,
    jetpack-nixos,
    lanzaboote,
  }: let
    systems = with flake-utils.lib.system; [
      x86_64-linux
      aarch64-linux
      riscv64-linux
    ];
    lib = nixpkgs.lib.extend (final: _prev: {
      ghaf = import ./lib {
        inherit self nixpkgs;
        lib = final;
      };
    });
  in
    # Combine list of attribute sets together
    lib.foldr lib.recursiveUpdate {} [
      # Documentation
      (flake-utils.lib.eachSystem systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.doc = pkgs.callPackage ./docs {
          revision = lib.version;
          options = let
            cfg = nixpkgs.lib.nixosSystem {
              inherit system;
              modules =
                lib.ghaf.modules
                ++ [
                  jetpack-nixos.nixosModules.default
                  microvm.nixosModules.host
                  lanzaboote.nixosModules.lanzaboote
                ];
            };
          in
            cfg.options;
        };

        formatter = pkgs.alejandra;

        devShells.kernel = pkgs.mkShell {
          packages = [
            pkgs.ncurses
            pkgs.pkg-config
            pkgs.python3
            pkgs.python3Packages.pip
          ];
          inputsFrom = [pkgs.linux_latest];
          shellHook = ''
            export src=${pkgs.linux_latest.src}
            if [ ! -d "linux-${pkgs.linux_latest.version}" ]; then
              unpackPhase
              patchPhase
            fi
            cd linux-${pkgs.linux_latest.version}

            # python3+pip for kernel-hardening-checker
            export PIP_PREFIX=$(pwd)/_build/pip_packages
            export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
            export PATH="$PIP_PREFIX/bin:$PATH"

            # install kernel-hardening-checker via pip under "linux-<version" for
            # easy clean-up with directory removal - if not already installed
            if [ ! -f "_build/pip_packages/bin/kernel-hardening-checker" ]; then
              python3 -m pip install git+https://github.com/a13xp0p0v/kernel-hardening-checker
            fi

            export PS1="[ghaf-kernel-devshell:\w]$ "
          '';
        };
      }))

      # ghaf lib
      {
        lib = lib.ghaf;
      }

      # Target configurations
      (import ./targets {inherit self lib nixpkgs nixos-generators nixos-hardware microvm jetpack-nixos lanzaboote;})

      # User apps
      (import ./user-apps {inherit lib nixpkgs flake-utils;})

      # Hydra jobs
      (import ./hydrajobs.nix {inherit self lib;})

      #templates
      (import ./templates)
    ];
}
