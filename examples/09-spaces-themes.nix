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

