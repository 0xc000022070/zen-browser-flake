# Declarative mod installation from Zen theme store
# Find mod UUIDs at: https://zen-browser.app/mods
{
  programs.zen-browser.profiles.default.mods = [
    "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
    "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
    "4ab93b88-151c-451b-a1b7-a1e0e28fa7f8" # No Sidebar Scrollbar
    "7190e4e9-bead-4b40-8f57-95d852ddc941" # Tab title fixes
    "803c7895-b39b-458e-84f8-a521f4d7a064" # Hide Inactive Workspaces
    "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
  ];
}
# Note: Browser must be restarted for changes to take effect.

