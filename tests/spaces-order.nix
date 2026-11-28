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
        spacesForce = true;

        spaces = {
          "Zulu" = {
            id = "aaaa0001-0000-4000-8000-000000000001";
            position = 1000;
          };
          "Alpha" = {
            id = "aaaa0002-0000-4000-8000-000000000002";
            position = 2000;
          };
          "Mike" = {
            id = "aaaa0003-0000-4000-8000-000000000003";
            position = 3000;
          };
        };
      };
    };
  };

  testScript = wrapWithX11 ''
    machine.succeed("test -d /home/testuser/.config/zen/default")

    # Pre-seed the session with the spaces in alphabetical order; the
    # declared positions should be Zulu -> Alpha -> Mike.
    machine.succeed(
        """
    cat > /tmp/sess-order.json <<'EOF'
    {
      "spaces": [
        {"uuid": "{aaaa0002-0000-4000-8000-000000000002}", "name": "Alpha", "containerTabId": 0, "theme": {}},
        {"uuid": "{aaaa0003-0000-4000-8000-000000000003}", "name": "Mike", "containerTabId": 0, "theme": {}},
        {"uuid": "{aaaa0001-0000-4000-8000-000000000001}", "name": "Zulu", "containerTabId": 0, "theme": {}}
      ],
      "tabs": [],
      "folders": [],
      "groups": [],
      "splitViewData": []
    }
    EOF
    mozlz4a /tmp/sess-order.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
    chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
    """
    )

    machine.succeed("systemctl restart home-manager-testuser.service")
    machine.wait_for_unit("home-manager-testuser.service")

    machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions.json")

    machine.succeed(
      "jq -e '.spaces | map(.name) == [\"Zulu\", \"Alpha\", \"Mike\"]' /tmp/sessions.json"
    )
    machine.succeed(
      "jq -e '.spaces | map(.position) == [1000, 2000, 3000]' /tmp/sessions.json"
    )
  '';
}
