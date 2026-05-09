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
        # pinsForceAction defaults to "demote"
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
      cat > /tmp/sess-demote.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "lastCollected": 0,
        "splitViewData": [],
        "tabs": [
          {
            "zenSyncId": "{11111111-1111-1111-1111-111111111111}",
            "pinned": true,
            "zenEssential": false,
            "zenWorkspace": null,
            "index": 0,
            "userContextId": 0,
            "groupId": null,
            "hidden": false,
            "entries": [
              {
                "url": "https://orphan.example/",
                "title": "Orphan",
                "charset": "UTF-8",
                "ID": 0,
                "persist": true
              }
            ]
          },
          {
            "zenSyncId": "{22222222-2222-2222-2222-222222222222}",
            "pinned": false,
            "zenEssential": false,
            "zenWorkspace": null,
            "index": 1,
            "userContextId": 0,
            "groupId": null,
            "hidden": false,
            "entries": [
              {
                "url": "https://normal.example/",
                "title": "Normal",
                "charset": "UTF-8",
                "ID": 0,
                "persist": true
              }
            ]
          }
        ]
      }
      EOF
      mozlz4a /tmp/sess-demote.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions-demote.json")
      machine.succeed("test $(jq '.tabs | length' /tmp/sessions-demote.json) -eq 3")
      machine.succeed(
          "jq -e '[.tabs[] | select(.zenSyncId == \"{11111111-1111-1111-1111-111111111111}\")] | .[0] | (.pinned == false) and (.zenEssential == false) and (.groupId == null)' /tmp/sessions-demote.json"
      )
      machine.succeed(
          "jq -e '[.tabs[] | select(.zenSyncId == \"{33333333-3333-3333-3333-333333333333}\")] | .[0] | .pinned == true' /tmp/sessions-demote.json"
      )
      machine.succeed(
          "jq -e '([.tabs[] | .zenSyncId] | index(\"{33333333-3333-3333-3333-333333333333}\")) < ([.tabs[] | .zenSyncId] | index(\"{11111111-1111-1111-1111-111111111111}\")) and ([.tabs[] | .zenSyncId] | index(\"{11111111-1111-1111-1111-111111111111}\")) < ([.tabs[] | .zenSyncId] | index(\"{22222222-2222-2222-2222-222222222222}\"))' /tmp/sessions-demote.json"
      )
      machine.succeed("jq -e '[.tabs[].index] == [0,1,2]' /tmp/sessions-demote.json")
    '';
}
