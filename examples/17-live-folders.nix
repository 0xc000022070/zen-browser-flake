# Live folders: Zen fills the folder with fetched items (RSS feed or GitHub
# queries). Member tabs are browser-owned — only the container and provider
# config are declared. State lands in two files that must share the folder id:
# zen-sessions.jsonlz4 (the sidebar folder row) and zen-live-folders.jsonlz4
# (provider config). The module writes both; runtime state the browser tracks
# (lastFetched, dismissed items, discovered repos) survives re-activation.
#
# GitHub kinds reuse the browser's logged-in github.com session — no token.
# Keep "zen.window-sync.enabled" = true (the default) or Zen may drop the
# entries on restore.
{
  programs.zen-browser.profiles.default = {
    liveFolders = {
      "Prisma blog" = {
        id = "0f3f2f66-64bc-4a43-8f86-01c2a134c4f4";
        kind = "rss";
        feedUrl = "https://www.prisma.io/blog/rss.xml";
        folderIcon = "https://www.prisma.io/favicon.ico";
        position = 400;
        maxItems = 5;
        # timeRange = 86400000;   # only items from the last 24 h; 0 (default) keeps all
        # fetchInterval = 900000; # 15 min; omit to let the browser manage it
      };

      "Pull requests" = {
        id = "b7a3d5c1-9e2f-4a68-b0d4-6f1c8e5a2d93";
        kind = "github:pull-requests";
        position = 401;
        github = {
          assignedMe = true; # default
          reviewRequested = true;
          # authorMe = true;
          # repoExcludes = ["owner/noisy-repo"];
        };
      };

      "My issues" = {
        id = "3c9e1f7a-5b24-4d80-9a6c-e2f4b8d10c57";
        kind = "github:issues";
        position = 402;
        github.authorMe = true;
      };
    };
  };
}
