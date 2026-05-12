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

        joinedTabs."Asymmetric split" = {
          id = "1778374511045-99";
          gridType = "vsep";
          tabs = [
            "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
            "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"
          ];
          sizes = [70 30];
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
      cat > /tmp/sess-joined-sizes.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-joined-sizes.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-joined-sizes.json")
      machine.succeed("jq -e '.splitViewData | length == 1' /tmp/sessions-joined-sizes.json")
      machine.succeed("jq -e '.splitViewData[0].groupId == \"1778374511045-99\"' /tmp/sessions-joined-sizes.json")
      machine.succeed("jq -e '[.splitViewData[0].layoutTree.children[].sizeInParent] == [70, 30]' /tmp/sessions-joined-sizes.json")
      machine.succeed("jq -e '[.splitViewData[0].layoutTree.children[].tabId] == [\"{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}\", \"{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb}\"]' /tmp/sessions-joined-sizes.json")
    '';
}
