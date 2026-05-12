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
          "Top" = {
            id = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa";
            url = "https://top.example";
            title = "Top";
            position = 10;
          };
          "Middle" = {
            id = "eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee";
            url = "https://middle.example";
            title = "Middle";
            position = 11;
          };
          "Bottom" = {
            id = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb";
            url = "https://bottom.example";
            title = "Bottom";
            position = 12;
          };
        };

        joinedTabs."Stacked split" = {
          id = "1778374511045-77";
          gridType = "hsep";
          tabs = [
            "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
            "eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee"
            "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"
          ];
          sizes = [50 30 20];
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
      cat > /tmp/sess-joined-hsep.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": []
      }
      EOF
      mozlz4a /tmp/sess-joined-hsep.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-joined-hsep.json")
      machine.succeed("jq -e '.splitViewData | length == 1' /tmp/sessions-joined-hsep.json")
      machine.succeed("jq -e '.splitViewData[0].gridType == \"hsep\"' /tmp/sessions-joined-hsep.json")
      machine.succeed("jq -e '.splitViewData[0].layoutTree.direction == \"column\"' /tmp/sessions-joined-hsep.json")
      machine.succeed("jq -e '[.splitViewData[0].layoutTree.children[].sizeInParent] == [50, 30, 20]' /tmp/sessions-joined-hsep.json")
    '';
}
