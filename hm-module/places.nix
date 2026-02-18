{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath isPath mkIf mkOption setAttrByPath types;

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
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    home.activation = let
      inherit
        (builtins)
        isNull
        toJSON
        ;
      inherit
        (lib)
        filterAttrs
        getExe
        mapAttrs'
        mapAttrsToList
        nameValuePair
        optionalAttrs
        optionalString
        ;

      profilesWithPlaces =
        filterAttrs
        (_: profile: profile.spaces != {} || profile.spacesForce || profile.pins != {} || profile.pinsForce)
        cfg.profiles;
    in
      mapAttrs' (
        profileName: profile: let
          mozlz4a = getExe pkgs.mozlz4a;
          jq = getExe pkgs.jq;
          sessionsFile = "${profilePath}/${profileName}/zen-sessions.jsonlz4";

          spacesJson = toJSON (mapAttrsToList (
              _: s: {
                uuid = "{${s.id}}";
                inherit (s) name position;
                icon = s.icon;
                containerTabId =
                  if isNull s.container
                  then 0
                  else s.container;
                theme = {
                  type =
                    if isNull s.theme.type
                    then "gradient"
                    else s.theme.type;
                  gradientColors =
                    if isNull s.theme.colors
                    then []
                    else
                      (map (c: {
                          inherit (c) algorithm lightness position type;
                          c = [c.red c.green c.blue];
                          isCustom = c.custom;
                          isPrimary = c.primary;
                        })
                        s.theme.colors);
                  opacity =
                    if isNull s.theme.opacity
                    then 0.5
                    else s.theme.opacity;
                  rotation = s.theme.rotation;
                  texture =
                    if isNull s.theme.texture
                    then 0
                    else s.theme.texture;
                };
                hasCollapsedPinnedTabs = false;
              }
            )
            profile.spaces);

          pinsJson = toJSON (mapAttrsToList (
              _: p:
                {
                  pinned = true;
                  hidden = false;
                  zenWorkspace =
                    if isNull p.workspace
                    then null
                    else "{${p.workspace}}";
                  zenSyncId = "{${p.id}}";
                  zenEssential = p.isEssential;
                  zenDefaultUserContextId = "true";
                  zenPinnedIcon = null;
                  zenIsEmpty = false;
                  zenHasStaticIcon = false;
                  zenGlanceId = null;
                  zenIsGlance = false;
                  searchMode = null;
                  userContextId =
                    if isNull p.container
                    then 0
                    else p.container;
                  attributes = {};
                  index = p.position;
                  lastAccessed = 0;
                }
                // optionalAttrs (!isNull p.url) {
                  entries = [
                    {
                      url = p.url;
                      title = p.title;
                      charset = "UTF-8";
                      ID = 0;
                      persist = true;
                    }
                  ];
                }
            )
            profile.pins);

          spacesJsonFile = pkgs.writeText "zen-declared-spaces-${profileName}.json" spacesJson;
          pinsJsonFile = pkgs.writeText "zen-declared-pins-${profileName}.json" pinsJson;

          jqFilterFile = pkgs.writeText "zen-sessions-filter-${profileName}.jq" ''
            ($declaredSpaces[0]) as $spaces |
            ($declaredPins[0]) as $pins |

            .spaces = (.spaces // []) |
            .tabs = (.tabs // []) |

            ([$spaces[].uuid]) as $dsUuids |
            ([.spaces[].uuid]) as $esUuids |

            .spaces = [.spaces[] |
              . as $e |
              ($spaces | map(select(.uuid == $e.uuid)) | .[0] // null) as $o |
              if $o != null then ($e * $o) else . end
            ] |
            .spaces += [$spaces[] | select(.uuid as $u | $esUuids | index($u) | not)] |

            ${optionalString profile.spacesForce ".spaces = [.spaces[] | select(.uuid as $u | $dsUuids | index($u) != null)] |"}

            ([$pins[].zenSyncId]) as $dpIds |
            ([.tabs[].zenSyncId]) as $etIds |

            .tabs = [.tabs[] |
              . as $e |
              ($pins | map(select(.zenSyncId == $e.zenSyncId)) | .[0] // null) as $o |
              if $o != null then
                $e + {pinned: $o.pinned, zenEssential: $o.zenEssential, zenWorkspace: $o.zenWorkspace, userContextId: $o.userContextId, index: $o.index}
              else . end
            ] |
            .tabs += [$pins[] | select(.zenSyncId as $id | $etIds | index($id) | not)]

            ${optionalString profile.pinsForce ''
              |
              .tabs = [.tabs[] |
                if (.pinned == true or .zenEssential == true) then
                  select(.zenSyncId as $id | $dpIds | index($id) != null)
                else . end
              ]
            ''}
          '';

          updateScript = pkgs.writeShellScript "zen-sessions-update-${profileName}" ''
            SESSIONS_FILE="${sessionsFile}"
            SESSIONS_TMP="$(mktemp)"
            SESSIONS_MODIFIED="$(mktemp)"
            BACKUP_FILE="''${SESSIONS_FILE}.backup"

            cleanup() {
              rm -f "$SESSIONS_TMP" "$SESSIONS_MODIFIED"
            }

            restore_and_cleanup() {
              if [ -f "$BACKUP_FILE" ]; then
                mv "$BACKUP_FILE" "$SESSIONS_FILE"
              fi
              cleanup
            }

            trap cleanup EXIT

            if [ ! -f "$SESSIONS_FILE" ]; then
              echo "zen-sessions: Sessions file not found at $SESSIONS_FILE"
              echo "zen-sessions: Zen Browser will create it on first run"
              exit 0
            fi

            if pgrep "zen" > /dev/null 2>&1; then
              echo "zen-sessions: Zen Browser appears to be running."
              echo "zen-sessions: Close Zen Browser and rebuild to apply spaces/pins changes."
              exit 1
            fi

            cp "$SESSIONS_FILE" "$BACKUP_FILE" || {
              echo "zen-sessions: Failed to create backup of $SESSIONS_FILE"
              exit 1
            }

            ${mozlz4a} -d "$SESSIONS_FILE" "$SESSIONS_TMP" || {
              echo "zen-sessions: Failed to decompress $SESSIONS_FILE"
              restore_and_cleanup
              exit 1
            }

            ${jq} \
              --slurpfile declaredSpaces ${spacesJsonFile} \
              --slurpfile declaredPins ${pinsJsonFile} \
              -f ${jqFilterFile} \
              "$SESSIONS_TMP" > "$SESSIONS_MODIFIED" || {
              echo "zen-sessions: Failed to apply modifications to sessions data"
              restore_and_cleanup
              exit 1
            }

            if [ ! -s "$SESSIONS_MODIFIED" ]; then
              echo "zen-sessions: Modified sessions file is empty, restoring backup"
              restore_and_cleanup
              exit 1
            fi

            ${mozlz4a} "$SESSIONS_MODIFIED" "$SESSIONS_FILE" || {
              echo "zen-sessions: Failed to recompress sessions file"
              restore_and_cleanup
              exit 1
            }

            rm -f "$BACKUP_FILE"
          '';
        in
          nameValuePair "zen-sessions-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"] ''
            ${updateScript}
            if [[ "$?" -eq 0 ]]; then
              $VERBOSE_ECHO "zen-sessions: Updated spaces/pins for profile '${profileName}'"
            else
              YELLOW="\033[1;33m"
              NC="\033[0m"
              echo -e "zen-sessions:''${YELLOW} Failed to update zen-sessions.jsonlz4 for Zen browser \"${profileName}\" profile.''${NC}"
              echo -e "zen-sessions:''${YELLOW} If Zen Browser was open, close it and rebuild to apply changes.''${NC}"
            fi
          '')
      )
      profilesWithPlaces;
  };
}
