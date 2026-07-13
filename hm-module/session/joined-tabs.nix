# Publishes `sessionStore.joinedTabIds`; the pins producer reads it to
# keep folder groupId off tabs owned by a split group.
{lib, ...}: let
  inherit (lib) mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  rows = import ../lib/session-rows.nix {inherit lib;};
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                joinedTabs = mkOption {
                  description = ''
                    Split-view groups (two or three tabs per group). Pin IDs listed in any `tabs` array
                    are written to the session without folder `groupId` (even if those pins use
                    `folderParentId`) so the split-view `groupId` can apply; the folder row still exists if
                    declared. Zen does not represent the same tab as both a folder child and a joined split.
                  '';
                  type = attrsOf (
                    submodule (
                      {name, ...}: {
                        options = {
                          name = mkOption {
                            type = str;
                            description = "Joined tab group name shown in Zen (empty string is valid).";
                            default = "";
                          };
                          id = mkOption {
                            type = str;
                            description = "Stable split-view group ID.";
                            default = name;
                          };
                          gridType = mkOption {
                            type = enum [
                              "vsep"
                              "hsep"
                            ];
                            description = "Zen split-view grid type.";
                            default = "vsep";
                          };
                          tabs = mkOption {
                            type = listOf str;
                            description = ''
                              Ordered pin UUIDs in this group (two or three pins). Each tab must still be
                              a declared pin; folder membership is not applied in the session for these
                              IDs.
                            '';
                            default = [];
                          };
                          sizes = mkOption {
                            type = listOf ints.positive;
                            description = ''
                              Optional per-tab share of the split, in percent. When set, must have the
                              same length as `tabs` and sum to 100. When empty (default), tabs are split
                              equally.
                            '';
                            default = [];
                            example = [70 30];
                          };
                          folderParentId = mkOption {
                            type = nullOr str;
                            description = ''
                              Pin UUID of a declared folder pin (`isGroup = true`). When set, the split
                              group gets a `splitViewGroup` folder entry in the session store, so Zen
                              nests it inside that folder and renders it as a folder child. Without it,
                              the joined tabs render flat in the pinned section (Zen only nests entries
                              present in the session `folders` array).
                            '';
                            default = null;
                          };
                        };
                      }
                    )
                  );
                  default = {};
                };
              };

              config = let
                inherit (lib) filterAttrs flatten mapAttrsToList zipListsWith;
              in {
                sessionStore.joinedTabIds =
                  flatten (mapAttrsToList (_: g: map rows.wrapTabId g.tabs) config.joinedTabs);

                sessionStore.folders =
                  mapAttrsToList (_: g: {
                    pinned = true;
                    splitViewGroup = true;
                    id = g.id;
                    name = g.name;
                    collapsed = false;
                    saveOnWindowClose = true;
                    parentId = "{${g.folderParentId}}";
                    prevSiblingInfo = {
                      type = "start";
                      id = null;
                    };
                    emptyTabIds = [];
                    workspaceId = null;
                  })
                  (filterAttrs (_: g: g.folderParentId != null) config.joinedTabs);

                sessionStore.groups =
                  mapAttrsToList (_: g: {
                    pinned = true;
                    essential = false;
                    splitView = true;
                    id = g.id;
                    name = g.name;
                    color = "blue";
                    collapsed = false;
                    saveOnWindowClose = true;
                  })
                  config.joinedTabs;

                sessionStore.splitViewData =
                  mapAttrsToList (
                    _: g: let
                      tabs = map rows.wrapTabId g.tabs;
                      direction =
                        if g.gridType == "hsep"
                        then "column"
                        else "row";
                      equalSize =
                        if tabs == []
                        then 100
                        else 100.0 / (builtins.length tabs);
                      sizes =
                        if g.sizes == []
                        then map (_: equalSize) tabs
                        else g.sizes;
                    in {
                      groupId = g.id;
                      inherit (g) gridType;
                      inherit tabs;
                      layoutTree = {
                        type = "splitter";
                        inherit direction;
                        children =
                          zipListsWith (tabId: sizeInParent: {
                            type = "leaf";
                            inherit tabId sizeInParent;
                          })
                          tabs
                          sizes;
                      };
                    }
                  )
                  config.joinedTabs;
              };
            }
          )
        );
    };
  };
}
