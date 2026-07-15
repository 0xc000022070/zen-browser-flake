# Writes zen-live-folders.jsonlz4 and contributes the matching
# zen-sessions.jsonlz4 rows; the two files join on the folder id.
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
  rows = import ../lib/session-rows.nix {inherit lib;};
  liveFolderModule = import ../lib/live-folder-options.nix {inherit lib;};
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
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
                  type = attrsOf (submodule liveFolderModule);
                  default = {};
                };
              };

              config = let
                inherit (lib) mapAttrsToList;
              in {
                # Live folders never have declared children (the browser owns
                # them), so every one gets a placeholder like childless group pins.
                sessionStore.tabs = mapAttrsToList (_: lf:
                  rows.mkEmptyTabRow {
                    tabId = "${lf.id}-empty";
                    groupId = lf.id;
                    inherit (lf) workspace position;
                  })
                config.liveFolders;

                sessionStore.folders =
                  mapAttrsToList (_: lf: {
                    pinned = true;
                    splitViewGroup = false;
                    id = lf.id;
                    name = lf.title;
                    collapsed = lf.collapsed;
                    saveOnWindowClose = true;
                    parentId = null;
                    prevSiblingInfo = {
                      type = "start";
                      id = null;
                    };
                    emptyTabIds = ["${lf.id}-empty"];
                    userIcon =
                      if lf.folderIcon == null
                      then ""
                      else lf.folderIcon;
                    workspaceId =
                      if lf.workspace == null
                      then null
                      else "{${lf.workspace}}";
                    index = lf.position;
                    isLiveFolder = true;
                  })
                  config.liveFolders;

                sessionStore.groups =
                  mapAttrsToList (_: lf: {
                    pinned = true;
                    splitView = false;
                    id = lf.id;
                    name = lf.title;
                    color = "zen-workspace-color";
                    collapsed = lf.collapsed;
                    saveOnWindowClose = true;
                    index = lf.position;
                  })
                  config.liveFolders;
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
          sessionsFile = "${cfg.profilesPath}/${profile.path}/zen-sessions.jsonlz4";
          liveFoldersFile = "${cfg.profilesPath}/${profile.path}/zen-live-folders.jsonlz4";

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

          updateScript = mkJsonlz4Updater {
            name = "zen-live-folders-update-${profileName}";
            logPrefix = "zen-live-folders";
            subject = "live folders";
            skipSubject = "live folder";
            stateFile = liveFoldersFile;
            lockFile = "${cfg.profilesPath}/${profile.path}/.parentlock";
            slurpfiles = {
              declaredLiveFolders = liveFoldersJsonFile;
            };
            inherit jqFilterFile;
            preChecks = ''
              if [ ! -f "${sessionsFile}" ]; then
                echo "zen-live-folders: Sessions file not found; skipping (live folders need their session folder rows)"
                exit 0
              fi
            '';
            postLockChecks = ''
              if [ ! -f "$STATE_FILE" ]; then
                ${getExe pkgs.mozlz4a} ${liveFoldersJsonFile} "$STATE_FILE" || {
                  echo "zen-live-folders: Failed to create $STATE_FILE"
                  exit 1
                }
                exit 0
              fi
            '';
          };
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
