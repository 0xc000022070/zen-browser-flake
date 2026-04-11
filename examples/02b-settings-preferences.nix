# Profile settings/preferences (prefs.js)
# User preferences that can be changed in browser
#
# In about:config, search "zen."
{...}: {
  programs.zen-browser.profiles.default.settings = {
    /**
    use double quotes!
    */
    "zen.workspaces.continue-where-left-off" = true;
    "zen.view.compact.hide-tabbar" = true;
    "zen.urlbar.behavior" = "float";
    "zen.welcome-screen.seen" = true;
  };
}
# Three-layer configuration overview:
#
# 1. policies (top-level, policies.json)
#    DisableAppUpdate, DisablePocket, etc. — enforced, user can't change
#
# 2. policies.Preferences (in policies.json)
#    Locked preference values like browser.startup.homepage — enforced, user can't change
#
# 3. profiles.*.settings (prefs.js)
#    User preferences like zen.* settings — defaults, user can change in browser
#
# Key rules for profiles.*.settings:
# - ALWAYS quote non-Zen keys: "browser.tabs.warnOnClose" = false;
# - Don't use nested notation for browser.*: don't do browser = { tabs.warnOnClose = ... }
# - Zen.* settings work reliably with quoted keys
# - Settings persist to prefs.js; user can override in browser
#
# Troubleshooting settings not persisting: see issue #293
# https://github.com/0xc000022070/zen-browser-flake/issues/293

