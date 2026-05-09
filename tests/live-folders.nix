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
          "NixOS Feed" = {
            id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
            kind = "rss";
            title = "NixOS Feed";
            feedUrl = "https://nixos.org/blog/blog-rss.xml";
            position = 5;
          };
        };
      };
    };
  };

  testScript =
    wrapWithX11
    ''
      machine.succeed("test -d /home/testuser/.config/zen/default")

      machine.succeed(
          """
      cat > /tmp/sess-live.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-live.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      cat > /tmp/live-pre.json <<'EOF'
      [
        {
          "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "type": "rss",
          "data": {
            "state": {
              "url": "https://example.com/stale.xml",
              "interval": 1800000,
              "lastFetched": 4242424242,
              "lastErrorId": null,
              "options": {},
              "maxItems": 5,
              "timeRange": 0
            }
          },
          "dismissedItems": ["aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:/blog/keep-dismissed"],
          "tabsState": [{"itemId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:/blog/tab-preserved", "label": null}]
        }
      ]
      EOF
      mozlz4a /tmp/live-pre.json /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-live.json")
      machine.succeed(
          "jq -e '[.folders[] | select(.isLiveFolder == true)] | length == 1' /tmp/sessions-live.json"
      )
      machine.succeed(
          "jq -e '[.folders[] | select(.id == \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\") | .name] | .[0] == \"NixOS Feed\"' /tmp/sessions-live.json"
      )
      machine.succeed(
          "jq -e '[.groups[] | select(.id == \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\")] | length == 1' /tmp/sessions-live.json"
      )

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live-out.json")
      machine.succeed("test $(jq '. | length' /tmp/live-out.json) -eq 1")
      machine.succeed(
          "jq -e '.[0] | (.type == \"rss\") and (.id == \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\") and (.data.state.url | endswith(\"blog-rss.xml\"))' /tmp/live-out.json"
      )
      machine.succeed(
          "jq -e '.[0].data.state.lastFetched == 4242424242' /tmp/live-out.json"
      )
      machine.succeed(
          "jq -e '.[0].dismissedItems == [\"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:/blog/keep-dismissed\"]' /tmp/live-out.json"
      )
      machine.succeed(
          "jq -e '.[0].tabsState | length == 1' /tmp/live-out.json"
      )
    '';
}
