# Firefox extensions via rycee's NUR repository
# Reference: https://nur.nix-community.org/repos/rycee/
# Add to flake.nix inputs:
# firefox-addons = {
#   url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
#   inputs.nixpkgs.follows = "nixpkgs";
# };
#
# `settings` writes browser-extension-data/<id>/storage.js. Keys are the
# extension's own storage.local schema, so read its source; declare every key
# you care about, omitted ones revert to the extension's defaults on each
# switch. Requires `force`, and sets ExtensionStorageIDB.enabled=false for the
# whole profile, which drops every extension to the legacy JSON backend and
# hides what they had in IndexedDB (nix-community/home-manager#9211).
#
# Prefer the managed-storage route in 04-extensions.nix where supported.
{
  inputs,
  pkgs,
  ...
}: let
  firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in {
  programs.zen-browser.profiles.default.extensions = {
    packages = with firefox-addons; [
      ublock-origin
      clearurls
      dearrow
      proton-pass
      vimium-ff
    ];

    settings = {
      # uBlock Origin also accepts managed storage, see 04-extensions.nix.
      "uBlock0@raymondhill.net" = {
        force = true;
        settings.selectedFilterLists = [
          "user-filters"
          "ublock-filters"
          "ublock-badware"
          "ublock-privacy"
          "ublock-unbreak"
        ];
      };

      # ClearURLs reads no managed storage, this is the only declarative route.
      # Runtime keys (ClearURLsData, dataHash, log, counters) are left out on
      # purpose, the extension refetches them.
      "{74145f27-f039-47ce-a470-a662b129930a}" = {
        force = true;
        settings = {
          badged_color = "#ffa500";
          badgedStatus = true;
          contextMenuEnabled = true;
          domainBlocking = true;
          eTagFiltering = false;
          globalStatus = true;
          hashURL = "https://rules2.clearurls.xyz/rules.minify.hash";
          historyListenerEnabled = true;
          localHostsSkipping = true;
          logLimit = 100;
          loggingStatus = false;
          pingBlocking = true;
          referralMarketing = false;
          ruleURL = "https://rules2.clearurls.xyz/data.minify.json";
          statisticsStatus = true;
        };
      };
    };
  };
}
