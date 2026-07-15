# Session-store engine: the single writer of zen-sessions.jsonlz4.
#
# Producer modules (session/*.nix) contribute rows to the internal
# `sessionStore` bus options declared here; this module assembles the
# declared JSON documents and applies them with one jq upsert that
# preserves unknown fields and keeps undeclared entries (unless a force
# option prunes them).
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

  mkJsonlz4Updater = import ../lib/state-writer.nix {inherit pkgs lib;};

  mkRowsOption = collection:
    mkOption {
      type = with types; listOf raw;
      internal = true;
      visible = false;
      default = [];
      description = "Session-store rows contributed to the `${collection}` collection.";
    };
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options.sessionStore = {
                spaces = mkRowsOption "spaces";
                tabs = mkRowsOption "tabs";
                folders = mkRowsOption "folders";
                groups = mkRowsOption "groups";
                splitViewData = mkRowsOption "splitViewData";
                joinedTabIds = mkOption {
                  type = listOf str;
                  internal = true;
                  visible = false;
                  default = [];
                  description = ''
                    Wrapped ids of tabs owned by a split-view group. Tab-row producers
                    must not set a folder groupId on these ids.
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
      inherit (lib) filterAttrs mapAttrs' nameValuePair optionalString;

      profilesWithSessionData =
        filterAttrs
        (_: profile:
          profile.sessionStore.spaces
          != []
          || profile.sessionStore.tabs != []
          || profile.sessionStore.folders != []
          || profile.sessionStore.groups != []
          || profile.sessionStore.splitViewData != []
          || profile.spacesForce
          || profile.pinsForce)
        cfg.profiles;
    in
      mapAttrs' (
        profileName: profile: let
          sessionsFile = "${cfg.profilesPath}/${profile.path}/zen-sessions.jsonlz4";

          spacesJsonFile = pkgs.writeText "zen-declared-spaces-${profileName}.json" (toJSON profile.sessionStore.spaces);
          pinsJsonFile = pkgs.writeText "zen-declared-pins-${profileName}.json" (toJSON profile.sessionStore.tabs);
          foldersJsonFile = pkgs.writeText "zen-declared-folders-${profileName}.json" (toJSON profile.sessionStore.folders);
          groupsJsonFile = pkgs.writeText "zen-declared-groups-${profileName}.json" (toJSON profile.sessionStore.groups);
          joinedTabsJsonFile = pkgs.writeText "zen-declared-joined-tabs-${profileName}.json" (toJSON profile.sessionStore.splitViewData);

          jqFilterFile = pkgs.writeText "zen-sessions-filter-${profileName}.jq" ''
            ($declaredSpaces[0]) as $spaces |
            ($declaredPins[0]) as $pins |
            ($declaredFolders[0]) as $folders |
            ($declaredGroups[0]) as $groups |
            ($declaredJoinedTabs[0]) as $joinedTabs |

            .spaces = (.spaces // []) |
            .tabs = (.tabs // []) |
            .folders = (.folders // []) |
            .groups = (.groups // []) |
            .splitViewData = (.splitViewData // []) |

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
                $e * {pinned: $o.pinned, zenEssential: $o.zenEssential, zenWorkspace: $o.zenWorkspace, userContextId: $o.userContextId, index: $o.index, entries: $o.entries, groupId: $o.groupId, zenStaticLabel: $o.zenStaticLabel} * (if $o.id != null then {id: $o.id} else {} end)
              else . end
            ] |
            .tabs += [$pins[] | select(.zenSyncId as $id | $etIds | index($id) | not)]

            ${optionalString (profile.pinsForce && profile.pinsForceAction == "remove") ''
              | .tabs = [.tabs[] |
                if (.pinned == true or .zenEssential == true) then
                  select(.zenSyncId as $id | $dpIds | index($id) != null)
                else . end
              ]
            ''}
            ${optionalString (profile.pinsForce && profile.pinsForceAction == "demote") ''
              | .tabs = (
                  .tabs as $allTabsIn |
                  ($allTabsIn | to_entries) as $ent |
                  ($ent | group_by(.value.zenWorkspace // "") | map(sort_by(.key))
                  | map(
                      . as $ws |
                      ($ws | map(select((.value.pinned == true or .value.zenEssential == true) and (.value.zenSyncId as $id | $dpIds | index($id) != null)))) as $declaredEnt |
                      ($ws | map(select((.value.pinned == true or .value.zenEssential == true) and (.value.zenSyncId as $id | $dpIds | index($id) == null)))) as $orphanEnt |
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
              if $o != null then (($e * $o) | if $o.splitView == true then del(.index) else . end) else . end
            ] |
            .groups += [$groups[] | select(.id as $id | $egIds | index($id) | not)] |

            ([$joinedTabs[].groupId]) as $djIds |
            ([.splitViewData[].groupId]) as $ejIds |

            .splitViewData = [.splitViewData[] |
              . as $e |
              ($joinedTabs | map(select(.groupId == $e.groupId)) | .[0] // null) as $o |
              if $o != null then ($e * $o) else . end
            ] |
            .splitViewData += [$joinedTabs[] | select(.groupId as $id | $ejIds | index($id) | not)] |
            .tabs = [.tabs[] |
              . as $tab |
              ($joinedTabs | map(select(.tabs | index($tab.id // $tab.zenSyncId // ""))) | .[0] // null) as $joinedTab |
              if $joinedTab != null then ($tab * {groupId: $joinedTab.groupId}) else . end
            ] |

            ${optionalString (!(profile.pinsForce && profile.pinsForceAction == "demote")) ''
              .tabs = (.tabs | sort_by(.index // 0)) |
            ''}
            .folders = (.folders | sort_by(.index // 0)) |
            .groups = (.groups | sort_by(.index // 0))
          '';

          updateScript = mkJsonlz4Updater {
            name = "zen-sessions-update-${profileName}";
            logPrefix = "zen-sessions";
            subject = "sessions";
            skipSubject = "spaces/pins";
            stateFile = sessionsFile;
            lockFile = "${cfg.profilesPath}/${profile.path}/.parentlock";
            slurpfiles = {
              declaredSpaces = spacesJsonFile;
              declaredPins = pinsJsonFile;
              declaredFolders = foldersJsonFile;
              declaredGroups = groupsJsonFile;
              declaredJoinedTabs = joinedTabsJsonFile;
            };
            inherit jqFilterFile;
            preChecks = ''
              if [ ! -f "$STATE_FILE" ]; then
                echo "zen-sessions: Sessions file not found at $STATE_FILE"
                echo "zen-sessions: Zen Browser will create it on first run"
                exit 0
              fi
            '';
          };
        in
          nameValuePair "zen-sessions-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"]
            ''
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
      profilesWithSessionData;
  };
}
