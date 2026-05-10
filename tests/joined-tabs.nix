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
        pins = {
          "Left" = {
            id = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa";
            url = "https://left.example";
            title = "Left";
            position = 10;
          };
          "Right" = {
            id = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb";
            url = "https://right.example";
            title = "Right";
            position = 11;
          };
        };

        joinedTabs."Dev split" = {
          id = "1778374511045-84";
          gridType = "vsep";
          tabs = [
            "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
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
      cat > /tmp/sess-joined.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-joined.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-joined.json")
      machine.succeed("jq -e '.tabs | length == 2' /tmp/sessions-joined.json")
      machine.succeed("jq -e '[.tabs[].id] == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-joined.json")
      machine.succeed("jq -e '[.tabs[].groupId] == [\"1778374511045-84\", \"1778374511045-84\"]' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.groups | length == 1' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.groups[0] | (.id == \"1778374511045-84\") and (.pinned == true) and (.essential == false) and (.splitView == true) and (.name == \"\") and (.color == \"blue\") and (.index == null)' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.splitViewData | length == 1' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.splitViewData[0].groupId == \"1778374511045-84\"' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.splitViewData[0].gridType == \"vsep\"' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.splitViewData[0].tabs == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-joined.json")
      machine.succeed("jq -e '.splitViewData[0].layoutTree.direction == \"row\"' /tmp/sessions-joined.json")
      machine.succeed("jq -e '[.splitViewData[0].layoutTree.children[].tabId] == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-joined.json")
      machine.succeed("jq -e '[.splitViewData[0].layoutTree.children[].sizeInParent] == [50, 50]' /tmp/sessions-joined.json")
    '';
}
