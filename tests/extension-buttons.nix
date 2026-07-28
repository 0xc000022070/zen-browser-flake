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
        settings."browser.aboutConfig.showWarning" = false;

        extensionButtons = {
          "nav-bar" = [
            "uBlock0@raymondhill.net"
            "{d7742d87-e61d-4b78-b8a1-b469842139fa}"
          ];
          # Not part of the seeded layout: must be skipped, not created.
          "zen-sidebar-foot-buttons" = ["missing@example.com"];
        };
      };
    };
  };

  testScript =
    wrapWithX11
    ''
      machine.succeed("test -d /home/testuser/.config/zen/default")

      # Fresh profile: nothing to merge into, so nothing is written.
      machine.fail("test -e /home/testuser/.config/zen/default/prefs.js")
      machine.fail("test -e /home/testuser/.config/zen/default/zen-extension-buttons-nix-managed.json")

      # One launch is enough for Zen to save a layout to merge into.
      machine.succeed(
        "su - testuser -c 'DISPLAY=:99 timeout 25 zen-twilight about:blank' || true"
      )
      machine.succeed("sleep 2")
      machine.succeed(
        "grep -q '^user_pref(\"browser.uiCustomization.state\", '"
        " /home/testuser/.config/zen/default/prefs.js"
      )

      # Seed a layout with an undeclared button and a stale one this flake
      # placed on a previous generation.
      machine.succeed(
          """
      cat > /home/testuser/.config/zen/default/prefs.js <<'EOF'
      // Mozilla User Preferences
      user_pref("browser.startup.homepage", "about:blank");
      user_pref("browser.uiCustomization.state", "{\\"placements\\":{\\"nav-bar\\":[\\"back-button\\",\\"urlbar-container\\",\\"unified-extensions-button\\",\\"stale_example_com-browser-action\\"],\\"unified-extensions-area\\":[\\"ublock0_raymondhill_net-browser-action\\",\\"keepme_example_com-browser-action\\"],\\"PersonalToolbar\\":[\\"personal-bookmarks\\"]},\\"seen\\":[\\"developer-button\\"],\\"dirtyAreaCache\\":[\\"nav-bar\\"],\\"currentVersion\\":24,\\"newElementCount\\":2}");
      user_pref("browser.zzz.last", true);
      EOF
      echo '["stale_example_com-browser-action"]' > /home/testuser/.config/zen/default/zen-extension-buttons-nix-managed.json
      chown testuser:users /home/testuser/.config/zen/default/prefs.js /home/testuser/.config/zen/default/zen-extension-buttons-nix-managed.json
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed(
        "grep '^user_pref(\"browser.uiCustomization.state\", ' /home/testuser/.config/zen/default/prefs.js"
        " | sed 's/^user_pref(\"browser.uiCustomization.state\", //; s/);$//'"
        " | jq 'fromjson' > /tmp/state.json"
      )

      machine.succeed(
        "jq -e '.placements[\"nav-bar\"] == ["
        "\"back-button\",\"urlbar-container\",\"unified-extensions-button\","
        "\"ublock0_raymondhill_net-browser-action\","
        "\"_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action\"]' /tmp/state.json"
      )

      # uBlock left the panel, the undeclared button stayed, the stale one
      # was demoted back into the panel.
      machine.succeed(
        "jq -e '.placements[\"unified-extensions-area\"] == ["
        "\"keepme_example_com-browser-action\","
        "\"stale_example_com-browser-action\"]' /tmp/state.json"
      )

      # Area absent from the saved layout is skipped, never invented.
      machine.succeed("jq -e '.placements | has(\"zen-sidebar-foot-buttons\") | not' /tmp/state.json")
      machine.succeed(
        "jq -e '[.seen[] | select(. == \"missing_example_com-browser-action\")] | length == 0' /tmp/state.json"
      )

      # Everything the flake does not manage survives the merge.
      machine.succeed(
        "jq -e '.placements.PersonalToolbar == [\"personal-bookmarks\"]"
        " and .currentVersion == 24 and .newElementCount == 2' /tmp/state.json"
      )
      machine.succeed("jq -e '.seen | index(\"developer-button\")' /tmp/state.json")
      machine.succeed(
        "jq -e '.dirtyAreaCache | index(\"nav-bar\") and index(\"unified-extensions-area\")' /tmp/state.json"
      )

      machine.succeed(
        "grep -q '^user_pref(\"browser.startup.homepage\", \"about:blank\");$'"
        " /home/testuser/.config/zen/default/prefs.js"
      )
      machine.succeed(
        "grep -n 'browser.uiCustomization.state' /home/testuser/.config/zen/default/prefs.js"
        " | grep -q '^3:'"
      )

      machine.succeed(
        "jq -e '. == [\"_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action\","
        "\"missing_example_com-browser-action\","
        "\"ublock0_raymondhill_net-browser-action\"]'"
        " /home/testuser/.config/zen/default/zen-extension-buttons-nix-managed.json"
      )

      # Re-running must not move anything a second time.
      machine.succeed("cp /home/testuser/.config/zen/default/prefs.js /tmp/prefs.before")
      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")
      machine.succeed("diff /tmp/prefs.before /home/testuser/.config/zen/default/prefs.js")

      # The placements must survive a real browser round-trip even though
      # none of these extensions are installed.
      machine.succeed(
        "su - testuser -c 'DISPLAY=:99 timeout 25 zen-twilight about:blank' || true"
      )
      machine.succeed("sleep 2")

      machine.succeed(
        "grep '^user_pref(\"browser.uiCustomization.state\", ' /home/testuser/.config/zen/default/prefs.js"
        " | sed 's/^user_pref(\"browser.uiCustomization.state\", //; s/);$//'"
        " | jq 'fromjson' > /tmp/after.json"
      )

      machine.succeed(
        "jq -e '.placements[\"nav-bar\"] | index(\"ublock0_raymondhill_net-browser-action\")"
        " and index(\"_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action\")' /tmp/after.json"
      )
      machine.succeed(
        "jq -e '.placements[\"unified-extensions-area\"]"
        " | index(\"ublock0_raymondhill_net-browser-action\") == null' /tmp/after.json"
      )
    '';
}
