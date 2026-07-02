{
  lib,
  pkgs,
}:
let
  inherit (builtins)
    attrNames
    compareVersions
    filter
    foldl'
    match
    replaceStrings
    ;
  inherit (lib) importJSON removePrefix toInt;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
  inherit (lib.lists) findFirst;
  inherit (lib.trivial) pipe;
  inherit (lib.versions) major;
  inherit (lib.strings) versionAtLeast versionOlder;

  versions = {
    elixir = importJSON ../data/elixir.json;
    erlang = importJSON ../data/erlang.json;
  };

  toAttrName = prefix: version: "${prefix}_${replaceStrings [ "." ] [ "_" ] version}";

  # https://hexdocs.pm/elixir/compatibility-and-deprecations.html
  # range is [min, max)
  compatBounds = [
    {
      min_el = "1.20.0";
      max_el = "1.21.0";
      min_erl = "27.0.0";
      max_erl = "30.0.0";
    }
    {
      min_el = "1.19.0";
      max_el = "1.20.0";
      min_erl = "26.0.0";
      max_erl = "29.0.0";
    }
    {
      min_el = "1.17.0";
      max_el = "1.19.0";
      min_erl = "25.0.0";
      max_erl = "28.0.0";
    }
    {
      min_el = "1.15.0";
      max_el = "1.17.0";
      min_erl = "24.0.0";
      max_erl = "27.0.0";
    }
    {
      min_el = "1.14.0";
      max_el = "1.15.0";
      min_erl = "23.0.0";
      max_erl = "26.0.0";
    }
  ];

  boundFor =
    elixirVersion:
    findFirst (
      b: versionAtLeast elixirVersion b.min_el && versionOlder elixirVersion b.max_el
    ) null compatBounds;

  compatible =
    elixirVersion: erlangVersion:
    let
      b = boundFor elixirVersion;
    in
    b != null && versionAtLeast erlangVersion b.min_erl && versionOlder erlangVersion b.max_erl;

  otpBoundsFor =
    elixirVersion:
    let
      b = boundFor elixirVersion;
    in
    {
      minimumOTPVersion = major b.min_erl;
      maximumOTPVersion = toString (toInt (major b.max_erl) - 1);
    };

  isStableElixir = version: match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;

  otpInterpreters = pkgs.beam.interpreters;

  availableOtpMajors = pipe (attrNames otpInterpreters) [
    (filter (n: match "erlang_[0-9]+" n != null))
    (map (removePrefix "erlang_"))
  ];

  newestOtpMajor = foldl' (a: b: if compareVersions a b >= 0 then a else b) "0" availableOtpMajors;

  otpBaseFor =
    version:
    let
      m = major version;
    in
    otpInterpreters."erlang_${m}" or (
      if compareVersions m newestOtpMajor > 0 then otpInterpreters."erlang_${newestOtpMajor}" else null
    );

  elixirBuilder = import "${pkgs.path}/pkgs/development/interpreters/elixir/generic-builder.nix";

  buildErlang =
    base: version: hash:
    base.overrideAttrs (_: {
      inherit version hash;
      src = pkgs.fetchFromGitHub {
        owner = "erlang";
        repo = "otp";
        tag = "OTP-${version}";
        inherit hash;
      };
    });

  buildElixir =
    beam: version: hash:
    beam.callPackage (elixirBuilder ({ inherit version hash; } // otpBoundsFor version)) { };
in
pipe versions.erlang [
  (filterAttrs (erlangVersion: _: otpBaseFor erlangVersion != null))
  (mapAttrs' (
    erlangVersion: erlangHash:
    let
      erlang = buildErlang (otpBaseFor erlangVersion) erlangVersion erlangHash;
      beam = pkgs.beam.packagesWith erlang;

      elixirs = pipe versions.elixir [
        (filterAttrs (
          elixirVersion: _: isStableElixir elixirVersion && compatible elixirVersion erlangVersion
        ))
        (mapAttrs' (
          elixirVersion: elixirHash:
          nameValuePair (toAttrName "elixir" elixirVersion) (buildElixir beam elixirVersion elixirHash)
        ))
      ];
    in
    nameValuePair (toAttrName "erlang" erlangVersion) (erlang // elixirs)
  ))
]
