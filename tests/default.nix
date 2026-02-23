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

      wrapWithX11 = testScript: ''        # python
        machine.succeed("( nohup Xvfb :99 -screen 0 1024x768x24 </dev/null >>/tmp/xvfb.log 2>&1 & )")
        machine.succeed("sleep 2")
        machine.succeed("su - testuser -c 'DISPLAY=:99 timeout 5 zen-beta about:blank' || true")
        ${testScript}
      '';
    };
  in
    pkgs.testers.nixosTest {
      inherit name;
      nodes.machine = {
        imports = [
          {
            imports = [home-manager.nixosModules.home-manager];

            environment.systemPackages = with pkgs; [
              jq
              mozlz4a
              xorg-server
            ];

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

      testScript = ''        # python
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("home-manager-testuser.service")
        ${suite.testScript}
      '';
    };

  suites = {
    "enable-beta-via-module" = ./enable-beta.nix;
    "pins-persistent" = ./pins-persistent.nix;
  };
in
  pkgs.lib.mapAttrs (name: path: mkGenericTest name path) suites
