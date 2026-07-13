# Zen Spaces with custom gradient themes
# Spaces are workspaces for organizing tabs across different contexts.
# ⚠ Only if using spaces or spacesForce: close Zen before home-manager switch
# (activation script decompresses zen-sessions.jsonlz4, modifies with jq, recompresses)
{
  programs.zen-browser.profiles.default = {
    spacesForce = true; # Delete spaces not declared here
    spaces = {
      "Personal" = {
        id = "c6de089c-410d-4206-961d-ab11f988d40a";
        position = 1000;
        icon = "🏠";

        # Pins can be declared under their space instead of the flat
        # `pins` + `workspace` pairing (see 10-pinned-tabs.nix).
        pins."Email" = {
          id = "5e8db6a4-92c7-4f31-8a60-1b9f3ce47d28";
          url = "https://mail.protonmail.com";
          position = 100;
        };
      };
      "Work" = {
        id = "cdd10fab-4fc5-494b-9041-325e5759195b";
        position = 2000;
        icon = "💼";
        theme = {
          type = "gradient";
          colors = [
            {
              red = 100;
              green = 150;
              blue = 200;
              algorithm = "floating";
              type = "explicit-lightness";
              lightness = 50;
            }
          ];
          opacity = 0.8;
          texture = 0.5;
        };
      };
      "Shopping" = {
        id = "78aabdad-8aae-4fe0-8ff0-2a0c6c4ccc24";
        position = 3000;
        icon = "💸";
      };
    };
  };
}
# Note: Changing a space's id re-creates it as new, losing opened tabs.
# If spacesForce = true, the old space is deleted.

