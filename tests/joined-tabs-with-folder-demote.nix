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
        folder = "dddddddd-dddd-4ddd-dddd-dddddddddddd";
      in {
        pinsForce = true;
        pinsForceAction = "demote";

        spaces."Main" = {
          id = ws;
          name = "Main";
          position = 1;
        };

        pins = {
          "State" = {
            id = folder;
            isGroup = true;
            workspace = ws;
            position = 10;
            isFolderCollapsed = true;
          };
          "Left" = {
            id = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa";
            url = "https://left.example";
            title = "Left";
            workspace = ws;
            folderParentId = folder;
            position = 11;
          };
          "Center" = {
            id = "eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee";
            url = "https://center.example";
            title = "Center";
            workspace = ws;
            folderParentId = folder;
            position = 12;
          };
          "Right" = {
            id = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb";
            url = "https://right.example";
            title = "Right";
            workspace = ws;
            folderParentId = folder;
            position = 13;
          };
        };

        joinedTabs."Inside state" = {
          id = "1778374511045-84";
          gridType = "vsep";
          tabs = [
            "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
            "eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee"
            "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"
          ];
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
      cat > /tmp/sess-joined-folder-demote.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": [
          {
            "pinned": true,
            "hidden": false,
            "zenWorkspace": "{cccccccc-cccc-4ccc-cccc-cccccccccccc}",
            "zenSyncId": "{11111111-1111-1111-1111-111111111111}",
            "userContextId": 0,
            "zenEssential": false,
            "index": 0,
            "groupId": null,
            "entries": [{"url": "https://orphan.example/", "title": "Orphan", "charset": "UTF-8", "ID": 0, "persist": true}]
          },
          {
            "pinned": true,
            "hidden": false,
            "zenWorkspace": "{cccccccc-cccc-4ccc-cccc-cccccccccccc}",
            "zenSyncId": "{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}",
            "id": "{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}",
            "userContextId": 0,
            "zenEssential": false,
            "index": 11,
            "groupId": "stale-should-be-replaced",
            "entries": [{"url": "https://left.example", "title": "Left", "charset": "UTF-8", "ID": 0, "persist": true}]
          },
          {
            "pinned": true,
            "hidden": false,
            "zenWorkspace": "{cccccccc-cccc-4ccc-cccc-cccccccccccc}",
            "zenSyncId": "{eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee}",
            "id": "{eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee}",
            "userContextId": 0,
            "zenEssential": false,
            "index": 12,
            "groupId": "stale-should-be-replaced",
            "entries": [{"url": "https://center.example", "title": "Center", "charset": "UTF-8", "ID": 0, "persist": true}]
          },
          {
            "pinned": true,
            "hidden": false,
            "zenWorkspace": "{cccccccc-cccc-4ccc-cccc-cccccccccccc}",
            "zenSyncId": "{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}",
            "id": "{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}",
            "userContextId": 0,
            "zenEssential": false,
            "index": 13,
            "groupId": "stale-should-be-replaced",
            "entries": [{"url": "https://right.example", "title": "Right", "charset": "UTF-8", "ID": 0, "persist": true}]
          }
        ]
      }
      EOF
      mozlz4a /tmp/sess-joined-folder-demote.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-jfd.json")
      machine.succeed("jq -e '.tabs | length == 4' /tmp/sessions-jfd.json")
      machine.succeed(
        "jq -e '[.tabs[] | select(.zenSyncId == \"{11111111-1111-1111-1111-111111111111}\")][0] | (.pinned == false) and (.zenEssential == false)' /tmp/sessions-jfd.json"
      )
      machine.succeed(
        "jq -e '[.tabs[] | select(.zenSyncId == \"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\")][0] | (.groupId == \"1778374511045-84\") and (.index == 11)' /tmp/sessions-jfd.json"
      )
      machine.succeed(
        "jq -e '[.tabs[] | select(.zenSyncId == \"{eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee}\")][0] | (.groupId == \"1778374511045-84\") and (.index == 12)' /tmp/sessions-jfd.json"
      )
      machine.succeed(
        "jq -e '[.tabs[] | select(.zenSyncId == \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\")][0] | (.groupId == \"1778374511045-84\") and (.index == 13)' /tmp/sessions-jfd.json"
      )
      machine.succeed("jq -e '.splitViewData | length == 1' /tmp/sessions-jfd.json")
    '';
}
