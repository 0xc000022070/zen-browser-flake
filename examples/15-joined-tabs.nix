# Joined tabs create Zen split-view groups.
# Use the stable tab IDs from declared pins.
{
  programs.zen-browser.profiles.default = let
    pins = {
      "Docs" = {
        id = "a4b044aa-ec6e-4a0a-81bd-cf59c90ad0b7";
        url = "https://docs.zen-browser.app";
        position = 100;
      };
      "Issues" = {
        id = "eb41c041-f720-4702-a955-c163ef040e25";
        url = "https://github.com/zen-browser/desktop/issues";
        position = 101;
      };
    };
  in {
    inherit pins;

    joinedTabs."Docs and issues" = {
      id = "docs-issues-split";
      gridType = "vsep";
      tabs = [
        pins."Docs".id
        pins."Issues".id
      ];
    };
  };
}
