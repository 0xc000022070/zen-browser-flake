{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  wrapZen = import ./wrap-zen.nix pkgs.wrapFirefox;

  mkZen = name: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).variants.${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };
in rec {
  beta-unwrapped = mkZen "beta" "beta";
  twilight-unwrapped = mkZen "twilight" "twilight";
  twilight-official-unwrapped = mkZen "twilight" "twilight-official";

  beta =
    if isDarwin
    then beta-unwrapped
    else
      wrapZen beta-unwrapped {
        icon = "zen-browser";
      };
  twilight =
    if isDarwin
    then twilight-unwrapped
    else wrapZen twilight-unwrapped {};
  twilight-official =
    if isDarwin
    then twilight-official-unwrapped
    else
      wrapZen twilight-official-unwrapped {
        icon = "zen-twilight";
      };

  default = beta;
}
