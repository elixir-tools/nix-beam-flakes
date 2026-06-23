{
  beamPackages,
  callPackages,
  fetchFromGitHub,
  git,
  lib,
  toolchains ? {},
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

  mixEnv = "prod";
in
  beam.mixRelease {
    pname = "expert-engine";
    inherit src version mixEnv;

    nativeBuildInputs = [git];
    mixNixDeps = {};
    passthru = toolchains;

    preConfigure = ''
      export HOME="$TMPDIR"
      mkdir -p apps/engine/deps
      ${lib.concatMapAttrsStringSep "\n" (name: dep: ''
          cp -rL --no-preserve=mode,ownership ${dep.src} apps/engine/deps/${name}
          (
            cd apps/engine/deps/${name}
            git init -q
            git add -A
            git -c user.email=expert@localhost -c user.name=expert commit -qm vendored
          )
        '')
        engineDeps}

      cd apps/engine
    '';

    buildPhase = ''
      runHook preBuild

      mix do compile --no-deps-check, namespace \
        "$PWD/_build/${mixEnv}" "$PWD/_build/${mixEnv}_ns" --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib"
      cp -r "$PWD/_build/${mixEnv}_ns/lib/"xp_* "$out/lib/"

      runHook postInstall
    '';

    postFixup = "";

    meta.description = "Pre-built, namespaced Expert engine for a specific Elixir/OTP toolchain";
  }
