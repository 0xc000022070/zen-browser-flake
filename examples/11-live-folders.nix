# Live folders setup (RSS / GitHub issues / PRs)
#
# Zen keeps two pieces of state:
#   ~/.config/zen/<profile>/zen-live-folders.jsonlz4   — provider config + dismissedItems + tabsState
#   ~/.config/zen/<profile>/zen-sessions.jsonlz4      — sidebar folder row (isLiveFolder, id, title, index, …)
#
# Workflow:
#   1. Import this flake home module and set ``programs.zen-browser.profiles.<profile>.liveFolders``.
#   2. Keep ``settings."zen.window-sync.enabled" = true`` so Zen applies sidebar ``folders[]`` on startup.
#   3. ``home-manager switch`` / rebuild with Zen closed.
#
# Ids: omit ``id`` — the module generates a stable ``<digits>-<digits>`` id (Zen-shaped). Set ``id`` only to
# adopt an existing folder from your profile (exact string from a session dump).
#
# Workspace: with several Zen spaces, set ``workspace`` per live folder (bare UUID = ``spaces.<name>.id``), or the
# folder row has no ``workspaceId`` and Zen may not show it. With exactly one ``spaces`` entry, null uses that space.
#
# Notes:
#   - If ``zen-sessions.jsonlz4`` did not exist yet, the module creates a minimal stub before merge so both files stay aligned.
#   - Sidebar strip below the separator lists normal *tabs* (including pages opened from a live folder).
#   - Use ``workspace`` when the folder belongs to a Zen space (bare UUID as in ``spaces.*.id``).
#   - Undeclared live-folder ids on disk are kept unless ``liveFoldersForce = true``.
{
  programs.zen-browser.profiles.default = {
    settings = {
      "zen.window-sync.enabled" = true;
    };

    liveFolders = {
      "Prisma blog" = {
        kind = "rss";
        title = "Prisma blog";
        feedUrl = "https://www.prisma.io/blog/rss.xml";
        position = 10;
        maxItems = 5;
        timeRange = 0;
      };

      "GitHub PRs" = {
        kind = "github-pull-requests";
        title = "Pull requests";
        position = 11;
        repos = [];
        githubOptions = {
          assignedMe = true;
          authorMe = false;
          reviewRequested = false;
          repoExcludes = [];
        };
      };
    };
  };
}
