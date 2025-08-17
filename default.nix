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

  beta = pkgs.wrapFirefox beta-unwrapped {};
  twilight = pkgs.wrapFirefox twilight-unwrapped {};
  twilight-official = pkgs.wrapFirefox twilight-official-unwrapped {};

  default = beta;
}
