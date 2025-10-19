{
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    eval = flake-parts-lib.evalFlakeModule {
      inherit inputs;
      specialArgs = {
        inherit pkgs;
        beam-flake-lib = self.lib;
      };
    } {imports = [../parts/all-parts.nix];};

    filterOptions = option:
      option
      // {
        visible = lib.hasPrefix "perSystem.beamWorkspace" option.name;
      };

    optionsDoc = pkgs.nixosOptionsDoc {
      options = builtins.removeAttrs eval.options [
        # Upstream flake-parts
        "_module"
        "flake"
        "perInput"
        # Focused via filterOptions instead
        # "perSystem"
        "systems"
        "transposition"
      ];
      documentType = "none";
      warningsAreErrors = false;
      transformOptions = filterOptions;
    };
  in {
    packages.optionsDoc = optionsDoc.optionsCommonMark;
  };
}
