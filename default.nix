{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  mkZen = name: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };
in rec {
  beta-unwrapped = mkZen "beta" "beta";
  twilight-unwrapped = mkZen "twilight" "twilight";
  twilight-official-unwrapped = mkZen "twilight" "twilight-official";

  beta = if pkgs.stdenv.isDarwin then beta-unwrapped else pkgs.wrapFirefox beta-unwrapped {
    icon = "zen-browser";
  };
  twilight = if pkgs.stdenv.isDarwin then twilight-unwrapped else pkgs.wrapFirefox twilight-unwrapped {};
  twilight-official = if pkgs.stdenv.isDarwin then twilight-official-unwrapped else pkgs.wrapFirefox twilight-official-unwrapped {
    icon = "zen-twilight";
  };

  default = beta;
}
