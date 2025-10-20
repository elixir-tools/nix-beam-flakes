_: {
  perSystem = {pkgs, ...}: {
    packages = {
      nix-prefetch-elixir = pkgs.writeShellScriptBin "nix-prefetch-elixir" ''
        ${pkgs.nix}/bin/nix-prefetch-url --unpack https://github.com/elixir-lang/elixir/archive/v''${1}.tar.gz
      '';

      nix-prefetch-otp = pkgs.writeShellScriptBin "nix-prefetch-otp" ''
        ${pkgs.nix-prefetch-github}/bin/nix-prefetch-github erlang otp --rev OTP-''${1} | ${pkgs.jq}/bin/jq -r .hash
      '';
    };
  };
}
