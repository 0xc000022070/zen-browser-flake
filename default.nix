{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  mkZen = name: entry: let
    variant = sources.variants.${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };

  binaryPackages = rec {
    beta-unwrapped = mkZen "beta" "beta";
    twilight-unwrapped = mkZen "twilight" "twilight";
    twilight-official-unwrapped = mkZen "twilight" "twilight-official";

    beta = pkgs.wrapFirefox beta-unwrapped {
      icon = "zen-browser";
    };
    twilight = pkgs.wrapFirefox twilight-unwrapped {};
    twilight-official = pkgs.wrapFirefox twilight-official-unwrapped {
      icon = "zen-twilight";
    };

    default = beta;
  };

  sourcePackages = pkgs.lib.optionalAttrs (system == "x86_64-linux") rec {
    surfer = pkgs.callPackage ./surfer.nix {
      source = sources.source.beta.surfer;
    };

    beta-source-unwrapped = pkgs.callPackage ./source-package.nix {
      source = sources.source.beta;
      inherit surfer;
    };

    beta-source = pkgs.wrapFirefox beta-source-unwrapped {
      icon = "zen-browser";
    };
  };
in
  binaryPackages // sourcePackages
