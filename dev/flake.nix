{
  description = "Contributor environment for Nix-based BEAM toolchain management";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      imports = [
        ./checksums
        inputs.git-hooks.flakeModule
      ];

      perSystem =
        {
          config,
          lib,
          pkgs,
          system,
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.just
            ]
            ++ (
              with inputs.git-hooks.packages.${system};
              [
                nixfmt
                pre-commit
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [ statix ]
            );
            shellHook = config.pre-commit.installationScript;
          };

          formatter = pkgs.nixfmt-tree;

          packages.gcroot = pkgs.linkFarmFromDrvs "beam-overlay-dev" [
            config.devShells.default.inputDerivation
          ];

          pre-commit = {
            settings = {
              rootSrc = lib.mkForce ./..;
              hooks = {
                nixfmt.enable = true;
                deadnix.enable = true;
                prettier.enable = true;
                prettier.excludes = [ "flake.lock" ];
                statix = {
                  enable = pkgs.stdenv.isLinux;
                  settings = {
                    ignore = [ ".direnv/*" ];
                  };
                };
              };
            };
          };
        };
    };
}
