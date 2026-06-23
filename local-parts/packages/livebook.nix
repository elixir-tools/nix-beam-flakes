{lib, ...}: {
  perSystem = {pkgs, ...}: let
    beamPkgs = pkgs.beam.packages.erlang_27.extend (_final: prev: {
      rebar3 = prev.rebar3.overrideAttrs (_old: {doCheck = false;});
    });
  in {
    packages = let
      inherit (beamPkgs) erlang rebar3;
      elixir = beamPkgs.elixir_1_18;
      hex = beamPkgs.hex.override {inherit elixir;};
      pname = "livebook";

      mixFodDeps = beamPkgs.fetchMixDeps {
        inherit elixir src version;
        pname = "mix-deps-${pname}";
        sha256 = "sha256-T74RmUORPdNibxdl+bRGyYyOdnKs1TyjtdutLtfLNLM=";
      };
      src = pkgs.fetchFromGitHub {
        owner = "livebook-dev";
        repo = "livebook";
        rev = "v${version}";
        sha256 = "sha256-cIFnGUJ8yRnEBL9eu4Jpg1sMlTV1t/ybhHusLSFdZEY=";
      };
      # https://github.com/livebook-dev/livebook/releases
      version = "0.19.8";
    in {
      livebook = beamPkgs.mixRelease {
        buildInputs = [];
        nativeBuildInputs = [pkgs.makeWrapper];

        inherit elixir hex mixFodDeps pname src version;

        installPhase = ''
          mix escript.build

          mkdir -p $out/bin
          cp ./livebook $out/bin

          wrapProgram $out/bin/livebook \
            --prefix PATH : ${lib.makeBinPath [elixir erlang]} \
            --set MIX_REBAR3 ${rebar3}/bin/rebar3
        '';

        meta.mainProgram = "livebook";
      };

      livebook_bumblebee = beamPkgs.mixRelease {
        buildInputs = [];
        nativeBuildInputs = [pkgs.makeWrapper];

        inherit elixir hex mixFodDeps pname src version;

        installPhase = ''
          mix escript.build

          mkdir -p $out/bin
          cp ./livebook $out/bin

          wrapProgram $out/bin/livebook \
            --prefix PATH : ${lib.makeBinPath ([elixir erlang] ++ (with pkgs; [cmake gcc gnumake]))} \
            --set MIX_REBAR3 ${rebar3}/bin/rebar3
        '';

        meta.mainProgram = "livebook";
      };
    };
  };
}
