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
        liveFolders = {
          "Bootstrapped feed" = {
            id = "bootstrap-rss-id-001";
            kind = "rss";
            title = "Bootstrapped feed";
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

      machine.succeed("test -f /home/testuser/.config/zen/default/zen-sessions.jsonlz4")
      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sess-bootstrap.json")
      machine.succeed(
          "jq -e '[.folders[] | select(.isLiveFolder == true)] | length == 1' /tmp/sess-bootstrap.json"
      )
      machine.succeed(
          "jq -e '[.folders[] | select(.id == \"bootstrap-rss-id-001\")] | length == 1' /tmp/sess-bootstrap.json"
      )

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live-bootstrap.json")
      machine.succeed(
          "jq -e 'length == 1 and .[0].id == \"bootstrap-rss-id-001\"' /tmp/live-bootstrap.json"
      )
    '';
}
