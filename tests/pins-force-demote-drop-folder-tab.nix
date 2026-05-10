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
        pinsForce = true;
        pins = {
          "Managed" = {
            id = "33333333-3333-3333-3333-333333333333";
            url = "https://managed.example";
            title = "Managed";
            position = 10;
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
      cat > /tmp/sess-drop.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": [
          {
            "zenSyncId": "{33333333-3333-3333-3333-333333333333}",
            "pinned": true,
            "zenEssential": false,
            "zenWorkspace": null,
            "index": 0,
            "userContextId": 0,
            "groupId": null,
            "hidden": false,
            "entries": [{"url": "https://managed.example/", "title": "Managed", "charset": "UTF-8", "ID": 0, "persist": true}]
          },
          {
            "zenSyncId": "{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}",
            "pinned": true,
            "zenEssential": false,
            "zenWorkspace": null,
            "index": 1,
            "userContextId": 0,
            "groupId": "7999365636147-43",
            "hidden": false,
            "entries": [{"url": "about:blank"}]
          }
        ]
      }
      EOF
      mozlz4a /tmp/sess-drop.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-drop.json")
      machine.succeed("test $(jq '.tabs | length' /tmp/sessions-drop.json) -eq 1")
      machine.succeed(
          "jq -e '[.tabs[] | select(.zenSyncId == \"{33333333-3333-3333-3333-333333333333}\")] | length == 1' /tmp/sessions-drop.json"
      )
      machine.succeed("jq -e '[.tabs[] | select(.zenSyncId == \"{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}\")] | length == 0' /tmp/sessions-drop.json")
    '';
}
