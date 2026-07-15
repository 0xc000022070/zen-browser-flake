# Space routing: rules that send a URL to a specific space when a tab opens,
# plus a global default for links opened from outside the browser. State lands
# in zen-space-routing.jsonlz4, independent of the session file. Undeclared
# routes Zen created are preserved unless `force = true`; runtime edits to a
# declared route are overwritten on re-activation.
#
# `openIn` / `defaultExternalRoute` take a space id or the literal
# "most-recent-space". A space id is brace-wrapped internally to match Zen's
# workspace uuid — declare it here without braces, exactly like `pins.workspace`.
{
  programs.zen-browser.profiles.default = let
    workId = "8a2c47f0-1d9e-4b36-a5c8-f70e92b4d615";
    personalId = "4b1e9d72-3a56-4c80-b9f1-27e6d0a4c8b3";
  in {
    spaceRouting = {
      # Link previews / external opens with no matching rule land here.
      defaultExternalRoute = workId;

      routes = {
        "github" = {
          reference = "github.com";
          matchType = "contains"; # default
          openIn = workId;
        };

        # Exact host match, protocol/www/trailing-slash normalized.
        "reddit" = {
          reference = "reddit.com";
          matchType = "equal-to";
          openIn = personalId;
        };

        # Any *.slack.com URL.
        "slack" = {
          reference = "https?://.*\\.slack\\.com";
          matchType = "regex";
          openIn = workId;
        };
      };
    };

    # Space-scoped form: same options as spaceRouting.routes.* except openIn,
    # which is set to the owning space's id automatically. Only `reference` is
    # required; `matchType` defaults to "contains" and `id` defaults to the
    # attribute name (namespaced per space, so equal names don't collide).
    spaces = {
      "Work" = {
        id = workId;
        routes."Jira" = {
          reference = "atlassian.net"; # matchType = "contains" (default)
        };
      };

      "Personal" = {
        id = personalId;
        routes."YouTube" = {
          reference = "youtube.com"; # matchType = "contains" (default)
        };
      };
    };
  };
}
