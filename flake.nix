{
  description = "Zen Browser";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: let
    mkZen = name: system: entry: let
      pkgs = nixpkgs.legacyPackages.${system};
      variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${entry}.${system};

      desktopFile =
        if name == "beta"
        then "zen.desktop"
        else "zen_${name}.desktop";
    in
      pkgs.callPackage ./package.nix {
        inherit name desktopFile variant;
      };

    mkZenWrapped = name: system: entry: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.wrapFirefox entry {
        icon = "zen-${name}";
        wmClass = "zen-${name}";
        hasMozSystemDirPatch = false;
      };

    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: rec {
      beta-unwrapped = mkZen "beta" system "beta";
      twilight-unwrapped = mkZen "twilight" system "twilight";
      twilight-official-unwrapped = mkZen "twilight" system "twilight-official";

      beta = mkZenWrapped "beta" system beta-unwrapped;
      twilight = mkZenWrapped "twilight" system twilight-unwrapped;
      twilight-official = mkZenWrapped "twilight" system twilight-official-unwrapped;

      default = beta;
    });

    formatter = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        pkgs.alejandra
    );

    homeModules = rec {
      beta = import ./hm-module.nix {
        inherit self home-manager;
        name = "beta";
      };
      twilight = import ./hm-module.nix {
        inherit self home-manager;
        name = "twilight";
      };
      twilight-official = import ./hm-module.nix {
        inherit self home-manager;
        name = "twilight-official";
      };
      default = beta;
    };
  };
}
