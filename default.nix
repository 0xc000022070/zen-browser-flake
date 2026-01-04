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
  
  wrap = unwrapped: icon:
    if pkgs.stdenv.isDarwin
    then unwrapped
    else pkgs.wrapFirefox unwrapped (if icon != null then {inherit icon;} else {});
in rec {
  beta-unwrapped = mkZen "beta" "beta";
  twilight-unwrapped = mkZen "twilight" "twilight";
  twilight-official-unwrapped = mkZen "twilight" "twilight-official";

  beta = wrap beta-unwrapped "zen-browser";
  twilight = wrap twilight-unwrapped null;
  twilight-official = wrap twilight-official-unwrapped null;

  default = beta;
}
