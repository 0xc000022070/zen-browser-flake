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
      cat > /tmp/sess-joined-folder.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-joined-folder.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-folder.json")
      machine.succeed("jq -e '.folders | length == 1' /tmp/sessions-folder.json")
      machine.succeed("jq -e '.folders[0].id == \"{dddddddd-dddd-4ddd-dddd-dddddddddddd}\"' /tmp/sessions-folder.json")
      machine.succeed("jq -e '.tabs | length == 3' /tmp/sessions-folder.json")
      machine.succeed(
        "jq -e '[.tabs[].groupId] == [\"1778374511045-84\", \"1778374511045-84\", \"1778374511045-84\"]' /tmp/sessions-folder.json"
      )
      machine.succeed("jq -e '[.tabs[].id] == [null, null, null]' /tmp/sessions-folder.json")
      machine.succeed("jq -e '.splitViewData | length == 1' /tmp/sessions-folder.json")
      machine.succeed("jq -e '.splitViewData[0].groupId == \"1778374511045-84\"' /tmp/sessions-folder.json")
      machine.succeed("jq -e '.splitViewData[0].gridType == \"vsep\"' /tmp/sessions-folder.json")
      machine.succeed(
        "jq -e '.splitViewData[0].tabs == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-folder.json"
      )
      machine.succeed("jq -e '.splitViewData[0].layoutTree.direction == \"row\"' /tmp/sessions-folder.json")
      machine.succeed(
        "jq -e '[.splitViewData[0].layoutTree.children[].tabId] == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-folder.json"
      )
      machine.succeed(
        "jq -e '[.splitViewData[0].layoutTree.children[].sizeInParent] | length == 3 and (add > 99.9 and add < 100.1)' /tmp/sessions-folder.json"
      )
      machine.succeed("jq -e '.groups | map(select(.splitView == true)) | length == 1' /tmp/sessions-folder.json")
    '';
}
