# Joined tabs create Zen split-view groups.
# Use the stable tab IDs from declared pins. When the member pins live in a
# nested tree (spaces.*.pins, embedded folder pins), alias the folder in a
# `let` and reference children by key — ids stay declared exactly once.
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

    spaces."Work" = {
      id = "3f2c1a9e-5d47-4b8a-9e21-c7a4d0b6f813";
      position = 1000;

      pins."Monitoring" = {
        id = "7a1e4c52-9b3d-4f06-8c2e-51d9aa047b36";
        isFolderCollapsed = true;
        position = 200;

        pins = {
          "Grafana" = {
            id = "c95327d8-4e61-4a2f-b0d3-6e8f12ab94c0";
            url = "https://grafana.example.org";
            position = 201;
          };
          "Alerts" = {
            id = "e60b8f37-2a91-4c5d-8b74-0f3ca6d1e295";
            url = "https://alerts.example.org";
            position = 202;
          };
        };
      };
    };

    monitoring = spaces."Work".pins."Monitoring";
  in {
    inherit pins spaces;

    joinedTabs."Docs and issues" = {
      id = "docs-issues-split";
      gridType = "vsep";
      tabs = [
        pins."Docs".id
        pins."Issues".id
      ];
      # Optional: explicit per-tab share (percent of parent, must sum to 100).
      # Defaults to equal-split when omitted.
      # sizes = [70 30];

      # Optional: nest the split inside a declared folder pin (isGroup = true)
      # so it renders as a folder child instead of flat pinned icons.
      # folderParentId = pins."Some folder".id;
    };

    # Split living inside an embedded folder: the `monitoring` alias above
    # reaches into the tree once; folder and member ids come from it.
    joinedTabs."Dashboards" = {
      id = "dashboards-split";
      gridType = "vsep";
      folderParentId = monitoring.id;
      tabs = [
        monitoring.pins."Grafana".id
        monitoring.pins."Alerts".id
      ];
    };
  };
}
