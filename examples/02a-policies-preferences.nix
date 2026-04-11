# Locked preferences via policies (policies.json)
# Use this to enforce preferences users cannot override in browser
# These go into policies.Preferences, not regular policies
# Reference: https://mozilla.github.io/policy-templates/#preferences
{...}: {
  programs.zen-browser.policies = {
    Preferences = {
      /**
      use double quotes!
      */
      "browser.startup.homepage" = {
        Value = "about:blank";
        Status = "locked";
      };
      "browser.tabs.warnOnClose" = {
        Value = true;
        Status = "locked"; # User cannot change this
      };
    };
  };
}
