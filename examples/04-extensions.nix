{
  programs.zen-browser.policies = let
    mkExtensionSettings = builtins.mapAttrs (_: pluginId: {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
      installation_mode = "force_installed";
    });
  in {
    ExtensionSettings = mkExtensionSettings {
      "wappalyzer@crunchlabz.com" = "wappalyzer";
      "{85860b32-02a8-431a-b2b1-40fbd64c9c69}" = "github-file-icons";
    };
  };
}
# Learn more:
# https://github.com/0xc000022070/zen-browser-flake/tree/b6b1e625e4aa049b59930611fc20790c0ccbc840?tab=readme-ov-file#extensions
#
# My config:
# https://github.com/luisnquin/nixos-config/blob/9f641d16c74cf9a90fdf5b654376a1d6c8cc1f86/home/modules/programs/browser/zen/policies-config.nix#L46
#
# I'm just too lazy to explain more about this.

