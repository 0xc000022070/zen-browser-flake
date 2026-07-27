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

    # Per-extension config via browser.storage.managed, for extensions that
    # read it — uBlock Origin does (`toOverwrite`, >= 1.33), ClearURLs does not.
    # Unlike profiles.<name>.extensions.settings (04b) it leaves the extension's
    # own storage alone, but it is a lock rather than a seed: re-asserted on
    # every start, so dashboard edits revert. Takes effect one restart late,
    # uBO caches managed storage on purpose (uAssets discussion 16939).
    "3rdparty".Extensions."uBlock0@raymondhill.net".toOverwrite = {
      # Entries matching `scheme://` are also subscribed as external lists.
      filterLists = [
        "user-filters"
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-unbreak"
        "adguard-spyware-url"
      ];
      filters = ["||ads.example.org^"]; # dashboard: My filters
      trustedSiteDirectives = ["example.org"]; # dashboard: Trusted sites
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

