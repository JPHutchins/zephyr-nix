{
  description = "Zephyr RTOS build environment and toolchain for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    west-nix.url = "github:JPHutchins/west-nix";
  };

  outputs = { self, nixpkgs, flake-utils, west-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          zephyr-sdk = pkgs.callPackage ./pkgs/zephyr-sdk { };
          zephyr-sdk-minimal = pkgs.callPackage ./pkgs/zephyr-sdk {
            architectures = [ ];
          };
          zephyr-sdk-arm = pkgs.callPackage ./pkgs/zephyr-sdk {
            architectures = [ "arm" ];
          };
          zephyr-sdk-riscv = pkgs.callPackage ./pkgs/zephyr-sdk {
            architectures = [ "riscv64" ];
          };
          pylock = pkgs.callPackage ./pkgs/pylock { };
          zephyr-nix-update = pkgs.callPackage ./pkgs/zephyr-nix-update {
            inherit west-nix;
          };
        };

        lib = {
          # zephyr-nix core functions
          mkZephyrDependencies = import ./lib/mkZephyrDependencies.nix {
            inherit pkgs;
          };

          mkPythonEnv = import ./lib/mkPythonEnv {
            inherit pkgs;
          };

          mkCrossCCache = import ./lib/mkCrossCCache.nix {
            inherit pkgs;
          };

          # Re-exported from west-nix for convenience
          mkWestProjects = west-nix.lib.${system}.mkWestProjects;
          mkWestWorkspace = west-nix.lib.${system}.mkWestWorkspace;
          mkWestProject = west-nix.lib.${system}.mkWestProject;

          # Unified Zephyr environment
          mkZephyrEnv = import ./lib/mkZephyrEnv.nix {
            inherit pkgs;
            west-nix-lib = west-nix.lib.${system};
          };
        };

        # Development shell for working on zephyr-nix itself
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix-prefetch-scripts
            wget
            uv
          ];
        };
      }
    );
}
