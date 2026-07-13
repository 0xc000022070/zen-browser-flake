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
        generalId = "aaaa0001-0000-4000-8000-00000000000a";
        workId = "aaaa0002-0000-4000-8000-00000000000b";
      in {
        pinsForce = true;
        pinsForceAction = "remove";

        spaces = {
          "General" = {
            id = generalId;
            position = 1000;

            pins = {
              "NixOS" = {
                id = "1213fc75-2019-436e-9c26-0b7995e8ca37";
                url = "https://nixos.org";
                position = 101;
              };
              "GitHub" = {
                id = "d9acb137-4117-4b54-a3de-4eab1a7001dd";
                url = "https://github.com";
                position = 102;
                isEssential = true;
              };
            };
          };

          "Work" = {
            id = workId;
            position = 2000;

            pins = {
              "Nix Packages" = {
                id = "f8dd784e-11d7-430a-8f57-7b05ecdb4c77";
                url = "https://search.nixos.org/packages";
                position = 201;
              };

              # Embedded folder: isGroup implied, children inherit
              # workspace + folderParentId.
              "Tools" = {
                id = "bbbb0001-0000-4000-8000-00000000000c";
                position = 300;

                pins."Hydra" = {
                  id = "bbbb0002-0000-4000-8000-00000000000d";
                  url = "https://hydra.nixos.org";
                  position = 301;
                };
              };
            };
          };
        };

        # Flat pins still coexist and target spaces via `workspace`.
        pins = {
          "Nix Options" = {
            id = "92931d60-fd40-4707-9512-a57b1a6a3919";
            url = "https://search.nixos.org/options";
            position = 202;
            workspace = workId;
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
      cat > /tmp/sess-scoped.json <<'EOF'
      {
        "spaces": [],
        "folders": [],
        "groups": [],
        "splitViewData": [],
        "tabs": [
          {
            "pinned": true,
            "zenSyncId": "{deadbeef-0000-4000-8000-000000000000}",
            "zenEssential": false,
            "index": 1,
            "entries": [{"url": "https://example.com/orphan"}]
          }
        ]
      }
      EOF
      mozlz4a /tmp/sess-scoped.json /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-sessions.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-sessions.jsonlz4 /tmp/sessions.json")

      machine.succeed("jq -e '.spaces | length == 2' /tmp/sessions.json")

      # Nested pins inherit the owning space's workspace id
      machine.succeed(
        "jq -e '.tabs[] | select(.zenSyncId == \"{1213fc75-2019-436e-9c26-0b7995e8ca37}\") | .zenWorkspace == \"{aaaa0001-0000-4000-8000-00000000000a}\" and .entries[0].url == \"https://nixos.org\"' /tmp/sessions.json"
      )
      machine.succeed(
        "jq -e '.tabs[] | select(.zenSyncId == \"{d9acb137-4117-4b54-a3de-4eab1a7001dd}\") | .zenWorkspace == \"{aaaa0001-0000-4000-8000-00000000000a}\" and .zenEssential == true' /tmp/sessions.json"
      )
      machine.succeed(
        "jq -e '.tabs[] | select(.zenSyncId == \"{f8dd784e-11d7-430a-8f57-7b05ecdb4c77}\") | .zenWorkspace == \"{aaaa0002-0000-4000-8000-00000000000b}\"' /tmp/sessions.json"
      )

      # Flat pin coexists with the same workspace targeting
      machine.succeed(
        "jq -e '.tabs[] | select(.zenSyncId == \"{92931d60-fd40-4707-9512-a57b1a6a3919}\") | .zenWorkspace == \"{aaaa0002-0000-4000-8000-00000000000b}\"' /tmp/sessions.json"
      )

      # Embedded folder: child tab carries the folder's groupId and the space's
      # workspace; the folder row lands in the space with no placeholder tab
      machine.succeed(
        "jq -e '.tabs[] | select(.zenSyncId == \"{bbbb0002-0000-4000-8000-00000000000d}\") | .groupId == \"{bbbb0001-0000-4000-8000-00000000000c}\" and .zenWorkspace == \"{aaaa0002-0000-4000-8000-00000000000b}\"' /tmp/sessions.json"
      )
      machine.succeed(
        "jq -e '.folders[] | select(.id == \"{bbbb0001-0000-4000-8000-00000000000c}\") | .workspaceId == \"{aaaa0002-0000-4000-8000-00000000000b}\" and .emptyTabIds == []' /tmp/sessions.json"
      )

      # pinsForce=remove counts nested pins as declared: they survive, the orphan does not
      machine.succeed("jq -e '[.tabs[] | select(.pinned == true)] | length == 5' /tmp/sessions.json")
      machine.succeed(
        "jq -e '[.tabs[] | select(.zenSyncId == \"{deadbeef-0000-4000-8000-000000000000}\")] | length == 0' /tmp/sessions.json"
      )
    '';
}
