# Bookmark organization with toolbar bookmarks
{
  programs.zen-browser.profiles.default.bookmarks = {
    force = true; # Rewrite bookmarks on each rebuild (overwrite browser changes)
    settings = [
      {
        name = "Nix Sites";
        toolbar = true;
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
