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
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system:
      import ./default.nix {
        pkgs = nixpkgs.legacyPackages.${system};
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
