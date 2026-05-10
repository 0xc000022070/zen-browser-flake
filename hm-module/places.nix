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
              imports = [./live-folders/options.nix];
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
                  description = ''
                    When true, apply `pinsForceAction` to pinned or essential tabs whose
                    `zenSyncId` is not declared in `pins`. When false, those tabs are left unchanged.
                  '';
                  default = false;
                };
                pinsForceAction = mkOption {
                  type = enum [
                    "remove"
                    "demote"
                  ];
                  default = "demote";
                  description = ''
                    Used only if `pinsForce` is true.

                    - `remove`: delete undeclared pinned or essential tabs from the session.
                    - `demote`: clear pin/essential state and pin-folder membership for **non-folder**
                      orphan pinned tabs (`groupId` null or still listed in declared ``folders``), then
                      place those at the top of the normal strip (after declared pins). Pinned tabs whose
                      ``groupId`` is **not** any declared folder id (removed pin group or live folder)
                      are **dropped** from the session instead of becoming normal tabs.
                  '';
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
                            type = nullOr (either str path);
                            description = ''
                              Folder icon only when `isGroup = true` (sessions `userIcon`). Emoji, `chrome://…`, or path (`file://…`).
                              Normal pinned tabs: no declarative icon — set in Zen for now; workspaces use `spaces.*.icon`.
                            '';
                            apply = v:
                              if isPath v
                              then "file://${v}"
                              else v;
                            default = null;
                          };
                          icon = mkOption {
                            type = nullOr (either str path);
                            visible = false;
                            description = ''
                              Ignored on pins (warning if set). Tab icons: configure in Zen for now. Folders: `folderIcon`.
                            '';
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
        (_: profile:
          profile.spaces
          != {}
          || profile.spacesForce
          || profile.pins != {}
          || profile.pinsForce
          || profile.liveFolders != {}
          || profile.liveFoldersForce)
        cfg.profiles;
    in
      mapAttrs' (
        profileName: profile: let
          zenLf = import ./live-folders/artifacts.nix {
            inherit lib pkgs profile profileName optionalString profilePath;
          };
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

          pinsJson = toJSON (
            let
              nonGroupPins = filterAttrs (_: p: !p.isGroup) profile.pins;
            in
              mapAttrsToList (
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
                    groupId =
                      if p.isGroup || p.folderParentId != null
                      then
                        if p.isGroup
                        then "{${p.id}}"
                        else "{${p.folderParentId}}"
                      else null;
                  }
                  // optionalAttrs p.editedTitle {
                    zenStaticLabel = p.title;
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
              nonGroupPins
          );

          foldersJson = toJSON (
            let
              groupPins = filterAttrs (_: p: p.isGroup) profile.pins;
              folderData =
                mapAttrsToList (_: p: {
                  id = "{${p.id}}";
                  name = p.title;
                  parentId =
                    if p.folderParentId == null
                    then null
                    else "{${p.folderParentId}}";
                  workspaceId =
                    if p.workspace == null
                    then null
                    else "{${p.workspace}}";
                  collapsed = p.isFolderCollapsed or false;
                  icon = p.folderIcon;
                  index = p.position;
                })
                groupPins;
              pinFolderRows =
                map (f: {
                  pinned = true;
                  essential = false;
                  splitViewGroup = false;
                  id = f.id;
                  name = f.name;
                  collapsed = f.collapsed;
                  saveOnWindowClose = true;
                  parentId = f.parentId;
                  prevSiblingInfo = {
                    type = "start";
                    id = null;
                  };
                  emptyTabIds = [];
                  userIcon =
                    if f.icon == null
                    then ""
                    else f.icon;
                  workspaceId = f.workspaceId;
                  index = f.index;
                  isLiveFolder = false;
                })
                folderData;
            in
              pinFolderRows ++ zenLf.liveFolderRows
          );

          groupsJson = toJSON (
            let
              groupPins = filterAttrs (_: p: p.isGroup) profile.pins;
              folderData =
                mapAttrsToList (_: p: {
                  id = "{${p.id}}";
                  name = p.title;
                  parentId = p.folderParentId;
                  collapsed = p.isFolderCollapsed or false;
                  index = p.position;
                })
                groupPins;
              pinGroupRows =
                map (f: {
                  pinned = true;
                  splitView = false;
                  id = f.id;
                  name = f.name;
                  color = "zen-workspace-color";
                  collapsed = f.collapsed;
                  saveOnWindowClose = true;
                  index = f.index;
                })
                folderData;
            in
              pinGroupRows ++ zenLf.liveFolderGroupRows
          );

          spacesJsonFile = pkgs.writeText "zen-declared-spaces-${profileName}.json" spacesJson;
          pinsJsonFile = pkgs.writeText "zen-declared-pins-${profileName}.json" pinsJson;
          foldersJsonFile = pkgs.writeText "zen-declared-folders-${profileName}.json" foldersJson;
          groupsJsonFile = pkgs.writeText "zen-declared-groups-${profileName}.json" groupsJson;
          liveFolderTabsJsonFile =
            pkgs.writeText "zen-declared-live-folder-tabs-${profileName}.json" zenLf.liveFolderPlaceholderTabsJson;

          jqFilterFile = pkgs.writeText "zen-sessions-filter-${profileName}.jq" ''
            ($declaredSpaces[0]) as $spaces |
            ($declaredPins[0]) as $pins |
            ($declaredFolders[0]) as $folders |
            ($declaredGroups[0]) as $groups |
            ($declaredLiveFolderTabs[0]) as $lftabs |
            ([$lftabs[].zenSyncId]) as $lfTabIds |

            .spaces = (.spaces // []) |
            .tabs = (.tabs // []) |
            .folders = (.folders // []) |
            .groups = (.groups // []) |

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
                $e * {pinned: $o.pinned, zenEssential: $o.zenEssential, zenWorkspace: $o.zenWorkspace, userContextId: $o.userContextId, index: $o.index, entries: $o.entries, groupId: $o.groupId, zenStaticLabel: $o.zenStaticLabel}
              else . end
            ] |
            .tabs += [$pins[] | select(.zenSyncId as $id | $etIds | index($id) | not)] |

            .tabs = [.tabs[] |
              . as $e |
              ($lftabs | map(select(.zenSyncId == $e.zenSyncId)) | .[0] // null) as $o |
              if $o != null then ($e * $o) else . end
            ] |
            .tabs += [$lftabs[] | select(.zenSyncId as $id | $etIds | index($id) | not)]

            ${optionalString (profile.pinsForce && profile.pinsForceAction == "remove") ''
              | .tabs = [.tabs[] |
                if (.pinned == true or .zenEssential == true) then
                  select(.zenSyncId as $id | ($dpIds + $lfTabIds) | index($id) != null)
                else . end
              ]
            ''}
            ${optionalString (profile.pinsForce && profile.pinsForceAction == "demote") ''
              | .tabs = (
                  .tabs as $allTabsIn |
                  ([$folders[].id]) as $managedFolderIds |
                  ($allTabsIn | to_entries) as $ent |
                  ($ent | group_by(.value.zenWorkspace // "") | map(sort_by(.key))
                  | map(
                      . as $ws |
                      ($ws | map(select((.value.pinned == true or .value.zenEssential == true) and (.value.zenSyncId as $id | ($dpIds + $lfTabIds) | index($id) != null)))) as $declaredEnt |
                      ($ws | map(select((.value.pinned == true or .value.zenEssential == true) and (.value.zenSyncId as $id | ($dpIds + $lfTabIds) | index($id) == null)))) as $orphanPinnedAll |
                      ($orphanPinnedAll | map(select((.value.groupId == null) or (.value.groupId as $g | $managedFolderIds | index($g) != null)))) as $orphanEnt |
                      ($ws | map(select((.value.pinned != true) and (.value.zenEssential != true)))) as $normalEnt |
                      (($declaredEnt | sort_by(.value.index // 0)) | map(.value)) as $decl |
                      (($orphanEnt | sort_by(.key)) | map(.value | . * {pinned: false, zenEssential: false, groupId: null})) as $dem |
                      (($normalEnt | sort_by(.key)) | map(.value)) as $norm |
                      $decl + $dem + $norm
                    )
                  | flatten
                )
              )
              | .tabs = [.tabs | to_entries[] | .value * {index: .key}]
            ''} |

            ([$folders[].id]) as $dfIds |
            ([.folders[].id]) as $efIds |

            .folders = [.folders[] |
              . as $e |
              ($folders | map(select(.id == $e.id)) | .[0] // null) as $o |
              if $o != null then ($e * $o) else . end
            ] |
            .folders += [$folders[] | select(.id as $id | $efIds | index($id) | not)] |

            ([$groups[].id]) as $dgIds |
            ([.groups[].id]) as $egIds |

            .groups = [.groups[] |
              . as $e |
              ($groups | map(select(.id == $e.id)) | .[0] // null) as $o |
              if $o != null then ($e * $o) else . end
            ] |
            .groups += [$groups[] | select(.id as $id | $egIds | index($id) | not)] |

            ${optionalString (!(profile.pinsForce && profile.pinsForceAction == "demote")) ''
              .tabs = (.tabs | sort_by(.index // 0)) |
            ''}
            ${zenLf.jqZenSessionsLiveFoldersForce}
            .folders = [.folders | sort_by(.index // 0) | to_entries[] | .value * {index: .key}] |
            .groups = [.groups | sort_by(.index // 0) | to_entries[] | .value * {index: .key}]
          '';

          updateScript =
            pkgs.writeShellScript "zen-sessions-update-${profileName}"
            ''
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

              if pgrep "zen" > /dev/null 2>&1; then
                echo "zen-sessions: Zen Browser appears to be running."
                echo "zen-sessions: Close Zen Browser and rebuild to apply spaces/pins/live-folders changes."
                exit 1
              fi

              mkdir -p "$(dirname "$SESSIONS_FILE")"

              if [ ! -f "$SESSIONS_FILE" ]; then
                echo "zen-sessions: No zen-sessions.jsonlz4 yet — writing minimal stub so declarative merge runs."
                echo "zen-sessions: (Otherwise zen-live-folders could be written without matching folders[] rows; Zen clears that file on startup.)"
                printf '%s' '{"spaces":[],"tabs":[],"folders":[],"groups":[],"lastCollected":0,"splitViewData":[]}' > "$SESSIONS_TMP"
                ${mozlz4a} "$SESSIONS_TMP" "$SESSIONS_FILE" || {
                  echo "zen-sessions: Failed to compress minimal sessions stub"
                  rm -f "$SESSIONS_FILE"
                  exit 1
                }
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
                --slurpfile declaredFolders ${foldersJsonFile} \
                --slurpfile declaredGroups ${groupsJsonFile} \
                --slurpfile declaredLiveFolderTabs ${liveFolderTabsJsonFile} \
                ${optionalString profile.liveFoldersForce "--slurpfile declaredLiveFolderIds ${zenLf.liveFoldersIdsFile}"} \
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

              ${optionalString zenLf.runLiveFoldersUpdate ''
                (
                  set -e
                  LIVE_FILE="${zenLf.liveFoldersFile}"
                  LIVE_TMP="$(mktemp)"
                  LIVE_MOD="$(mktemp)"
                  LIVE_BACK="''${LIVE_FILE}.backup"
                  trap 'rm -f "$LIVE_TMP" "$LIVE_MOD"' EXIT

                  if [ -f "$LIVE_FILE" ]; then
                    cp "$LIVE_FILE" "$LIVE_BACK" || {
                      echo "zen-live-folders: Failed to create backup of $LIVE_FILE"
                      exit 1
                    }
                    ${mozlz4a} -d "$LIVE_FILE" "$LIVE_TMP" || {
                      echo "zen-live-folders: Failed to decompress $LIVE_FILE"
                      mv "$LIVE_BACK" "$LIVE_FILE"
                      exit 1
                    }
                  else
                    echo "[]" > "$LIVE_TMP"
                  fi

                  ${jq} \
                    --slurpfile declaredLiveFolders ${zenLf.liveFoldersDeclaredJsonFile} \
                    -f ${zenLf.liveFoldersJqFilterFile} \
                    "$LIVE_TMP" > "$LIVE_MOD" || {
                    echo "zen-live-folders: Failed to merge live folder state"
                    if [ -f "$LIVE_BACK" ]; then
                      mv "$LIVE_BACK" "$LIVE_FILE"
                    fi
                    exit 1
                  }

                  if [ ! -s "$LIVE_MOD" ]; then
                    echo "zen-live-folders: Modified live folders file is empty, restoring backup"
                    if [ -f "$LIVE_BACK" ]; then
                      mv "$LIVE_BACK" "$LIVE_FILE"
                    fi
                    exit 1
                  fi

                  ${mozlz4a} "$LIVE_MOD" "$LIVE_FILE" || {
                    echo "zen-live-folders: Failed to recompress $LIVE_FILE"
                    if [ -f "$LIVE_BACK" ]; then
                      mv "$LIVE_BACK" "$LIVE_FILE"
                    fi
                    exit 1
                  }

                  rm -f "$LIVE_BACK"
                )
              ''}
            '';
        in
          nameValuePair "zen-sessions-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"]
            ''
              ${updateScript}
              if [[ "$?" -eq 0 ]]; then
                $VERBOSE_ECHO "zen-sessions: Updated zen session files for profile '${profileName}'"
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
