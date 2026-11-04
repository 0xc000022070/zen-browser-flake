# Upserts into the profile's customKeys.json (about:keyboard store, Zen >= 1.24b):
# only customized ids are present, `{}` means unbound, key is uppercase.
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

  mkStateUpdater = import ./lib/state-writer.nix {inherit pkgs lib;};

  modifierNames = ["accel" "alt" "control" "meta" "shift"];
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                keyboardShortcuts = mkOption {
                  type = listOf (
                    submodule (
                      {...}: {
                        options = {
                          id = mkOption {
                            type = str;
                            description = "Id of the <key> element to rebind, as listed in the profile's customKeys.json after editing it in about:keyboard.";
                          };
                          key = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "The character key (e.g., 'a', 's', '1'). Mutually exclusive with keycode.";
                          };
                          keycode = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Virtual key code (e.g., 'VK_F1', 'VK_DELETE'). Mutually exclusive with key.";
                          };
                          modifiers = mkOption {
                            type = submodule {
                              options = {
                                control = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Ctrl key modifier.";
                                };
                                alt = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Alt key modifier.";
                                };
                                shift = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Shift key modifier.";
                                };
                                meta = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Meta/Windows/Command key modifier.";
                                };
                                accel = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Accelerator key (Ctrl on Windows/Linux, Cmd on macOS).";
                                };
                              };
                            };
                            default = {};
                            description = "Modifier keys for the shortcut.";
                          };
                          disabled = mkOption {
                            type = bool;
                            default = false;
                            description = "Unbind the shortcut.";
                          };
                        };
                      }
                    )
                  );
                  default = [];
                  description = ''
                    Keyboard shortcut overrides written to the profile's customKeys.json
                    (the store behind about:keyboard). Each entry replaces the binding of
                    the key with that id; ids not listed keep whatever about:keyboard holds.
                  '';
                };
                keyboardShortcutsVersion = mkOption {
                  type = nullOr int;
                  default = null;
                  visible = false;
                  description = "Deprecated, no effect: Zen 1.24b dropped the versioned zen-keyboard-shortcuts.json. Remove it.";
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser.activationFragments = let
      inherit (builtins) toJSON;
      inherit
        (lib)
        concatStringsSep
        filter
        filterAttrs
        listToAttrs
        mapAttrs'
        nameValuePair
        toUpper
        ;

      profilesWithShortcuts =
        filterAttrs
        (_: profile: profile.keyboardShortcuts != [])
        cfg.profiles;

      toBinding = shortcut:
        if shortcut.disabled
        then {}
        else
          filterAttrs (_: v: v != null && v != "") {
            modifiers = concatStringsSep "," (filter (m: shortcut.modifiers.${m}) modifierNames);
            key =
              if shortcut.key != null
              then toUpper shortcut.key
              else null;
            inherit (shortcut) keycode;
          };
    in
      mapAttrs'
      (
        profileName: profile: let
          declaredFile = pkgs.writeText "zen-keyboard-shortcuts-${profileName}.json" (toJSON (
            listToAttrs (map (s: nameValuePair s.id (toBinding s)) profile.keyboardShortcuts)
          ));

          updateScript = mkStateUpdater {
            name = "zen-keyboard-shortcuts-update-${profileName}";
            logPrefix = "zen-keyboard-shortcuts";
            subject = "keyboard shortcuts";
            skipSubject = "keyboard shortcuts";
            stateFile = "${cfg.profilesPath}/${profile.path}/customKeys.json";
            lockFile = "${cfg.profilesPath}/${profile.path}/.parentlock";
            compressed = false;
            initialFile = declaredFile;
            slurpfiles.declared = declaredFile;
            jqFilterFile = pkgs.writeText "zen-keyboard-shortcuts-filter.jq" ''
              (if type == "object" then . else {} end) + $declared[0]
            '';
          };
        in
          nameValuePair profileName [
            {
              priority = 50;
              requiresLock = true;
              skipSubject = "keyboard shortcuts";
              text = ''
                ${updateScript}
                if [[ "$?" -eq 0 ]]; then
                  $VERBOSE_ECHO "zen-keyboard-shortcuts: Updated keyboard shortcuts for profile '${profileName}'"
                else
                  echo "zen-keyboard-shortcuts: Failed to update keyboard shortcuts for profile '${profileName}'!" >&2
                fi
              '';
            }
          ]
      )
      profilesWithShortcuts;
  };
}
