{
  zen-browser-flake,
  wrapWithX11,
  ...
}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.twilight];

    programs.zen-browser = {
      enable = true;
      profiles.default = let
        ws = "cccccccc-cccc-4ccc-cccc-cccccccccccc";
      in {
        spaces."Main" = {
          id = ws;
          name = "Main";
          position = 1;
        };

        liveFolders = {
          "NixOS blog" = {
            id = "nixos-blog";
            kind = "rss";
            feedUrl = "https://nixos.org/blog/rss.xml";
            workspace = ws;
            position = 20;
            maxItems = 5;
            folderIcon = "https://nixos.org/favicon.ico";
          };
          "Pull requests" = {
            id = "gh-prs";
            kind = "github:pull-requests";
            workspace = ws;
            position = 21;
            fetchInterval = 900000;
            github = {
              reviewRequested = true;
              repoExcludes = ["owner/noisy"];
            };
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
          "id": "nixos-blog",
          "type": "rss",
          "data": {
            "state": {
              "url": "https://example.com/stale.xml",
              "maxItems": 10,
              "timeRange": 0,
              "interval": 1800000,
              "lastFetched": 4242424242,
              "lastErrorId": null,
              "options": {}
            }
          },
          "dismissedItems": ["nixos-blog:/blog/keep-dismissed"],
          "tabsState": [{"itemId": "nixos-blog:/blog/keep-dismissed", "label": null}]
        },
        {
          "id": "imperative-orphan",
          "type": "rss",
          "data": {"state": {"url": "https://example.org/feed.xml"}},
          "dismissedItems": [],
          "tabsState": []
        }
      ]
      EOF
      mozlz4a /tmp/live-pre.json /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      # Session store: folder rows, groups rows, placeholder tabs
      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-live.json")
      machine.succeed("jq -e '.folders | length == 2' /tmp/sessions-live.json")
      machine.succeed(
        "jq -e '.folders[] | select(.id == \"nixos-blog\") | .isLiveFolder == true and .name == \"NixOS blog\" and .pinned == true and .collapsed == true and .emptyTabIds == [\"nixos-blog-empty\"] and .userIcon == \"https://nixos.org/favicon.ico\" and .workspaceId == \"{cccccccc-cccc-4ccc-cccc-cccccccccccc}\"' /tmp/sessions-live.json"
      )
      machine.succeed(
        "jq -e '.folders[] | select(.id == \"gh-prs\") | .isLiveFolder == true and .index == 21' /tmp/sessions-live.json"
      )
      machine.succeed("jq -e '.groups | length == 2' /tmp/sessions-live.json")
      machine.succeed(
        "jq -e '.groups[] | select(.id == \"nixos-blog\") | .splitView == false and .pinned == true and .color == \"zen-workspace-color\"' /tmp/sessions-live.json"
      )
      machine.succeed("jq -e '[.tabs[] | select(.zenIsEmpty == true)] | length == 2' /tmp/sessions-live.json")
      machine.succeed(
        "jq -e '.tabs[] | select(.id == \"nixos-blog-empty\") | .groupId == \"nixos-blog\" and .pinned == true and .entries[0].url == \"about:blank\"' /tmp/sessions-live.json"
      )

      # Live folders store: declared config applied, runtime state preserved, orphan kept
      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live-post.json")
      machine.succeed("jq -e 'length == 3' /tmp/live-post.json")
      machine.succeed(
        "jq -e '.[] | select(.id == \"nixos-blog\") | .data.state.url == \"https://nixos.org/blog/rss.xml\" and .data.state.maxItems == 5' /tmp/live-post.json"
      )
      machine.succeed(
        "jq -e '.[] | select(.id == \"nixos-blog\") | .data.state.lastFetched == 4242424242 and .data.state.interval == 1800000' /tmp/live-post.json"
      )
      machine.succeed(
        "jq -e '.[] | select(.id == \"nixos-blog\") | .dismissedItems == [\"nixos-blog:/blog/keep-dismissed\"] and (.tabsState | length == 1)' /tmp/live-post.json"
      )
      machine.succeed(
        "jq -e '.[] | select(.id == \"gh-prs\") | .type == \"github\" and .data.state.type == \"pull-requests\" and .data.state.interval == 900000' /tmp/live-post.json"
      )
      machine.succeed(
        "jq -e '.[] | select(.id == \"gh-prs\") | .data.state.options == {\"authorMe\": false, \"assignedMe\": true, \"reviewRequested\": true, \"repoExcludes\": [\"owner/noisy\"]} and (.data.state | has(\"url\") | not)' /tmp/live-post.json"
      )
      machine.succeed(
        "jq -e '.[] | select(.id == \"imperative-orphan\") | .data.state.url == \"https://example.org/feed.xml\"' /tmp/live-post.json"
      )
    '';
}
