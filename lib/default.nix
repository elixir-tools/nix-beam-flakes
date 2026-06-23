{lib}: let
  inherit (builtins) concatStringsSep mapAttrs splitVersion;
  inherit (lib) take;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
  inherit (lib.trivial) importJSON pipe;
  inherit (findBasePackage) elixirBasePackage otpBasePackage;

  compatibleVersions = let
    elixirsFor = erlangVersion:
      pipe versions.elixir [
        (filterAttrs (n: _v: versionCompatible n erlangVersion))
        (mapAttrs (version: checksum: {inherit version checksum;}))
      ];
    genCompatiblePkgSet = version: checksum:
      nameValuePair version {
        erlang = {inherit version checksum;};
        elixirs = elixirsFor version;
      };
  in
    mapAttrs' genCompatiblePkgSet versions.erlang;

  compatibleVersionPackages = pkgs: let
    expandElixir = erlang: _name: attrs:
      if erlang != null
      then
        nameValuePair "elixir_${attrs.version}"
        (mkElixir (pkgs.beam.packagesWith erlang) attrs.version attrs.checksum)
      else null;
    expandErlang = _erlangVersion: checksumSet: let
      erlang =
        mkErlang pkgs checksumSet.erlang.version
        checksumSet.erlang.checksum;
      elixirs = pipe checksumSet.elixirs [
        (mapAttrs' (expandElixir erlang))
        (filterAttrs (_n: v: v != null))
      ];
    in
      nameValuePair "erlang_${erlang.version}" {inherit erlang elixirs;};
  in
    pipe compatibleVersions [
      (filterAttrs (erlangVersion: _attrs: (erlangExists pkgs erlangVersion)))
      (mapAttrs' expandErlang)
    ];

  erlangExists = pkgs: version: otpBasePackage pkgs version != null;

  findBasePackage = import ./findBasePackage.nix {inherit lib;};

  latestVersions = import ./latestVersions.nix {inherit lib versions;};

  mkElixir = pkgs: beamPkgs: version: hash: let
    basePkg = elixirBasePackage beamPkgs version;
  in
    if basePkg != null
    then
      basePkg.overrideAttrs {
        inherit hash;
        src = pkgs.fetchFromGitHub {
          owner = "elixir-lang";
          repo = "elixir";
          tag = "v${version}";
          inherit hash;
        };
      }
    else null;

  mkErlang = pkgs: version: hash: let
    basePkg = otpBasePackage pkgs version;
  in
    if basePkg != null
    then
      if (lib.versions.major version) == "25"
      then
        basePkg.overrideAttrs {
          inherit version hash;
          src = pkgs.fetchFromGitHub {
            owner = "erlang";
            repo = "otp";
            tag = "OTP-${version}";
            inherit hash;
          };
          configureFlags = ["--disable-jit"];
        }
      else
        basePkg.overrideAttrs {
          inherit hash version;

          src = pkgs.fetchFromGitHub {
            owner = "erlang";
            repo = "otp";
            tag = "OTP-${version}";
            inherit hash;
          };
        }
    else null;

  mkPackageSet = {
    elixirVersion,
    erlangVersion,
    elixirLanguageServer ? false,
    erlangLanguageServer ? false,
    # Upstream Rebar project is presumed to have done its own CI diligence WRT Erlang versions
    rebarCheck ? false,
    pkgs,
  }: let
    erlang = mkErlang pkgs erlangVersion versions.erlang.${erlangVersion};
    beamPkgs = (pkgs.beam.packagesWith erlang).extend (_: _: {
      elixir = mkElixir pkgs beamPkgs elixirVersion versions.elixir.${elixirVersion};
    });
    inherit (beamPkgs) elixir;
  in
    {
      inherit (beamPkgs) erlang;
      inherit elixir;
    }
    // (
      if elixirLanguageServer
      then {
        elixir-ls = (beamPkgs.elixir-ls.override {inherit elixir;}).overrideAttrs (old: {
          buildPhase =
            # Elixir 1.16.0 or newer
            if ((builtins.compareVersions elixir.version "1.16.0") != -1)
            then ''
              runHook preBuild
              mix do compile --no-deps-check, elixir_ls.release2
              runHook postBuild
            ''
            else old.buildPhase;
        });
      }
      else {}
    )
    // (
      if erlangLanguageServer
      then {
        inherit (beamPkgs) erlang-ls;
      }
      else {}
    )
    // (
      if rebarCheck
      then {}
      else lib.genAttrs ["rebar" "rebar3"] (p: beamPkgs.${p}.overrideAttrs (_old: {doCheck = false;}))
    );

  normalizeElixir = version:
    lib.trivial.pipe version [
      (lib.versions.pad 3)
      splitVersion
      (take 3)
      (map toString)
      (concatStringsSep ".")
    ];

  packageSetFromToolVersions = pkgs: toolVersionsPath: args: let
    asdfVersions = parseToolVersions toolVersionsPath;
  in
    mkPackageSet ({
        elixirVersion = normalizeElixir asdfVersions.elixir;
        erlangVersion = asdfVersions.erlang;
        inherit pkgs;
      }
      // args);

  parseToolVersions = import ./parseToolVersions.nix {inherit lib;};

  inherit (latestVersions) recentElixirs recentErlangs;

  # idea credit: https://github.com/nix-community/nix-github-actions/blob/bfeb681177b5128d061ebbef7ded30bc21a3f135/default.nix
  recentMatrix =
    pipe {
      elixir = recentElixirs;
      erlang = recentErlangs;
      os = ["macos-latest" "ubuntu-latest"];
    } [
      lib.attrsets.cartesianProduct
      (builtins.filter (set: versionCompatible set.elixir set.erlang))
      (v: {include = v;})
    ];

  versionCompatible =
    import ./versionCompatible.nix {inherit lib normalizeElixir;};

  versions = {
    elixir = importJSON ../data/elixir.json;
    erlang = importJSON ../data/erlang.json;
  };

  mkBeamPackages = {
    pkgs,
    elixirVersion,
    erlangVersion,
  }: let
    erlang = mkErlang pkgs erlangVersion versions.erlang.${erlangVersion};
    beamPkgs = (pkgs.beam.packagesWith erlang).extend (_: _: {
      elixir = mkElixir pkgs beamPkgs elixirVersion versions.elixir.${elixirVersion};
    });
  in
    beamPkgs;

  expertBeam = pkgs: pkgs.beam.packages.erlang_29.extend (_: prev: {elixir = prev.elixir_1_20;});

  expert = pkgs: pkgs.callPackage ./expert.nix {beamPackages = expertBeam pkgs;};

  mkEngine = {
    pkgs,
    beamPackages,
    toolchains ? {},
  }:
    pkgs.callPackage ./engine.nix {inherit beamPackages toolchains;};

  expertPackages = pkgs: let
    beamByOtp = pkgs.beam.packages;
    otps = builtins.filter (n: beamByOtp ? ${n}) ["erlang_27" "erlang_28" "erlang_29"];
    elixirsOf = otp:
      builtins.filter (n: builtins.match "elixir_1_[0-9]+" n != null) (builtins.attrNames beamByOtp.${otp});
    engineFor = otp: elixir:
      mkEngine {
        inherit pkgs;
        beamPackages = beamByOtp.${otp}.extend (_: prev: {elixir = prev.${elixir};});
      };

    toolchains = lib.genAttrs otps (otp: lib.genAttrs (elixirsOf otp) (engineFor otp));

    expert' = expert pkgs;
    engine = mkEngine {
      inherit pkgs toolchains;
      beamPackages = expertBeam pkgs;
    };
  in {
    expert = expert';
    inherit engine;
    expert-with-engine = expert'.withEngine engine;
  };
in {
  inherit compatibleVersions compatibleVersionPackages versions versionCompatible;
  inherit mkElixir mkErlang mkPackageSet normalizeElixir;
  inherit mkBeamPackages mkEngine expert expertPackages;
  inherit packageSetFromToolVersions parseToolVersions;
  inherit (latestVersions) latestElixirMinors latestErlangMajors recentElixirs recentErlangs;
  inherit recentMatrix;
}
