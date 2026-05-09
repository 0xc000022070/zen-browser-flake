{
  zen-browser-flake,
  wrapWithX11,
  ...
}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.twilight];

    programs.zen-browser = {
      enable = true;
      profiles.default = {
        settings."zen.window-sync.enabled" = true;
        liveFolders = {
          "No manual id" = {
            kind = "rss";
            title = "No manual id";
            feedUrl = "https://nixos.org/blog/blog-rss.xml";
            position = 0;
          };
        };
      };
    };
  };

  testScript =
    wrapWithX11
    ''
      machine.succeed("mkdir -p /home/testuser/.config/zen/default")

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sess-auto.json")
      machine.succeed(
          "jq -e '[.folders[] | select(.isLiveFolder == true) | .id][0] | test(\"^[0-9]+-[0-9]+$\")' /tmp/sess-auto.json"
      )

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live-auto.json")
      machine.succeed(
          "jq -e '.[0].id | test(\"^[0-9]+-[0-9]+$\")' /tmp/live-auto.json"
      )
      machine.succeed("jq -e '.[0].type == \"rss\"' /tmp/live-auto.json")
    '';
}
