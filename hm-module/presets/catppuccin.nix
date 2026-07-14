# Catppuccin preset (catppuccin/zen-browser, pinned in sources.json).
# The theme is symlinked to chrome/catppuccin and activated through the
# upstream userChrome/userContent options as mkDefault `@import`s instead of
# writing chrome/userChrome.css directly: the upstream module already owns
# that file, and a non-empty userChrome also makes it set the
# toolkit.legacyUserProfileCustomizations.stylesheets pref the theme needs.
# A profile-defined userChrome overrides the import (warned below).
{self}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkDefault mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  sources = builtins.fromJSON (builtins.readFile "${self}/sources.json");

  catppuccinZen = pkgs.fetchFromGitHub {
    inherit (sources.addons.catppuccin) rev hash;
    repo = "zen-browser";
    owner = "catppuccin";
  };

  flavors = ["Frappe" "Latte" "Macchiato" "Mocha"];
  accents = [
    "Blue"
    "Flamingo"
    "Green"
    "Lavender"
    "Maroon"
    "Mauve"
    "Peach"
    "Pink"
    "Red"
    "Rosewater"
    "Sapphire"
    "Sky"
    "Teal"
    "Yellow"
  ];
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                presets.catppuccin = {
                  enable = mkOption {
                    type = bool;
                    default = false;
                    description = "Enable the Catppuccin theme (catppuccin/zen-browser) for this profile.";
                  };
                  flavor = mkOption {
                    type = enum flavors;
                    default = "Mocha";
                    description = "Catppuccin flavor (base palette).";
                  };
                  accent = mkOption {
                    type = enum accents;
                    default = "Mauve";
                    description = "Catppuccin accent color.";
                  };
                };
              };

              config = mkIf config.presets.catppuccin.enable {
                userChrome = mkDefault ''@import "catppuccin/userChrome.css";'';
                userContent = mkDefault ''@import "catppuccin/userContent.css";'';

                # Upstream gates every flavor behind prefers-color-scheme
                # (Latte light, the rest dark); if the chrome scheme does not
                # match the flavor the theme never applies. Zen's own dark
                # mode (zen.view.window.scheme) does not flip that media
                # query, so align the Firefox-level scheme too.
                settings = let
                  dark = config.presets.catppuccin.flavor != "Latte";
                in {
                  "ui.systemUsesDarkTheme" = mkDefault (
                    if dark
                    then 1
                    else 0
                  );
                  "zen.view.window.scheme" = mkDefault (
                    if dark
                    then 0
                    else 1
                  );
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    warnings = lib.concatLists (
      lib.mapAttrsToList (
        profileName: profile:
          lib.optional (
            profile.presets.catppuccin.enable
            && lib.isString profile.userChrome
            && !(lib.hasInfix "catppuccin/userChrome.css" profile.userChrome)
          ) ''
            [Zen Browser] '${profileName}': userChrome overrides the catppuccin preset. Add `@import "catppuccin/userChrome.css";` at the top of your userChrome to keep the theme (likewise for userContent).
          ''
      )
      cfg.profiles
    );

    home.file =
      lib.concatMapAttrs (
        _: profile: let
          ctp = profile.presets.catppuccin;
        in
          lib.optionalAttrs ctp.enable {
            "${cfg.profilesPath}/${profile.path}/chrome/catppuccin".source = "${catppuccinZen}/themes/${ctp.flavor}/${ctp.accent}";
          }
      )
      cfg.profiles;
  };
}
