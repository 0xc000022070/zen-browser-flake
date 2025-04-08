{
  pkgs ? import <nixpkgs> { },
  system ? pkgs.stdenv.hostPlatform.system,
}:

let
  mkZen =
    pkgs: name: system: entry:
    let
      variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${entry}.${system};

      desktopFile = if name == "beta" then "zen.desktop" else "zen_${name}.desktop";
    in
    pkgs.callPackage ./package.nix {
      inherit name desktopFile variant;
    };

  mkZenWrapped =
    pkgs: name: system: entry:
    pkgs.wrapFirefox entry {
      icon = "zen-${name}";
      wmClass = "zen-${name}";
      hasMozSystemDirPatch = false;
    };
in
rec {
  beta-unwrapped = mkZen pkgs "beta" system "beta";
  twilight-unwrapped = mkZen pkgs "twilight" system "twilight";
  twilight-official-unwrapped = mkZen pkgs "twilight" system "twilight-official";

  beta = mkZenWrapped pkgs "beta" system beta-unwrapped;
  twilight = mkZenWrapped pkgs "twilight" system twilight-unwrapped;
  twilight-official = mkZenWrapped pkgs "twilight" system twilight-official-unwrapped;

  default = beta;
}
