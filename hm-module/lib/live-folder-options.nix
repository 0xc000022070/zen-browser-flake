# Live-folder submodule shared by `liveFolders` and the space-scoped
# `spaces.*.liveFolders`. Space-scoped folders exclude `workspace`: it is
# derived from the owning space during desugaring (session/spaces.nix).
{
  lib,
  includeWorkspace ? true,
}: let
  inherit (lib) mkOption types;
in
  {name, ...}: {
    options = with types;
      {
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
            if lib.isPath v
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
      }
      // lib.optionalAttrs includeWorkspace {
        workspace = mkOption {
          type = nullOr str;
          default = null;
          description = "Workspace ID owning the folder (bare UUID, as in `spaces.*.id`).";
        };
      };
  }
