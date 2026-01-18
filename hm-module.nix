{
  home-manager,
  self,
  name,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    getAttrFromPath
    isPath
    mkIf
    mkOption
    setAttrByPath
    types
    ;

  cfg = getAttrFromPath modulePath config;

  applicationName = "Zen Browser";
  modulePath = [
    "programs"
    "zen-browser"
  ];

  linuxConfigPath = ".zen";
  darwinConfigPath = "Library/Application Support/Zen";

  # Actual profile directory path where places.sqlite is located
  profilePath = "${(
    if pkgs.stdenv.isDarwin
    then "${darwinConfigPath}/Profiles"
    else linuxConfigPath
  )}";

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "zen-${name}";
      unwrappedPackageName = "zen-${name}-unwrapped";
      visible = true;
      platforms = {
        linux = {
          vendorPath = linuxConfigPath;
          configPath = linuxConfigPath;
        };
        darwin = {
          configPath = darwinConfigPath;
          defaultsId = "app.zen-browser.zen";
        };
      };
    })
  ];

  options = setAttrByPath modulePath {
    extraPrefsFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of extra preference files to be included.";
    };

    extraPrefs = mkOption {
      type = types.str;
      default = "";
      description = "Extra preferences to be included.";
    };

    icon = mkOption {
      type = types.nullOr (types.either types.str types.path);
      default = null;
      description = "Icon to be used for the application. It's only expected to work on Linux.";
    };

    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                spacesForce = mkOption {
                  type = bool;
                  description = "Whether to delete existing spaces not declared in the configuration.";
                  default = false;
                };
                spaces = mkOption {
                  type = attrsOf (
                    submodule (
                      {name, ...}: {
                        options = {
                          name = mkOption {
                            type = str;
                            description = "Name of the space.";
                            default = name;
                          };
                          id = mkOption {
                            type = str;
                            description = "REQUIRED. Unique Version 4 UUID for space.";
                          };
                          position = mkOption {
                            type = ints.unsigned;
                            description = "Position of space in the left bar.";
                            default = 1000;
                          };
                          icon = mkOption {
                            type = nullOr (either str path);
                            description = "Emoji or icon URI to be used as space icon.";
                            apply = v:
                              if isPath v
                              then "file://${v}"
                              else v;
                            default = null;
                          };
                          container = mkOption {
                            type = nullOr ints.unsigned;
                            description = "Container ID to be used in space";
                            default = null;
                          };
                          theme.type = mkOption {
                            type = nullOr str;
                            default = "gradient";
                          };
                          theme.colors = mkOption {
                            type = nullOr (
                              listOf (
                                submodule (
                                  {...}: {
                                    options = {
                                      red = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      green = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      blue = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      custom = mkOption {
                                        type = bool;
                                        default = false;
                                      };
                                      algorithm = mkOption {
                                        type = enum [
                                          "complementary"
                                          "floating"
                                          "analogous"
                                        ];
                                        default = "floating";
                                      };
                                      primary = mkOption {
                                        type = bool;
                                        default = true;
                                      };
                                      lightness = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      position.x = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      position.y = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      type = mkOption {
                                        type = enum [
                                          "undefined"
                                          "explicit-lightness"
                                        ];
                                        default = "undefined";
                                      };
                                    };
                                  }
                                )
                              )
                            );
                            default = [];
                          };
                          theme.opacity = mkOption {
                            type = nullOr float;
                            default = 0.5;
                          };
                          theme.rotation = mkOption {
                            type = nullOr int;
                            default = null;
                          };
                          theme.texture = mkOption {
                            type = nullOr float;
                            default = 0.0;
                          };
                        };
                      }
                    )
                  );
                  default = {};
                };
                pinsForce = mkOption {
                  type = bool;
                  description = "Whether to delete existing pins not declared in the configuration.";
                  default = false;
                };
                pins = mkOption {
                  type = attrsOf (
                    submodule (
                      {name, ...}: {
                        options = {
                          title = mkOption {
                            type = str;
                            description = "title of the pin.";
                            default = name;
                          };
                          id = mkOption {
                            type = str;
                            description = "REQUIRED. Unique Version 4 UUID for pin.";
                          };
                          url = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Optional URL text field";
                          };
                          container = mkOption {
                            type = nullOr ints.unsigned;
                            default = null;
                            description = "Container ID to be used in pin";
                          };
                          workspace = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Workspace ID to be used in pin";
                          };
                          position = mkOption {
                            type = ints.unsigned;
                            default = 1000;
                            description = "Position of the pin.";
                          };
                          isEssential = mkOption {
                            type = bool;
                            default = false;
                            description = "Required boolean flag for essential items, defaults to false";
                          };
                          isGroup = mkOption {
                            type = bool;
                            default = false;
                            description = "Required boolean flag for group items, defaults to false";
                          };
                          editedTitle = mkOption {
                            type = bool;
                            default = false;
                            description = "Required boolean flag for edited title, defaults to false";
                          };
                          isFolderCollapsed = mkOption {
                            type = bool;
                            default = false;
                            description = "Required boolean flag for folder collapse state, defaults to false";
                          };
                          folderIcon = mkOption {
                            type = nullOr str;
                            description = "Emoji or icon URI to be used as pin folder icon.";
                            default = null;
                          };
                          folderParentId = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Optional folder parent UUID text field";
                          };
                        };
                      }
                    )
                  );
                  default = {};
                };
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
                mods = mkOption {
                  type = listOf str;
                  default = [];
                  description = "List of mod UUIDs to install from the Zen theme store.";
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.icon == null || pkgs.stdenv.isLinux;
        message = "The 'icon' option is only supported on Linux.";
      }
    ];
    programs.zen-browser = {
      package = lib.mkDefault (
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
            # Seems like zen uses relative (to the original binary) path to the policies.json file
            # and ignores the overrides by pkgs.wrapFirefox
            policies = cfg.policies;
          }) {
            icon =
              if cfg.icon != null
              then cfg.icon
              else if name == "beta"
              then "zen-browser"
              else "zen-${name}";
          }).override
        {
          extraPrefs = cfg.extraPrefs;
          extraPrefsFiles = cfg.extraPrefsFiles;
          nativeMessagingHosts = cfg.nativeMessagingHosts;
        }
      );

      policies = {
        DisableAppUpdate = lib.mkDefault true;
        DisableTelemetry = lib.mkDefault true;
      };
    };

    home.file = let
      inherit
        (builtins)
        isNull
        toJSON
        toString
        ;
      inherit
        (lib)
        concatStringsSep
        concatMapStringsSep
        concatMapAttrsStringSep
        filterAttrs
        getExe
        getExe'
        mapAttrs'
        mapAttrsToList
        nameValuePair
        optionalString
        pipe
        ;
    in (mapAttrs' (
      profileName: profile: let
        sqlite3 = getExe' pkgs.sqlite "sqlite3";
        scriptFile = "${profilePath}/${profileName}/places_update.sh";
        placesFile = "${config.home.homeDirectory}/${profilePath}/${profileName}/places.sqlite";

        insertSpaces = ''
                    # Reference: https://github.com/zen-browser/desktop/blob/4e2dfd8a138fd28767bb4799a3ca9d8aab80430e/src/zen/workspaces/ZenWorkspacesStorage.mjs#L25-L55
                    ${sqlite3} "${placesFile}" "${
            concatStringsSep " " [
              "CREATE TABLE IF NOT EXISTS zen_workspaces ("
              "id INTEGER PRIMARY KEY,"
              "uuid TEXT UNIQUE NOT NULL,"
              "name TEXT NOT NULL,"
              "icon TEXT,"
              "container_id INTEGER,"
              "position INTEGER NOT NULL DEFAULT 0,"
              "created_at INTEGER NOT NULL,"
              "updated_at INTEGER NOT NULL"
              ");"
            ]
          }" || exit 1

                    columns=($(${sqlite3} "${placesFile}" "SELECT name FROM pragma_table_info('zen_workspaces');"))
                    if [[ ! "''${columns[@]}" =~ "theme_type" ]]; then
                      ${sqlite3} "${placesFile}" "ALTER TABLE zen_workspaces ADD COLUMN theme_type TEXT;" || exit 1
                    fi
                    if [[ ! "''${columns[@]}" =~ "theme_colors" ]]; then
                      ${sqlite3} "${placesFile}" "ALTER TABLE zen_workspaces ADD COLUMN theme_colors TEXT;" || exit 1
                    fi
                    if [[ ! "''${columns[@]}" =~ "theme_opacity" ]]; then
                      ${sqlite3} "${placesFile}" "ALTER TABLE zen_workspaces ADD COLUMN theme_opacity REAL;" || exit 1
                    fi
                    if [[ ! "''${columns[@]}" =~ "theme_rotation" ]]; then
                      ${sqlite3} "${placesFile}" "ALTER TABLE zen_workspaces ADD COLUMN theme_rotation INTEGER;" || exit 1
                    fi
                    if [[ ! "''${columns[@]}" =~ "theme_texture" ]]; then
                      ${sqlite3} "${placesFile}" "ALTER TABLE zen_workspaces ADD COLUMN theme_texture REAL;" || exit 1
                    fi

                    # Reference: https://github.com/zen-browser/desktop/blob/4e2dfd8a138fd28767bb4799a3ca9d8aab80430e/src/zen/workspaces/ZenWorkspacesStorage.mjs#L141-L149
                    ${sqlite3} "${placesFile}" <<-'SQL' || exit 1
          ${
            (concatStringsSep " " [
              "INSERT OR REPLACE INTO zen_workspaces ("
              "uuid,"
              "name,"
              "icon,"
              "container_id,"
              "position,"

              "theme_type,"
              "theme_colors,"
              "theme_opacity,"
              "theme_rotation,"
              "theme_texture,"

              "created_at,"
              "updated_at"
              ") VALUES "
            ])
            + (pipe profile.spaces [
              (mapAttrsToList (
                _: s: [
                  "'{${s.id}}'"
                  "'${s.name}'"
                  (
                    if isNull s.icon
                    then "NULL"
                    else "'${s.icon}'"
                  )
                  (
                    if isNull s.container
                    then "NULL"
                    else toString s.container
                  )
                  (toString s.position)
                  (
                    if isNull s.theme.type
                    then "NULL"
                    else "'${s.theme.type}'"
                  )
                  (
                    if isNull s.theme.colors
                    then "NULL"
                    else "'${
                      toJSON (
                        map (c: {
                          inherit
                            (c)
                            algorithm
                            lightness
                            position
                            type
                            ;
                          c = [
                            c.red
                            c.green
                            c.blue
                          ];
                          isCustom = c.custom;
                          isPrimary = c.primary;
                        })
                        s.theme.colors
                      )
                    }'"
                  )
                  (
                    if isNull s.theme.opacity
                    then "NULL"
                    else toString s.theme.opacity
                  )
                  (
                    if isNull s.theme.rotation
                    then "NULL"
                    else toString s.theme.rotation
                  )
                  (
                    if isNull s.theme.texture
                    then "NULL"
                    else toString s.theme.texture
                  )
                  "COALESCE((SELECT created_at FROM zen_workspaces WHERE uuid = '{${s.id}}'), strftime('%s', 'now'))"
                  "strftime('%s', 'now')"
                ]
              ))
              (map (row: concatStringsSep "," row))
              (concatMapStringsSep "," (row: "(${row})"))
            ])
          }
          SQL
        '';

        deleteSpaces = ''
          ${sqlite3} "${placesFile}" "DELETE FROM zen_workspaces ${
            if profile.spaces != {}
            then "WHERE "
            else ""
          }${concatMapAttrsStringSep " AND " (_: s: "NOT uuid = '{${s.id}}'") profile.spaces}" || exit 1
        '';

        insertPins = ''
          #Reference https://github.com/zen-browser/desktop/blob/28bf0458e43e2bb741cd67834d2b50ce2b5587c6/src/zen/tabs/ZenPinnedTabsStorage.mjs#L12-L26
          # Create the pins table if it doesn't exist
          ${sqlite3} "${placesFile}" "${
            concatStringsSep " " [
              "CREATE TABLE IF NOT EXISTS zen_pins ("
              "id INTEGER PRIMARY KEY,"
              "uuid TEXT UNIQUE NOT NULL,"
              "title TEXT NOT NULL,"
              "url TEXT,"
              "container_id INTEGER,"
              "workspace_uuid TEXT,"
              "position INTEGER NOT NULL DEFAULT 0,"
              "is_essential BOOLEAN NOT NULL DEFAULT 0,"
              "is_group BOOLEAN NOT NULL DEFAULT 0,"
              "created_at INTEGER NOT NULL,"
              "updated_at INTEGER NOT NULL"
              ");"
            ]
          }" || exit 1

          columns=($(${sqlite3} "${placesFile}" "SELECT name FROM pragma_table_info('zen_pins');"))

          if [[ ! "''${columns[@]}" =~ "edited_title" ]]; then
            ${sqlite3} "${placesFile}" "ALTER TABLE zen_pins ADD COLUMN edited_title BOOLEAN NOT NULL DEFAULT 0;" || exit 1
          fi
          if [[ ! "''${columns[@]}" =~ "is_folder_collapsed" ]]; then
            ${sqlite3} "${placesFile}" "ALTER TABLE zen_pins ADD COLUMN is_folder_collapsed BOOLEAN NOT NULL DEFAULT 0;" || exit 1
          fi
          if [[ ! "''${columns[@]}" =~ "folder_icon" ]]; then
            ${sqlite3} "${placesFile}" "ALTER TABLE zen_pins ADD COLUMN folder_icon TEXT DEFAULT NULL;" || exit 1
          fi
          if [[ ! "''${columns[@]}" =~ "folder_parent_uuid" ]]; then
            ${sqlite3} "${placesFile}" "ALTER TABLE zen_pins ADD COLUMN folder_parent_uuid TEXT DEFAULT NULL;" || exit 1
          fi

          # Reference https://github.com/zen-browser/desktop/blob/28bf0458e43e2bb741cd67834d2b50ce2b5587c6/src/zen/tabs/ZenPinnedTabsStorage.mjs#L103-L112
          # Insert or replace the pin
          ${sqlite3} "${placesFile}" <<-'SQL' || exit 1
          ${
            (concatStringsSep " " [
              "INSERT OR REPLACE INTO zen_pins ("
              "uuid,"
              "title,"
              "url,"
              "container_id,"
              "workspace_uuid,"
              "position,"
              "is_essential,"
              "is_group,"
              "folder_parent_uuid,"
              "edited_title,"
              "created_at,"
              "updated_at,"
              "is_folder_collapsed,"
              "folder_icon"
              ") VALUES "
            ])
            + (pipe profile.pins [
              (mapAttrsToList (
                _: p: [
                  "'{${p.id}}'"
                  "'${p.title}'"
                  (
                    if isNull p.url
                    then "NULL"
                    else "'${p.url}'"
                  )
                  (
                    if isNull p.container
                    then "NULL"
                    else toString p.container
                  )
                  (
                    if isNull p.workspace
                    then "NULL"
                    else "'{${p.workspace}}'"
                  )
                  (toString p.position)
                  (
                    if p.isEssential
                    then "1"
                    else "0"
                  )
                  (
                    if p.isGroup
                    then "1"
                    else "0"
                  )
                  (
                    if isNull p.folderParentId
                    then "NULL"
                    else "'{${p.folderParentId}}'"
                  )
                  (
                    if p.editedTitle
                    then "1"
                    else "0"
                  )
                  "COALESCE((SELECT created_at FROM zen_pins WHERE uuid = '{${p.id}}'), strftime('%s', 'now'))"
                  "strftime('%s', 'now')"
                  (
                    if p.isFolderCollapsed
                    then "1"
                    else "0"
                  )
                  (
                    if isNull p.folderIcon
                    then "NULL"
                    else "'${p.folderIcon}'"
                  )
                ]
              ))
              (map (row: concatStringsSep "," row))
              (concatMapStringsSep "," (row: "(${row})"))
            ])
          }
          SQL
        '';

        deletePins = ''
          ${sqlite3} "${placesFile}" "DELETE FROM zen_pins ${
            if profile.pins != {}
            then "WHERE "
            else ""
          }${concatMapAttrsStringSep " AND " (_: p: "NOT uuid = '{${p.id}}'") profile.pins}" || exit 1
        '';
      in
        nameValuePair scriptFile {
          source = getExe (
            pkgs.writeShellScriptBin "places_update_${profileName}" ''
              # This file is generated by Zen browser Home Manager module, please to not change it since it
              # will be overridden and executed on every rebuild of the home environment.

              function update_places() {
                ${optionalString (profile.spaces != {}) insertSpaces}
                ${optionalString (profile.spacesForce) deleteSpaces}
                ${optionalString (profile.pins != {}) insertPins}
                ${optionalString (profile.pinsForce) deletePins}

                # Force WAL checkpoint to ensure changes are visible immediately
                ${sqlite3} "${placesFile}" "PRAGMA wal_checkpoint(FULL);" || exit 1
              }

              error="$(update_places 2>&1 1>/dev/null)"
              if [[ "$?" -ne 0 ]]; then
                if [[ "$error" == *"database is locked"* ]]; then
                  echo "$error"

                  YELLOW="\033[1;33m"
                  NC="\033[0m"
                  echo -e "zen-update-places:''${YELLOW} Atempted to update the \"zen_workspaces\" table with values declared in \"programs.zen.profiles.\"${profileName}\".spaces\".''${NC}"
                  echo -e "zen-update-places:''${YELLOW} Failed to update \"${placesFile}\" due to a Zen browser instance for profile \"${profileName}\" being opened, please close''${NC}"
                  echo -e "zen-update-places:''${YELLOW} Zen browser and rebuild the home environment to rerun \"home-manager-${config.home.username}.service\" and update places.sqlite.''${NC}"
                else
                  echo "$error"
                fi
                exit 1
              else
                exit 0
              fi
            ''
          );
          onChange = ''
            "${config.home.homeDirectory}/${scriptFile}"
            if [[ "$?" -ne 0 ]]; then
              RED="\033[0;31m"
              NC="\033[0m"
              echo -e "zen-update-places:''${RED} Failed to update places.sqlite file for Zen browser \"${profileName}\" profile.''${NC}"
            fi
          '';
          executable = true;
          force = true;
        }
    ) (filterAttrs (_: profile: profile.spaces != {} || profile.spacesForce || profile.pins != {} || profile.pinsForce) cfg.profiles));

    home.activation = let
      inherit (builtins) toJSON;
      inherit
        (lib)
        filterAttrs
        mapAttrs'
        nameValuePair
        optionalString
        ;
      # Filter profiles that have keyboard shortcuts configured
      profilesWithShortcuts =
        filterAttrs
        (_: profile: profile.keyboardShortcuts != [])
        cfg.profiles;
    in
      (mapAttrs'
        (
          profileName: profile: let
            shortcutsFile = "${profilePath}/${profileName}/zen-keyboard-shortcuts.json";
            shortcutsFilePath = "${config.home.homeDirectory}/${shortcutsFile}";
            prefsFile = "${config.home.homeDirectory}/${profilePath}/${profileName}/prefs.js";

            # Convert Nix shortcut config to JSON format
            # All binding fields are included (with null/false defaults) to fully replace the binding
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

            # Generate the shortcuts overrides array
            declaredShortcuts = map shortcutToJson profile.keyboardShortcuts;

            # Script to update shortcuts
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
        profilesWithShortcuts)
      # Mods activation
      // (let
        profilesWithMods =
          filterAttrs
          (_: profile: profile.mods != [])
          cfg.profiles;
      in
        mapAttrs'
        (
          profileName: profile: let
            themesFile = "${profilePath}/${profileName}/zen-themes.json";
            themesFilePath = "${config.home.homeDirectory}/${themesFile}";

            updateModsScript = pkgs.writeShellScript "zen-mods-update-${profileName}" ''
                            THEMES_FILE="${themesFilePath}"
                            MODS="${lib.concatStringsSep " " profile.mods}"
                            BASE_DIR="${config.home.homeDirectory}/.zen/${profileName}"
                            MANAGED_FILE="$BASE_DIR/zen-mods-nix-managed.json"

                            if [ ! -f "$THEMES_FILE" ]; then
                              echo '{}' > "$THEMES_FILE"
                            fi

                            # Read current managed mods
                            if [ -f "$MANAGED_FILE" ]; then
                              CURRENT_MANAGED=$(${lib.getExe pkgs.jq} -r '.[]' "$MANAGED_FILE" 2>/dev/null || echo "")
                            else
                              CURRENT_MANAGED=""
                            fi

                            # Remove mods not in current list
                            for uuid in $CURRENT_MANAGED; do
                              if [[ " $MODS " != *" $uuid "* ]]; then
                                ${lib.getExe pkgs.jq} "del(.[\"$uuid\"])" "$THEMES_FILE" > "$THEMES_FILE.tmp" && mv "$THEMES_FILE.tmp" "$THEMES_FILE"
                                rm -rf "$BASE_DIR/chrome/zen-themes/$uuid"
                                echo "Removed mod $uuid"
                              fi
                            done

                            # Install/update current mods
                            for mod_uuid in $MODS; do
                              THEME_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_uuid/theme.json"
                              echo "Fetching mod $mod_uuid from $THEME_URL"

                              THEME_JSON=$(${lib.getExe pkgs.curl} -s "$THEME_URL")
                              if [ $? -ne 0 ] || [ -z "$THEME_JSON" ]; then
                                echo "Failed to fetch theme for mod $mod_uuid"
                                continue
                              fi

                              if ! echo "$THEME_JSON" | ${lib.getExe pkgs.jq} empty 2>/dev/null; then
                                echo "Invalid JSON for mod $mod_uuid"
                                continue
                              fi

                              # Merge into themes file
                              ${lib.getExe pkgs.jq} --arg uuid "$mod_uuid" --argjson theme "$THEME_JSON" '.[$uuid] = $theme' "$THEMES_FILE" > "$THEMES_FILE.tmp" && mv "$THEMES_FILE.tmp" "$THEMES_FILE"

                              # Download mod files
                              MOD_DIR="$BASE_DIR/chrome/zen-themes/$mod_uuid"
                              mkdir -p "$MOD_DIR"

                              for file in chrome.css preferences.json readme.md; do
                                FILE_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_uuid/$file"
                                echo "Downloading $file for mod $mod_uuid"
                                ${lib.getExe pkgs.curl} -s "$FILE_URL" -o "$MOD_DIR/$file" || true
                              done
                            done

                            # Write new managed list
                            echo "$MODS" | tr ' ' '\n' | ${lib.getExe pkgs.jq} -R -s 'split("\n") | map(select(. != ""))' > "$MANAGED_FILE"

                            # Generate zen-themes.css
                            ZEN_THEMES_CSS="$BASE_DIR/chrome/zen-themes.css"
                            echo "/* Zen Mods - Generated by Zen Browser Flake." > "$ZEN_THEMES_CSS"
                            cat >> "$ZEN_THEMES_CSS" << 'EOF'
              * DO NOT EDIT THIS FILE DIRECTLY!
              * Your changes will be overwritten.
              * Instead, go to the preferences and edit the mods there.
              */
              EOF

                            # Get enabled mods
                            ENABLED_MODS=$(${lib.getExe pkgs.jq} -r 'to_entries[] | select(.value.enabled == null or .value.enabled == true) | .key' "$THEMES_FILE")

                            for mod_uuid in $ENABLED_MODS; do
                              MOD_CSS="$BASE_DIR/chrome/zen-themes/$mod_uuid/chrome.css"
                              if [ -f "$MOD_CSS" ]; then
                                MOD_INFO=$(${lib.getExe pkgs.jq} -r ".\"$mod_uuid\" | \"/* Name: \(.name) */\\n/* Description: \(.description) */\\n/* Author: @\(.author) */\"" "$THEMES_FILE")
                                echo "$MOD_INFO" >> "$ZEN_THEMES_CSS"
                                cat "$MOD_CSS" >> "$ZEN_THEMES_CSS"
                                echo "" >> "$ZEN_THEMES_CSS"
                              fi
                            done

                            echo "/* End of Zen Mods */" >> "$ZEN_THEMES_CSS"

                            if ! ${lib.getExe pkgs.jq} empty "$THEMES_FILE" 2>/dev/null; then
                              echo "Error: Generated invalid JSON in $THEMES_FILE"
                              exit 1
                            fi
            '';
          in
            nameValuePair "zen-mods-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"] ''
              ${updateModsScript}
              if [[ "$?" -eq 0 ]]; then
                $VERBOSE_ECHO "zen-mods: Updated mods for profile '${profileName}'"
              else
                echo "zen-mods: Failed to update mods for profile '${profileName}'!" >&2
              fi
            '')
        )
        profilesWithMods);
  };
}
