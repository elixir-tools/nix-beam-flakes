{
  description = "Nix-based BEAM toolchain management";

  nixConfig = {
    extra-substituters = [
      "https://nix-beam-flakes.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-beam-flakes.cachix.org-1:iRMzLmb/dZFw7v08Rp3waYlWqYZ8nR3fmtFwq2prdk4="
    ];
  };

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }: let
    systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    beamFlakesLib = import ./lib {inherit (nixpkgs) lib;};
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [./parts/all-parts.nix ./local-parts];
      inherit systems;

      flake = {
        flakeModule = ./parts/all-parts.nix;

        perSystem = {pkgs, ...}: {
          formatter = pkgs.alejandra;
        };

        packages =
          nixpkgs.lib.genAttrs systems
          (system: let
            exp = beamFlakesLib.expertPackages (import nixpkgs {inherit system;});
          in {
            inherit (exp) expert engine expert-with-engine;
          });

        templates = {
          default = {
            path = ./templates/default;
            description = "An environment suitable for developing Elixir applications";
          };

          phoenix = {
            path = ./templates/phoenix;
            description = "An environment suitable for developing Phoenix 1.7 applications";
          };
        };
      };
    };
}
