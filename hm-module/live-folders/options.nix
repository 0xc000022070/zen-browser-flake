# Options fragment: imported into `programs.zen-browser.profiles` submodule (`places.nix`).
{lib, ...}: let
  inherit (lib) mkOption;
  inherit (lib.types) attrsOf bool either enum listOf nullOr path str submodule;
  inherit (lib.types.ints) unsigned;
in {
  options = {
    liveFolders = mkOption {
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
                type = nullOr str;
                default = null;
                description = ''
                  Omit for a deterministic id in Zen’s usual shape (digits-digits, same style as
                  ``Date.now()`` + suffix). Derived from profile name, attribute key, and folder fields —
                  changing those changes the id (new session rows vs previous Zen state).
                  Set only to adopt an existing folder from disk (exact string) or pin an explicit id.
                '';
              };
              kind = mkOption {
                type = enum [
                  "rss"
                  "github-pull-requests"
                  "github-issues"
                ];
                description = ''
                  Live folder provider: RSS/Atom feed, GitHub pull requests, or GitHub issues.
                '';
              };
              workspace = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Which Zen space owns this folder (bare UUID, same string as ``spaces.*.id``).
                  Required for the folder to show in that space’s sidebar when you use multiple spaces.
                  If you declare exactly one ``spaces`` entry, null attaches live folders to that space automatically.
                  Otherwise set this (copy from ``jq '.spaces[].uuid'`` on decompressed ``zen-sessions.jsonlz4``, strip braces).
                  Encoded as ``'{uuid}'`` in the session file like pin folders.
                '';
              };
              position = mkOption {
                type = unsigned;
                default = 1000;
                description = "Sort position in the folders list.";
              };
              collapsed = mkOption {
                type = bool;
                default = true;
                description = "Whether the folder starts collapsed.";
              };
              folderIcon = mkOption {
                type = nullOr (either str path);
                description = "Optional folder icon (`userIcon`); emoji, `chrome://…`, or path.";
                apply = v:
                  if builtins.isPath v
                  then "file://${v}"
                  else v;
                default = null;
              };
              folderParentId = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Optional parent folder id (bare string as in Zen); encoded as ``'{id}'`` on disk like group folders.
                '';
              };
              feedUrl = mkOption {
                type = nullOr str;
                default = null;
                description = "RSS or Atom feed URL; required when `kind = \"rss\"`.";
              };
              maxItems = mkOption {
                type = unsigned;
                default = 10;
                description = "RSS: max items to show.";
              };
              timeRange = mkOption {
                type = unsigned;
                default = 0;
                description = "RSS: only items newer than this many milliseconds; 0 keeps all.";
              };
              repos = mkOption {
                type = listOf str;
                default = [];
                description = "GitHub: repository filter list (`owner/repo`).";
              };
              githubOptions = mkOption {
                type = submodule {
                  options = {
                    authorMe = mkOption {
                      type = bool;
                      default = false;
                    };
                    assignedMe = mkOption {
                      type = bool;
                      default = true;
                    };
                    reviewRequested = mkOption {
                      type = bool;
                      default = false;
                    };
                    repoExcludes = mkOption {
                      type = listOf str;
                      default = [];
                      description = "Repositories excluded from the GitHub query.";
                    };
                  };
                };
                default = {};
                description = "GitHub live folder filter toggles (ignored for RSS).";
              };
            };
          }
        )
      );
      default = {};
      description = ''
        Declarative Zen live folders (RSS, GitHub issues/PRs). Writes matching
        folder rows into zen-sessions.jsonlz4 and merges provider entries into
        zen-live-folders.jsonlz4 (undeclared ids are kept; declared ids merge provider
        ``data.state`` over existing rows while preserving ``lastFetched``, ``lastErrorId``,
        ``dismissedItems``, and ``tabsState``). Close Zen before rebuild.
        Keep ``zen.window-sync.enabled`` true in profile settings; if startup cannot attach session ``folders[]``
        to the window, Zen clears ``zen-live-folders.jsonlz4`` on save. Use ids copied from Zen session files
        (Zen generates ids like ``Timestamp-N``, not arbitrary UUIDs).
      '';
    };
    liveFoldersForce = mkOption {
      type = bool;
      default = false;
      description = ''
        When true, remove live-folder entries not declared in ``liveFolders``: rows in
        ``zen-live-folders.jsonlz4`` and ``folders`` entries with ``isLiveFolder == true``
        in ``zen-sessions.jsonlz4`` whose ids are absent from ``liveFolders``. No demotion;
        rows are dropped. When false, undeclared live folders on disk are preserved (merge only).
      '';
    };
  };
}
