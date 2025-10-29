_: {
  perSystem = {pkgs, ...}: {
    packages = {
      nix-prefetch-elixir = pkgs.writeShellScriptBin "nix-prefetch-elixir" ''
        ${pkgs.nix-prefetch-github}/bin/nix-prefetch-github elixir-lang elixir --rev v''${1} | ${pkgs.jq}/bin/jq -r .hash
      '';

      nix-prefetch-otp = pkgs.writeShellScriptBin "nix-prefetch-otp" ''
        ${pkgs.nix-prefetch-github}/bin/nix-prefetch-github erlang otp --rev OTP-''${1} | ${pkgs.jq}/bin/jq -r .hash
      '';
    };
  };
}
