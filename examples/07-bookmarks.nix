# Bookmark organization with toolbar bookmarks
#
# `toolbar = true` marks a directory AS the bookmarks toolbar (its name is
# discarded), it does not put that directory inside the toolbar. To get a
# folder on the toolbar, nest it inside the toolbar directory.
# Directories without `toolbar` land in the bookmarks menu.
{
  programs.zen-browser.profiles.default.bookmarks = {
    force = true; # Rewrite bookmarks on each rebuild (overwrite browser changes)
    settings = [
      {
        name = "Bookmarks Toolbar";
        toolbar = true;
        bookmarks = [
          {
            name = "Nix Sites";
            bookmarks = [
              {
                name = "homepage";
                url = "https://nixos.org/";
              }
              {
                name = "wiki";
                tags = ["wiki" "nix"];
                url = "https://wiki.nixos.org/";
              }
              {
                name = "packages";
                url = "https://search.nixos.org/packages";
              }
            ];
          }
        ];
      }
      {
        name = "Development";
        bookmarks = [
          {
            name = "GitHub";
            url = "https://github.com";
          }
        ];
      }
    ];
  };
}
