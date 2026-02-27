_: {
  perSystem = {pkgs, ...}: let
    nix-prefetch-deps = pkgs.lib.makeBinPath [
      pkgs.nix-prefetch-git
      pkgs.nix
    ];
  in {
    packages = {
      nix-prefetch-elixir = pkgs.writeShellScriptBin "nix-prefetch-elixir" ''
        export PATH="${nix-prefetch-deps}:$PATH"
        ${pkgs.nix-prefetch-github}/bin/nix-prefetch-github elixir-lang elixir --rev v''${1} | ${pkgs.jq}/bin/jq -r .hash
      '';

      nix-prefetch-otp = pkgs.writeShellScriptBin "nix-prefetch-otp" ''
        export PATH="${nix-prefetch-deps}:$PATH"
        ${pkgs.nix-prefetch-github}/bin/nix-prefetch-github erlang otp --rev OTP-''${1} | ${pkgs.jq}/bin/jq -r .hash
      '';
    };
  };
}
