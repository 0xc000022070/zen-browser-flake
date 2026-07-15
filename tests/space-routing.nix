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
        workId = "aaaa0001-0000-4000-8000-00000000000a";
        personalId = "aaaa0002-0000-4000-8000-00000000000b";
      in {
        spaceRouting = {
          defaultExternalRoute = workId;

          routes = {
            "github" = {
              reference = "github.com";
              openIn = workId;
            };
            "slack" = {
              reference = "https?://.*\\.slack\\.com";
              matchType = "regex";
              openIn = workId;
            };
          };
        };

        spaces."Personal" = {
          id = personalId;
          routes."YouTube" = {
            reference = "youtube.com";
          };
        };
      };
    };
  };

  testScript =
    wrapWithX11
    ''
      machine.succeed("test -d /home/testuser/.config/zen/default")

      # Seed an existing routing file with a browser-created route and default,
      # to verify the merge preserves undeclared routes (force = false).
      machine.succeed(
          """
      cat > /tmp/routing.json <<'EOF'
      {
        "routes": [
          {
            "id": "browser-keep",
            "reference": "keepme.com",
            "matchType": "contains",
            "openIn": "most-recent-space"
          }
        ],
        "defaultRouteExternal": "most-recent-space"
      }
      EOF
      mozlz4a /tmp/routing.json /home/testuser/.config/zen/default/zen-space-routing.jsonlz4
      chown testuser:users /home/testuser/.config/zen/default/zen-space-routing.jsonlz4
      """
      )

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      # Launch the real browser (this suite is twilight -> binary is zen-twilight,
      # not the zen-beta that wrapWithX11 no-ops on) so it loads the flake-written
      # routing file, then let it close. The state must survive the round-trip:
      # a valid jsonlz4 the browser can parse without resetting routes to [].
      machine.succeed(
        "su - testuser -c 'DISPLAY=:99 timeout 25 zen-twilight about:blank' || true"
      )
      machine.succeed("sleep 2")

      machine.succeed("mozlz4a -d /home/testuser/.config/zen/default/zen-space-routing.jsonlz4 /tmp/out.json")

      # After closing the browser: direct route intact, space id brace-wrapped
      # to Zen's workspace uuid form
      machine.succeed(
        "jq -e '.routes[] | select(.id == \"github\") | .openIn == \"{aaaa0001-0000-4000-8000-00000000000a}\" and .reference == \"github.com\" and .matchType == \"contains\"' /tmp/out.json"
      )

      # Regex route keeps its unmodified reference
      machine.succeed(
        "jq -e '.routes[] | select(.id == \"slack\") | .matchType == \"regex\"' /tmp/out.json"
      )

      # Space-scoped route: id namespaced, openIn forced to the owning space id
      machine.succeed(
        "jq -e '.routes[] | select(.id == \"spaces/Personal/YouTube\") | .openIn == \"{aaaa0002-0000-4000-8000-00000000000b}\" and .reference == \"youtube.com\"' /tmp/out.json"
      )

      # Undeclared browser route survives the merge
      machine.succeed(
        "jq -e '[.routes[] | select(.id == \"browser-keep\")] | length == 1' /tmp/out.json"
      )

      # Managed default replaces the browser value, brace-wrapped
      machine.succeed(
        "jq -e '.defaultRouteExternal == \"{aaaa0001-0000-4000-8000-00000000000a}\"' /tmp/out.json"
      )
    '';
}
