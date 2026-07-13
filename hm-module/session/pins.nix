{lib, ...}: let
  inherit (lib) mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  pinModule = import ../lib/pin-options.nix {inherit lib;};
  resolvePins = import ../lib/resolve-pins.nix {inherit lib;};
  rows = import ../lib/session-rows.nix {inherit lib;};
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                pinsForce = mkOption {
                  type = bool;
                  description = ''
                    When true, apply `pinsForceAction` to pinned or essential tabs whose
                    `zenSyncId` is not declared in `pins`. When false, those tabs are left unchanged.
                  '';
                  default = false;
                };
                pinsForceAction = mkOption {
                  type = enum [
                    "remove"
                    "demote"
                  ];
                  default = "demote";
                  description = ''
                    Used only if `pinsForce` is true.

                    - `remove`: delete undeclared pinned or essential tabs from the session.
                    - `demote`: clear pin/essential state and pin-folder membership, then place those
                      tabs at the top of the normal strip (after declared pins), preserving their
                      previous relative order. Tab `index` fields are rewritten to match this order so
                      Zen does not reorder by stale indices.
                  '';
                };
                pins = mkOption {
                  type = attrsOf (submodule pinModule);
                  default = {};
                };
                pinsResolved = mkOption {
                  type = lazyAttrsOf raw;
                  internal = true;
                  readOnly = true;
                  description = ''
                    Flat view of `pins` with nested child pins (`pins.*.pins`) resolved:
                    `folderParentId` and `workspace` inherited from the owning folder pin,
                    `isGroup` implied by children. Consumers read this, never `pins`.
                  '';
                };
              };

              config = let
                inherit (builtins) elem isNull;
                inherit (lib) any attrValues filterAttrs mapAttrsToList optionalAttrs;

                joinedTabIds = config.sessionStore.joinedTabIds;

                nonGroupPins = filterAttrs (_: p: !p.isGroup) config.pinsResolved;
                groupPins = filterAttrs (_: p: p.isGroup) config.pinsResolved;

                # A pin owned by a split group carries the group's groupId, not the
                # folder's, so it doesn't keep the folder alive on restore — such
                # folders count as childless (see mkEmptyTabRow in lib/session-rows.nix).
                folderHasDirectChild = fp:
                  any (
                    p:
                      !p.isGroup
                      && p.folderParentId == fp.id
                      && !(elem "{${p.id}}" joinedTabIds)
                  ) (attrValues config.pinsResolved);

                childlessGroupPins = filterAttrs (_: p: p.isGroup && !(folderHasDirectChild p)) config.pinsResolved;
                maxSubfolders = (config.settings or {})."zen.folders.max-subfolders" or 5;
              in {
                pinsResolved = resolvePins maxSubfolders config.pins;

                sessionStore.tabs =
                  mapAttrsToList (_: fp:
                    rows.mkEmptyTabRow {
                      tabId = "{${fp.id}}-empty";
                      groupId = "{${fp.id}}";
                      inherit (fp) workspace position;
                    })
                  childlessGroupPins
                  ++ mapAttrsToList (
                    _: p:
                      {
                        pinned = true;
                        hidden = false;
                        zenWorkspace =
                          if isNull p.workspace
                          then null
                          else "{${p.workspace}}";
                        zenSyncId = "{${p.id}}";
                        zenEssential = p.isEssential;
                        zenDefaultUserContextId = "true";
                        zenPinnedIcon = null;
                        zenIsEmpty = false;
                        zenHasStaticIcon = false;
                        zenGlanceId = null;
                        zenIsGlance = false;
                        searchMode = null;
                        userContextId =
                          if isNull p.container
                          then 0
                          else p.container;
                        attributes = {};
                        index = p.position;
                        lastAccessed = 0;
                        groupId =
                          if elem "{${p.id}}" joinedTabIds
                          then null
                          else if p.folderParentId != null
                          then "{${p.folderParentId}}"
                          else null;
                      }
                      // optionalAttrs (elem "{${p.id}}" joinedTabIds) {
                        id = "{${p.id}}";
                      }
                      // optionalAttrs p.editedTitle {
                        zenStaticLabel = p.title;
                      }
                      // optionalAttrs (!isNull p.url) {
                        entries = [
                          {
                            url = p.url;
                            title = p.title;
                            charset = "UTF-8";
                            ID = 0;
                            persist = true;
                          }
                        ];
                      }
                  )
                  nonGroupPins;

                sessionStore.folders =
                  mapAttrsToList (_: p: {
                    pinned = true;
                    splitViewGroup = false;
                    id = "{${p.id}}";
                    name = p.title;
                    collapsed = p.isFolderCollapsed;
                    saveOnWindowClose = true;
                    parentId =
                      if p.folderParentId == null
                      then null
                      else "{${p.folderParentId}}";
                    prevSiblingInfo = {
                      type = "start";
                      id = null;
                    };
                    emptyTabIds =
                      if folderHasDirectChild p
                      then []
                      else ["{${p.id}}-empty"];
                    userIcon =
                      if p.folderIcon == null
                      then ""
                      else p.folderIcon;
                    workspaceId =
                      if p.workspace == null
                      then null
                      else "{${p.workspace}}";
                    index = p.position;
                  })
                  groupPins;

                sessionStore.groups =
                  mapAttrsToList (_: p: {
                    pinned = true;
                    splitView = false;
                    id = "{${p.id}}";
                    name = p.title;
                    color = "zen-workspace-color";
                    collapsed = p.isFolderCollapsed;
                    saveOnWindowClose = true;
                    index = p.position;
                  })
                  groupPins;
              };
            }
          )
        );
    };
  };
}
