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

    apps = forAllSystems (pkgs: let
      root = toString ./.;
      gen = ./tooling/gen-options.sh;
    in {
      docs-options = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "docs-options" ''
          out="$(pwd)/docs/options.json"
          mkdir -p "$(dirname "$out")"
          exec env FLAKE_ROOT="${root}" ${pkgs.bash}/bin/bash "${gen}" "$out"
        ''}/bin/docs-options";
      };

      docs-serve = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "docs-serve" ''
          set -euo pipefail
          dir="$(pwd)/docs"
          if [[ ! -f "$dir/index.html" ]]; then
            echo "docs-serve: $dir/index.html not found (run from flake root)" >&2
            exit 1
          fi
          if [[ ! -f "$dir/options.json" ]]; then
            echo "docs-serve: $dir/options.json missing — run 'nix run .#docs-options' first" >&2
            exit 1
          fi
          port="''${PORT:-8080}"
          exec ${pkgs.miniserve}/bin/miniserve --index index.html --port "$port" "$dir"
        ''}/bin/docs-serve";
      };
    });
  };
}
