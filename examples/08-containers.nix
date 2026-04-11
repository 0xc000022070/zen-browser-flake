# Multi-container setup for organizing tabs and cookies
# Containers help isolate browsing contexts (work, personal, shopping, etc.)
#
# ⚠ Only if using pins or pinsForce: close Zen before home-manager switch
# (activation script needs exclusive access to modify zen-sessions.jsonlz4)
{
  programs.zen-browser.profiles.default = {
    containersForce = true; # Delete containers not declared here
    containers = {
      Personal = {
        color = "purple";
        icon = "fingerprint";
        id = 1;
      };
      Work = {
        color = "blue";
        icon = "briefcase";
        id = 2;
      };
      Shopping = {
        color = "yellow";
        icon = "dollar";
        id = 3;
      };
    };
  };
}
# Note: containersForce = true deletes containers not declared here.
# Set to false to keep manually created containers.

