# Declarative Zen live folders (RSS / GitHub PRs / GitHub issues).
#
# Owns the `liveFolders` options and the zen-live-folders.jsonlz4 writer.
# The matching zen-sessions.jsonlz4 rows (folder row with isLiveFolder,
# groups row, placeholder empty tab) are produced by places.nix, which owns
# everything session-store side; both files must share the folder id.
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
                liveFolders = mkOption {
                  description = ''
                    Live folders (RSS/Atom feed, GitHub pull requests, GitHub issues). Zen fills
                    the folder with fetched items; member tabs are browser-owned and never
                    declared. Writes the folder row into `zen-sessions.jsonlz4` and merges the
                    provider entry into `zen-live-folders.jsonlz4`. Browser runtime state
                    (`lastFetched`, `dismissedItems`, `tabsState`, discovered GitHub repos) is
                    preserved on merge; undeclared live folders on disk are kept.
                  '';
                  type = attrsOf (
                    submodule (
                      {name, ...}: {
                        options = {
                          title = mkOption {
                            type = str;
                            description = "Sidebar label for the folder.";
                            default = name;
                          };
                          id = mkOption {
                            type = str;
                            description = ''
                              REQUIRED. Stable folder ID, written verbatim to both state files
                              (like `joinedTabs.*.id`). To adopt a live folder created in Zen,
                              copy its exact id from the session file.
                            '';
                          };
                          kind = mkOption {
                            type = enum [
                              "rss"
                              "github:pull-requests"
                              "github:issues"
                            ];
                            description = "Live folder provider.";
                            default = "rss";
                          };
                          workspace = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Workspace ID owning the folder (bare UUID, as in `spaces.*.id`).";
                          };
                          position = mkOption {
                            type = ints.unsigned;
                            default = 1000;
                            description = "Position of the folder.";
                          };
                          collapsed = mkOption {
                            type = bool;
                            default = true;
                            description = "Whether the folder starts collapsed.";
                          };
                          folderIcon = mkOption {
                            type = nullOr (either str path);
                            description = "Folder icon (sessions `userIcon`). Emoji, `chrome://…`, or path (`file://…`).";
                            apply = v:
                              if isPath v
                              then "file://${v}"
                              else v;
                            default = null;
                          };
                          feedUrl = mkOption {
                            type = nullOr str;
                            default = null;
                            description = "RSS or Atom feed URL. Required when `kind = \"rss\"`.";
                          };
                          maxItems = mkOption {
                            type = ints.positive;
                            default = 10;
                            description = "RSS only: maximum items shown.";
                          };
                          timeRange = mkOption {
                            type = ints.unsigned;
                            default = 0;
                            description = "RSS only: only items newer than this many milliseconds; 0 keeps all.";
                          };
                          fetchInterval = mkOption {
                            type = nullOr ints.positive;
                            default = null;
                            description = ''
                              Refetch interval in milliseconds. Null lets the browser manage it
                              (30 minutes by default; RSS feeds may tune it via their `ttl`).
                            '';
                          };
                          github = mkOption {
                            type = submodule {
                              options = {
                                authorMe = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Include items you authored.";
                                };
                                assignedMe = mkOption {
                                  type = bool;
                                  default = true;
                                  description = "Include items assigned to you.";
                                };
                                reviewRequested = mkOption {
                                  type = bool;
                                  default = false;
                                  description = "Pull requests only: include review requests.";
                                };
                                repoExcludes = mkOption {
                                  type = listOf str;
                                  default = [];
                                  description = "`owner/repo` list excluded from the query.";
                                };
                              };
                            };
                            default = {};
                            description = "GitHub kinds only; ignored for RSS.";
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
      inherit (builtins) toJSON;
      inherit (lib) filterAttrs getExe mapAttrs' mapAttrsToList nameValuePair optionalAttrs;

      profilesWithLiveFolders = filterAttrs (_: profile: profile.liveFolders != {}) cfg.profiles;
    in
      mapAttrs' (
        profileName: profile: let
          mozlz4a = getExe pkgs.mozlz4a;
          jq = getExe pkgs.jq;
          sessionsFile = "${profilePath}/${profileName}/zen-sessions.jsonlz4";
          liveFoldersFile = "${profilePath}/${profileName}/zen-live-folders.jsonlz4";

          # Only provider config is declared; the browser fills runtime defaults
          # (interval, lastFetched, options) on load.
          liveFoldersJson = toJSON (
            mapAttrsToList (
              _: lf: {
                id = lf.id;
                type =
                  if lf.kind == "rss"
                  then "rss"
                  else "github";
                dismissedItems = [];
                tabsState = [];
                data.state =
                  optionalAttrs (lf.fetchInterval != null) {
                    interval = lf.fetchInterval;
                  }
                  // (
                    if lf.kind == "rss"
                    then {
                      url = lf.feedUrl;
                      inherit (lf) maxItems timeRange;
                    }
                    else {
                      type =
                        if lf.kind == "github:pull-requests"
                        then "pull-requests"
                        else "issues";
                      options = {
                        inherit (lf.github) authorMe assignedMe reviewRequested repoExcludes;
                      };
                    }
                  );
              }
            )
            profile.liveFolders
          );

          liveFoldersJsonFile = pkgs.writeText "zen-declared-live-folders-${profileName}.json" liveFoldersJson;

          # Match by id: declared wins for provider config (type, data.state keys
          # present in the declared entry — jq * deep-merges objects), browser wins
          # for runtime state (lastFetched, lastErrorId, isJsonApi, discovered
          # repos, dismissedItems, tabsState). Unknown ids are appended untouched.
          jqFilterFile = pkgs.writeText "zen-live-folders-filter-${profileName}.jq" ''
            ($declaredLiveFolders[0]) as $decl |
            (if type == "array" then . else [] end) as $existing |
            ([$existing[].id]) as $eIds |

            [$existing[] |
              . as $e |
              ($decl | map(select(.id == $e.id)) | .[0] // null) as $o |
              if $o != null then ($e * ($o | del(.dismissedItems, .tabsState))) else . end
            ] + [$decl[] | select(.id as $id | $eIds | index($id) | not)]
          '';

          updateScript =
            pkgs.writeShellScript "zen-live-folders-update-${profileName}"
            ''
              SESSIONS_FILE="${sessionsFile}"
              LIVE_FILE="${liveFoldersFile}"
              LIVE_TMP="$(mktemp)"
              LIVE_MODIFIED="$(mktemp)"
              BACKUP_FILE="''${LIVE_FILE}.backup"
              LOCK_FILE="''${SESSIONS_FILE%/*}/.parentlock"

              cleanup() {
                rm -f "$LIVE_TMP" "$LIVE_MODIFIED"
              }

              restore_and_cleanup() {
                if [ -f "$BACKUP_FILE" ]; then
                  mv "$BACKUP_FILE" "$LIVE_FILE"
                fi
                cleanup
              }

              trap cleanup EXIT

              if [ ! -f "$SESSIONS_FILE" ]; then
                echo "zen-live-folders: Sessions file not found; skipping (live folders need their session folder rows)"
                exit 0
              fi

              if "${lib.getExe pkgs.lsof}" "$LOCK_FILE" >/dev/null 2>&1; then
                echo "zen-live-folders: Zen Browser appears to be running."
                echo "zen-live-folders: Close Zen Browser and rebuild to apply live folder changes."
                exit 1
              fi

              if [ ! -f "$LIVE_FILE" ]; then
                ${mozlz4a} ${liveFoldersJsonFile} "$LIVE_FILE" || {
                  echo "zen-live-folders: Failed to create $LIVE_FILE"
                  exit 1
                }
                exit 0
              fi

              cp "$LIVE_FILE" "$BACKUP_FILE" || {
                echo "zen-live-folders: Failed to create backup of $LIVE_FILE"
                exit 1
              }

              ${mozlz4a} -d "$LIVE_FILE" "$LIVE_TMP" || {
                echo "zen-live-folders: Failed to decompress $LIVE_FILE"
                restore_and_cleanup
                exit 1
              }

              ${jq} \
                --slurpfile declaredLiveFolders ${liveFoldersJsonFile} \
                -f ${jqFilterFile} \
                "$LIVE_TMP" > "$LIVE_MODIFIED" || {
                echo "zen-live-folders: Failed to apply modifications to live folders data"
                restore_and_cleanup
                exit 1
              }

              if [ ! -s "$LIVE_MODIFIED" ]; then
                echo "zen-live-folders: Modified live folders file is empty, restoring backup"
                restore_and_cleanup
                exit 1
              fi

              ${mozlz4a} "$LIVE_MODIFIED" "$LIVE_FILE" || {
                echo "zen-live-folders: Failed to recompress live folders file"
                restore_and_cleanup
                exit 1
              }

              rm -f "$BACKUP_FILE"
            '';
        in
          nameValuePair "zen-live-folders-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary" "zen-sessions-${profileName}"]
            ''
              ${updateScript}
              if [[ "$?" -eq 0 ]]; then
                $VERBOSE_ECHO "zen-live-folders: Updated live folders for profile '${profileName}'"
              else
                YELLOW="\033[1;33m"
                NC="\033[0m"
                echo -e "zen-live-folders:''${YELLOW} Failed to update zen-live-folders.jsonlz4 for Zen browser \"${profileName}\" profile.''${NC}"
                echo -e "zen-live-folders:''${YELLOW} If Zen Browser was open, close it and rebuild to apply changes.''${NC}"
              fi
            '')
      )
      profilesWithLiveFolders;
  };
}
