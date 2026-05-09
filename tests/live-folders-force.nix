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
        liveFoldersForce = true;
        liveFolders = {
          "Kept RSS" = {
            id = "keep-live-folder-id";
            kind = "rss";
            title = "Kept RSS";
            feedUrl = "https://nixos.org/blog/blog-rss.xml";
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
      cat > /tmp/sess-force.json <<'EOF'
      {
        "spaces": [],
        "folders": [
          {
            "pinned": true,
            "essential": false,
            "splitViewGroup": false,
            "id": "keep-live-folder-id",
            "name": "Kept RSS",
            "collapsed": true,
            "saveOnWindowClose": true,
            "parentId": null,
            "prevSiblingInfo": {"type": "start", "id": null},
            "emptyTabIds": [],
            "userIcon": "",
            "workspaceId": null,
            "index": 0,
            "isLiveFolder": true
          },
          {
            "pinned": true,
            "essential": false,
            "splitViewGroup": false,
            "id": "orphan-live-folder-id",
            "name": "Orphan",
            "collapsed": true,
            "saveOnWindowClose": true,
            "parentId": null,
            "prevSiblingInfo": {"type": "start", "id": null},
            "emptyTabIds": [],
            "userIcon": "",
            "workspaceId": null,
            "index": 1,
            "isLiveFolder": true
          }
        ],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-force.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4

      cat > /tmp/live-force-pre.json <<'EOF'
      [
        {
          "id": "keep-live-folder-id",
          "type": "rss",
          "data": {"state": {"url": "https://old.example/feed.xml", "interval": 1800000, "lastFetched": 1, "options": {}, "maxItems": 5, "timeRange": 0, "lastErrorId": null}},
          "dismissedItems": [],
          "tabsState": []
        },
        {
          "id": "orphan-live-folder-id",
          "type": "rss",
          "data": {"state": {"url": "https://orphan.example/", "interval": 1800000, "lastFetched": 2, "options": {}, "maxItems": 10, "timeRange": 0, "lastErrorId": null}},
          "dismissedItems": [],
          "tabsState": []
        }
      ]
      EOF
      mozlz4a /tmp/live-force-pre.json /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-live-folders.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live-force-out.json")
      machine.succeed("test $(jq '. | length' /tmp/live-force-out.json) -eq 1")
      machine.succeed("jq -e '.[0].id == \"keep-live-folder-id\"' /tmp/live-force-out.json")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sess-force-out.json")
      machine.succeed("test $(jq '[.folders[] | select(.isLiveFolder == true)] | length' /tmp/sess-force-out.json) -eq 1")
      machine.succeed("jq -e '[.folders[] | select(.isLiveFolder == true)][0].id == \"keep-live-folder-id\"' /tmp/sess-force-out.json")
      machine.succeed(
          "jq -e '[.groups[] | select(.id == \"keep-live-folder-id\")] | length == 1' /tmp/sess-force-out.json"
      )
    '';
}
