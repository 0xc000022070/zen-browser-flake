{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  inherit (pkgs) lib;

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  wrapZen = import ./wrap-zen.nix pkgs.wrapFirefox;

  mkZen = name: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).variants.${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };

  mkWrapped = unwrapped: wrapperDefaults:
    lib.makeOverridable (
      {
        policies ? {},
        extraPolicies ? {},
        ...
      } @ args:
        wrapZen
        (unwrapped.override {inherit policies extraPolicies;})
        (wrapperDefaults // removeAttrs args ["policies" "extraPolicies"])
    ) {};
in rec {
  beta-unwrapped = mkZen "beta" "beta";
  twilight-unwrapped = mkZen "twilight" "twilight";
  twilight-official-unwrapped = mkZen "twilight" "twilight-official";

  beta =
    if isDarwin
    then beta-unwrapped
    else
      mkWrapped beta-unwrapped {
        icon = "zen-browser";
      };
  twilight =
    if isDarwin
    then twilight-unwrapped
    else mkWrapped twilight-unwrapped {};
  twilight-official =
    if isDarwin
    then twilight-official-unwrapped
    else
      mkWrapped twilight-official-unwrapped {
        icon = "zen-twilight";
      };

  default = beta;
}
