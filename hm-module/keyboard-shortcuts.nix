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

  linuxConfigPath = "${config.xdg.configHome}/zen";
  darwinConfigPath = "${config.home.homeDirectory}/Library/Application Support/Zen";

  profilePath = "${(
    if pkgs.stdenv.isDarwin
    then "${darwinConfigPath}/Profiles"
    else linuxConfigPath
  )}";
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
                            description = "Unique identifier for the keyboard shortcut to modify.";
                          };
                          key = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "The character key (e.g., 'a', 's', '1'). Leave null to keep existing value.";
                          };
                          keycode = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Virtual key code (e.g., 'VK_F1', 'VK_DELETE'). Leave null to keep existing value.";
                          };
                          modifiers = mkOption {
                            type = nullOr (submodule {
                              options = {
                                control = mkOption {
                                  type = nullOr bool;
                                  default = null;
                                  description = "Ctrl key modifier.";
                                };
                                alt = mkOption {
                                  type = nullOr bool;
                                  default = null;
                                  description = "Alt key modifier.";
                                };
                                shift = mkOption {
                                  type = nullOr bool;
                                  default = null;
                                  description = "Shift key modifier.";
                                };
                                meta = mkOption {
                                  type = nullOr bool;
                                  default = null;
                                  description = "Meta/Windows/Command key modifier.";
                                };
                                accel = mkOption {
                                  type = nullOr bool;
                                  default = null;
                                  description = "Accelerator key (Ctrl on Windows/Linux, Cmd on macOS).";
                                };
                              };
                            });
                            default = null;
                            description = "Modifier keys for the shortcut. Leave null to keep existing values.";
                          };
                          disabled = mkOption {
                            type = nullOr bool;
                            default = null;
                            description = "Whether the shortcut is disabled. Leave null to keep existing value.";
                          };
                        };
                      }
                    )
                  );
                  default = [];
                  description = ''
                    Declarative keyboard shortcuts configuration.
                    Each item specifies a shortcut to modify by its id.
                    Only the fields you specify will be overridden; others keep their defaults from Zen.
                  '';
                };
                keyboardShortcutsVersion = mkOption {
                  type = nullOr int;
                  default = null;
                  example = 1;
                  description = ''
                    Expected version of the keyboard shortcuts schema.
                    If set, activation will fail if the Zen Browser shortcuts version doesn't match,
                    preventing silent breakage after Zen Browser updates.
                    Find the current version in about:config as "zen.keyboard.shortcuts.version".
                  '';
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    home.activation = let
      inherit (builtins) toJSON;
      inherit
        (lib)
        filterAttrs
        mapAttrs'
        nameValuePair
        optionalString
        ;

      profilesWithShortcuts =
        filterAttrs
        (_: profile: profile.keyboardShortcuts != [])
        cfg.profiles;
    in
      mapAttrs'
      (
        profileName: profile: let
          shortcutsFilePath = "${profilePath}/${profileName}/zen-keyboard-shortcuts.json";
          prefsFile = "${profilePath}/${profileName}/prefs.js";

          shortcutToJson = shortcut: {
            inherit (shortcut) id;
            key =
              if shortcut.key != null
              then shortcut.key
              else "";
            keycode = shortcut.keycode;
            modifiers =
              if shortcut.modifiers != null
              then shortcut.modifiers
              else {
                control = false;
                alt = false;
                shift = false;
                meta = false;
                accel = false;
              };
            disabled =
              if shortcut.disabled != null
              then shortcut.disabled
              else false;
          };

          declaredShortcuts = map shortcutToJson profile.keyboardShortcuts;

          updateScript = pkgs.writeShellScript "zen-shortcuts-update-${profileName}" ''
            SHORTCUTS_FILE="${shortcutsFilePath}"
            PREFS_FILE="${prefsFile}"
            OVERRIDES='${toJSON declaredShortcuts}'

            # Wait for Zen to create the shortcuts file if it doesn't exist yet
            if [ ! -f "$SHORTCUTS_FILE" ]; then
              echo "zen-keyboard-shortcuts: Shortcuts file doesn't exist yet at $SHORTCUTS_FILE"
              echo "zen-keyboard-shortcuts: Zen Browser will create it on first run"
              exit 0
            fi

            ${optionalString (profile.keyboardShortcutsVersion != null) ''
              # Version check: ensure shortcuts schema matches expected version
              if [ -f "$PREFS_FILE" ]; then
                ACTUAL_VERSION=$(${pkgs.gnugrep}/bin/grep -oP 'user_pref\("zen\.keyboard\.shortcuts\.version",\s*\K\d+' "$PREFS_FILE" || echo "")
                EXPECTED_VERSION="${toString profile.keyboardShortcutsVersion}"

                if [ -n "$ACTUAL_VERSION" ] && [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
                  echo "ERROR: Zen Browser keyboard shortcuts version mismatch!"
                  echo "  Expected version: $EXPECTED_VERSION"
                  echo "  Actual version:   $ACTUAL_VERSION"
                  echo ""
                  echo "This likely means Zen Browser was updated and keyboard shortcuts changed."
                  echo "To fix this:"
                  echo "  1. Check the new shortcuts in settings or ${shortcutsFilePath}"
                  echo "  2. Review and update your keyboard shortcuts overrides if needed"
                  echo "  3. Update keyboardShortcutsVersion = $ACTUAL_VERSION in your configuration"
                  exit 1
                fi
              fi
            ''}

            # Read existing shortcuts
            EXISTING_SHORTCUTS=$(cat "$SHORTCUTS_FILE")

            # Use jq to merge overrides into existing shortcuts
            # For each override, preserve identity fields but completely replace binding fields
            MERGED=$(echo "$EXISTING_SHORTCUTS" | ${lib.getExe pkgs.jq} --argjson overrides "$OVERRIDES" '
              .shortcuts |= map(
                . as $existing |
                # Find if there is an override for this shortcut
                ($overrides | map(select(.id == $existing.id)) | .[0]) as $override |
                if $override then
                  # Preserve identity/metadata fields from existing
                  {
                    id: $existing.id,
                    group: $existing.group,
                    l10nId: $existing.l10nId,
                    action: $existing.action,
                    reserved: $existing.reserved,
                    internal: $existing.internal
                  }
                  # Replace binding fields with override
                  + {
                    key: $override.key,
                    keycode: $override.keycode,
                    modifiers: $override.modifiers,
                    disabled: $override.disabled
                  }
                else
                  # No override, keep as is
                  $existing
                end
              )
            ')

            echo "$MERGED" > "$SHORTCUTS_FILE"

            # Validate JSON
            if ! ${lib.getExe pkgs.jq} empty "$SHORTCUTS_FILE" 2>/dev/null; then
              echo "Error: Generated invalid JSON in $SHORTCUTS_FILE"
              exit 1
            fi
          '';
        in
          nameValuePair "zen-keyboard-shortcuts-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"] ''
            ${updateScript}
            if [[ "$?" -eq 0 ]]; then
              $VERBOSE_ECHO "zen-keyboard-shortcuts: Updated keyboard shortcuts for profile '${profileName}'"
            else
              echo "zen-keyboard-shortcuts: Failed to update keyboard shortcuts for profile '${profileName}'!" >&2
            fi
          '')
      )
      profilesWithShortcuts;
  };
}
