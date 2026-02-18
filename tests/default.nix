{
  self,
  nixpkgs,
  home-manager,
}: let
  pkgs = nixpkgs;

  mkGenericTest = name: suitePath: let
    suite = import suitePath {
      inherit pkgs home-manager;
      zen-browser-flake = self;
    };
  in
    pkgs.testers.nixosTest {
      inherit name;
      nodes.machine = {
        imports = [
          {
            imports = [home-manager.nixosModules.home-manager];

            users.users.testuser = {
              isNormalUser = true;
              home = "/home/testuser";
              createHome = true;
              group = "users";
              uid = 1000;
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              users.testuser = {
                imports = [suite.homeModule];

                home.stateVersion = "26.05";
              };
            };
          }
        ];
      };

      inherit (suite) testScript;
    };

  suites = {
    "enable-beta-via-module" = ./enable-beta.nix;
  };
in
  pkgs.lib.mapAttrs (name: path: mkGenericTest name path) suites
