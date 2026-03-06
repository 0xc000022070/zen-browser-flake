{
  zen-browser-flake,
  wrapWithX11,
  ...
}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.twilight];

    programs.zen-browser = {
      enable = true;
      suppressXdgMigrationWarning = true;

      profiles.default = {
        pins = {
          "Test Pin" = {
            id = "1213fc75-2019-436e-9c26-0b7995e8ca37";
            url = "https://nixos.org";
            title = "NixOS";
            position = 100;
          };
          "Another Pin" = {
            id = "d9acb137-4117-4b54-a3de-4eab1a7001dd";
            url = "https://search.nixos.org/packages";
            title = "Nix Packages";
            position = 101;
          };
        };
      };
    };
  };

  testScript = wrapWithX11 /* python */ ''
    machine.succeed("test -f /home/testuser/.config/zen/profiles.ini")
    machine.succeed("grep -q 'Name=default' /home/testuser/.config/zen/profiles.ini")
    machine.succeed("test -d /home/testuser/.config/zen/default")

    machine.succeed("test -f /home/testuser/.config/zen/default/zen-sessions.jsonlz4 || ( echo '{\"spaces\":[],\"tabs\":[],\"folders\":[],\"groups\":[]}' > /tmp/min.json && mozlz4a /tmp/min.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4 && chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4 )")

    machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-after-first-run.json")
    machine.succeed("jq -e '.tabs != null and .spaces != null' /tmp/sessions-after-first-run.json")

    machine.succeed("systemctl restart home-manager-testuser.service")
    machine.wait_for_unit("home-manager-testuser.service")

    machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions.json")
    machine.succeed("test $(jq '[.tabs[] | select(.pinned == true)] | length' /tmp/sessions.json) -ge 2")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{1213fc75-2019-436e-9c26-0b7995e8ca37}\")] | length == 1' /tmp/sessions.json")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{d9acb137-4117-4b54-a3de-4eab1a7001dd}\")] | length == 1' /tmp/sessions.json")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{1213fc75-2019-436e-9c26-0b7995e8ca37}\") | .entries[0].url] | .[0] == \"https://nixos.org\"' /tmp/sessions.json")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{d9acb137-4117-4b54-a3de-4eab1a7001dd}\") | .entries[0].url] | .[0] == \"https://search.nixos.org/packages\"' /tmp/sessions.json")

    machine.succeed("su - testuser -c 'DISPLAY=:99 timeout 5 zen-twilight about:blank' || true")
    machine.succeed("systemctl restart home-manager-testuser.service")
    machine.wait_for_unit("home-manager-testuser.service")
    machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-after-zen.json")
    machine.succeed("test $(jq '[.tabs[] | select(.pinned == true)] | length' /tmp/sessions-after-zen.json) -ge 2")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{1213fc75-2019-436e-9c26-0b7995e8ca37}\")] | length == 1' /tmp/sessions-after-zen.json")
    machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{d9acb137-4117-4b54-a3de-4eab1a7001dd}\")] | length == 1' /tmp/sessions-after-zen.json")
  '';
}
