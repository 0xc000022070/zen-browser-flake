# Live folders setup (RSS / GitHub issues / PRs)
#
# Zen keeps two pieces of state:
#   ~/.config/zen/<profile>/zen-live-folders.jsonlz4   — provider config + dismissedItems + tabsState
#   ~/.config/zen/<profile>/zen-sessions.jsonlz4      — sidebar folder row (isLiveFolder, id, title, index, …)
#
# Workflow (recommended):
#   1. In Zen: sidebar → create the live folder (RSS / GitHub PRs / GitHub issues) once.
#   2. Quit Zen completely.
#   3. Inspect ids so Nix matches Zen (mozlz4a from nixpkgs; decompress to a temp json file, then jq):
#        mozlz4a -d ~/.config/zen/default/zen-live-folders.jsonlz4 /tmp/live.json && jq '.[].id' /tmp/live.json
#        mozlz4a -d ~/.config/zen/default/zen-sessions.jsonlz4 /tmp/sess.json && jq '.folders[] | select(.isLiveFolder==true) | {id,name}' /tmp/sess.json
#      Use that exact `id` string in liveFolders below (opaque, e.g. "1778364952102-44").
#   4. Import this flake’s home module and set programs.zen-browser.profiles.<profile>.liveFolders.
#   5. home-manager switch / rebuild. Zen must stay closed during activation.
#
# Notes:
#   - Sidebar strip below the separator lists normal *tabs* (including pages opened from a live folder).
#     Only the folder row (eye icon) is `folders[]`; feed entries as tabs stay unpinned unless you pin them in Zen.
#   - Use ``workspace`` when the folder belongs to a Zen space: same bare UUID as ``programs.zen-browser.profiles.*.spaces.*``;
#     the module writes ``workspaceId`` as ``'{uuid}'`` like pin folders.
#   - Undeclared live-folder ids already on disk are kept unless liveFoldersForce = true (then removed
#     from zen-live-folders.jsonlz4 and undeclared isLiveFolder rows from zen-sessions folders).
#   - Declared ids merge over provider fields and preserve lastFetched / dismissedItems / tabsState when possible.
#   - workspace / folderParentId / folderIcon are optional; copy strings from session dumps if you use them.
#   - This is independent of pins.isGroup folders (different feature).
{
  programs.zen-browser.profiles.default = {
    liveFolders = {
      # Replace id/title/feedUrl with values from your machine (step 3 above).
      "Prisma blog" = {
        id = "1778364952102-44";
        kind = "rss";
        title = "Prisma blog";
        feedUrl = "https://www.prisma.io/blog/rss.xml";
        position = 10;
        maxItems = 5;
        timeRange = 0;
      };

      "GitHub PRs" = {
        id = "66666666-7777-8888-9999-aaaaaaaaaaaa";
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
