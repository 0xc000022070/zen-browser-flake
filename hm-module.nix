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

  configPath = "${config.home.homeDirectory}/${
    (
      if pkgs.stdenv.isDarwin
      then darwinConfigPath
      else linuxConfigPath
    )
  }";

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
        };
      };
    })
  ];

  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                spacesForce = mkOption {
                  type = bool;
                  description = "Whether delete existing spaces not declared in the configuration.";
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
                                        type = int;
                                        default = 0;
                                      };
                                      green = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      blue = mkOption {
                                        type = int;
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
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package =
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
          # Seems like zen uses relative (to the original binary) path to the policies.json file
          # and ignores the overrides by pkgs.wrapFirefox
          policies = cfg.policies;
        }) {}).override
        {
          nativeMessagingHosts = cfg.nativeMessagingHosts;
        };

      policies = {
        DisableAppUpdate = lib.mkDefault true;
        DisableTelemetry = lib.mkDefault true;
      };
    };

    systemd.user.services."zen-browser-spaces-activation" = let
      hasSpaces = with lib;
        pipe cfg.profiles [
          (mapAttrsToList (n: v: v.spaces != {}))
          (lists.any (v: v))
        ];
    in
      mkIf hasSpaces {
        Install.WantedBy = ["default.target"];
        Unit.After = ["home-manager-${config.home.username}.service"];
        Service = {
          Type = "oneshot";
          ExecStart = let
            inherit
              (lib)
              attrByPath
              concatMapAttrsStringSep
              concatMapStringsSep
              concatStringsSep
              elemAt
              filterAttrs
              getExe
              getExe'
              isStringLike
              mapAttrsToList
              optionalString
              pipe
              ;

            sqlite3 = getExe' pkgs.sqlite "sqlite3";
          in
            pipe cfg.profiles [
              (filterAttrs (_: v: v.spaces != {}))
              (mapAttrsToList (
                n: v: let
                  placesFile = "${configPath}/${n}/places.sqlite";
                in (pkgs.writeShellScriptBin "zen-browser-spaces-${n}" ''
                  mkdir -p "${configPath}/${n}"

                  # Reference: https://github.com/zen-browser/desktop/blob/4e2dfd8a138fd28767bb4799a3ca9d8aab80430e/src/zen/workspaces/ZenWorkspacesStorage.mjs#L25-L55
                  ${sqlite3} $placesFile "${
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
                  ${sqlite3} "${placesFile}" "${
                    concatStringsSep " " [
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
                      ") VALUES ${
                        pipe v.spaces [
                          (mapAttrsToList (
                            _: space: [
                              "{${space.id}}"
                              space.name
                              (attrByPath ["icon"] null space)
                              (attrByPath ["container"] null space)
                              (attrByPath ["position"] 0 space)
                              (attrByPath ["theme" "type"] "gradient" space)
                              (map (color: {
                                inherit
                                  (color)
                                  algorithm
                                  lightness
                                  position
                                  type
                                  ;
                                c = [
                                  color.red
                                  color.green
                                  color.blue
                                ];
                                isCustom = color.custom;
                                isPrimary = color.primary;
                              }) (attrByPath ["theme" "colors"] [] space))
                              (attrByPath ["theme" "opacity"] 0.5 space)
                              (attrByPath ["theme" "rotation"] null space)
                              (attrByPath ["theme" "texture"] 0.0 space)
                            ]
                          ))
                          (map (
                            row:
                              map (
                                v:
                                  with builtins;
                                    if isStringLike v
                                    then "'${v}'"
                                    else if (isList v) || (isAttrs v)
                                    then "'${toJSON v}'"
                                    else if isNull v
                                    then "NULL"
                                    else toString v
                              )
                              row
                          ))
                          (map (
                            row:
                              row
                              ++ [
                                "COALESCE((SELECT created_at FROM zen_workspaces WHERE uuid = ${elemAt row 0}), strftime('%s', 'now'))"
                                "strftime('%s', 'now')"
                              ]
                          ))
                          (map (row: concatStringsSep "," row))
                          (concatMapStringsSep "," (row: "(${row})"))
                        ]
                      }"
                    ]
                  }" || exit 1

                  ${optionalString v.spacesForce ''${sqlite3} "${placesFile}" "DELETE FROM zen_workspaces ${
                      if v.spaces != {}
                      then "WHERE "
                      else ""
                    }${
                      concatMapAttrsStringSep " AND " (n: v: "NOT uuid = '{${v.id}}'") v.spaces
                    }" || exit 1''}
                '')
              ))
              (list: map (pkg: getExe pkg) list)
            ];
        };
      };
  };
}
