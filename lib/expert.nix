{
  beamPackages,
  callPackages,
  fetchFromGitHub,
  lib,
  makeWrapper,
  runCommandLocal,
}: let
  inherit (import ./expert-source.nix {inherit fetchFromGitHub;}) src version;

  beam = beamPackages.extend (_: prev: {
    rebar = prev.rebar.overrideAttrs (_: {doCheck = false;});
    rebar3 = prev.rebar3.overrideAttrs (_: {doCheck = false;});
  });

  engineDeps = callPackages "${src}/apps/engine/deps.nix" {
    inherit lib;
    beamPackages = beam;
  };

  mixNixDeps = callPackages "${src}/apps/expert/deps.nix" {
    inherit lib;
    beamPackages = beam;
  };

  expert = beam.mixRelease {
    pname = "expert";
    inherit src version mixNixDeps;

    mixReleaseName = "plain";

    preConfigure = ''
      mkdir -p apps/engine/deps
      ${lib.concatMapAttrsStringSep "\n" (name: dep: ''
          dep_path="apps/engine/deps/${name}"
          if [ -d "${dep}/src" ]; then
            ln -sv ${dep}/src $dep_path
          fi
        '')
        engineDeps}

        cd apps/expert
    '';

    postInstall = ''
      mv $out/bin/plain $out/bin/expert
      wrapProgram $out/bin/expert --add-flag "eval" --add-flag "System.no_halt(true); Application.ensure_all_started(:xp_expert)"
    '';

    removeCookie = false;

    passthru = {
      inherit engineDeps mixNixDeps;

      withEngine = engine:
        runCommandLocal "expert-with-engine" {
          nativeBuildInputs = [makeWrapper];
          meta.mainProgram = "expert";
        } ''
          mkdir -p $out/bin
          makeWrapper ${expert}/bin/expert $out/bin/expert \
            --set EXPERT_PREBUILT_ENGINE_PATH ${engine}
        '';
    };

    meta.mainProgram = "expert";
  };
in
  expert
