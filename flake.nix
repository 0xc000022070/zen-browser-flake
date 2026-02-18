{
  description = "Community-driven Nix Flake for the Zen browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: let
    linuxSystems = ["x86_64-linux" "aarch64-linux"];

    supportedSystems = linuxSystems ++ ["aarch64-darwin"];

    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (
        system: f nixpkgs.legacyPackages.${system}
      );
  in {
    packages = forAllSystems (pkgs: import ./default.nix {inherit pkgs;});

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    checks =
      nixpkgs.lib.genAttrs linuxSystems
      (system:
        import ./tests {
          inherit self home-manager;
          nixpkgs = nixpkgs.legacyPackages.${system};
        });

    homeModules = {
      beta = import ./hm-module {
        inherit self home-manager;
        name = "beta";
      };
      twilight = import ./hm-module {
        inherit self home-manager;
        name = "twilight";
      };
      twilight-official = import ./hm-module {
        inherit self home-manager;
        name = "twilight-official";
      };
      default = self.homeModules.beta;
    };
  };
}
