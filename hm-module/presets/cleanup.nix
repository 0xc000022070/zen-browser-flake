# Preset pref cleanup engine. Presets apply prefs through `settings`,
# which Firefox bakes into the browser-owned prefs.js on launch; removing
# a preset stops declaring them but never un-bakes them (the arkenfox
# `browser.startup.page = 0` stranding session restore, catppuccin's
# `ui.systemUsesDarkTheme` stranding a global dark theme).
#
# Each enabled preset contributes its pref names to the internal
# `presets.managedPrefNames` bus; this engine records their effective
# values (final `settings`, so a user override is what gets recorded) in
# zen-prefs-nix-managed.json and, via the prefs-cleaner factory, resets
# any recorded pref that is no longer declared. The activation entry runs
# for every profile unconditionally: the map from the previous generation
# may exist even when no preset is enabled anymore — that is exactly the
# case that needs cleaning.
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  mkPrefsCleaner = import ../lib/prefs-cleaner.nix {inherit pkgs lib;};
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                presets.managedPrefNames = mkOption {
                  type = listOf str;
                  default = [];
                  internal = true;
                  visible = false;
                  description = ''
                    Pref names contributed by enabled presets. Tracked in the
                    profile's zen-prefs-nix-managed.json so prefs baked into
                    prefs.js are reset when the preset that set them is
                    disabled.
                  '';
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser.activationFragments = let
      inherit (lib) filterAttrs genAttrs mapAttrs' nameValuePair unique;
    in
      mapAttrs'
      (
        profileName: profile: let
          profileDir = "${cfg.profilesPath}/${profile.path}";

          # Effective values: presets set prefs with mkDefault, so the final
          # `settings` entry — user override included — is what user.js
          # writes and therefore what prefs.js will contain.
          declaredPrefs =
            filterAttrs (_: v: v != null)
            (genAttrs
              (unique profile.presets.managedPrefNames)
              (n: profile.settings.${n} or null));

          declaredFile =
            pkgs.writeText
            "zen-preset-prefs-${profileName}.json"
            (builtins.toJSON declaredPrefs);

          cleanupScript = mkPrefsCleaner {
            name = "zen-preset-prefs-cleanup-${profileName}";
            logPrefix = "zen-preset-prefs";
            inherit profileDir declaredFile;
            lockFile = "${profileDir}/.parentlock";
          };
        in
          nameValuePair profileName [
            {
              priority = 40;
              requiresLock = true;
              skipSubject = "preset prefs";
              text = ''
                ${cleanupScript}
                if [[ "$?" -eq 0 ]]; then
                  $VERBOSE_ECHO "zen-preset-prefs: Updated managed preset prefs for profile '${profileName}'"
                else
                  echo "zen-preset-prefs: Failed to clean up preset prefs for profile '${profileName}'!" >&2
                fi
              '';
            }
          ]
      )
      cfg.profiles;
  };
}
