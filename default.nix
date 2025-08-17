{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  mkZen = pkgs: name: system: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };
in rec {
  beta-unwrapped = mkZen pkgs "beta" system "beta";
  twilight-unwrapped = mkZen pkgs "twilight" system "twilight";
  twilight-official-unwrapped = mkZen pkgs "twilight" system "twilight-official";

  beta = pkgs.wrapFirefox beta-unwrapped {};
  twilight = pkgs.wrapFirefox twilight-unwrapped {};
  twilight-official = pkgs.wrapFirefox twilight-official-unwrapped {};

  default = beta;
}
