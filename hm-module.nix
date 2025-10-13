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

  configPath = "${(
    if pkgs.stdenv.isDarwin
    then darwinConfigPath
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
                      { name, ... }: {
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
                            description = "Optional workspace UUID text field";
                          };
                          position = mkOption {
                            type = ints.unsigned;
                            default = 1000;
                            description = "Required position integer, defaults to 0";
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
                            type = nullOr (either str path);
                            description = "Emoji or icon URI to be used as pin folder icon.";
                            apply = v:
                              if isPath v
                              then "file://${v}"
                              else v;
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
                  default = { };
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package = lib.mkDefault (
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
            # Seems like zen uses relative (to the original binary) path to the policies.json file
            # and ignores the overrides by pkgs.wrapFirefox
            policies = cfg.policies;
          }) {
            icon =
              if name == "beta"
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
        scriptFile = "${configPath}/${profileName}/places_update.sh";
        placesFile = "${config.home.homeDirectory}/${configPath}/${profileName}/places.sqlite";

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
      in
        nameValuePair scriptFile {
          source = getExe (
            pkgs.writeShellScriptBin "places_update_${profileName}" ''
              # This file is generated by Zen browser Home Manager module, please to not change it since it
              # will be overridden and executed on every rebuild of the home environment.

              function update_spaces() {
                ${optionalString (profile.spaces != {}) insertSpaces}
                ${optionalString (profile.spacesForce) deleteSpaces}
              }

              error="$(update_spaces 2>&1 1>/dev/null)"
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
            ${config.home.homeDirectory}/${scriptFile}
            if [[ "$?" -ne 0 ]]; then
              RED="\033[0;31m"
              NC="\033[0m"
              echo -e "zen-update-places:''${RED} Failed to update places.sqlite file for Zen browser \"${profileName}\" profile.''${NC}"
            fi
          '';
          executable = true;
          force = true;
        }
    ) (filterAttrs (_: profile: profile.spaces != {} || profile.spacesForce) cfg.profiles));
  };
}
