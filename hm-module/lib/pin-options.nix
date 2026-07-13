# Pin submodule shared by `pins` and the space-scoped `spaces.*.pins`.
# Space-scoped pins exclude `workspace`: it is derived from the owning
# space during desugaring (session/spaces.nix).
{
  lib,
  includeWorkspace ? true,
}: let
  inherit (lib) isPath mkOption types;
in
  {name, ...}: {
    options = with types;
      {
        title = mkOption {
          type = str;
          description = "title of the pin.";
          default = name;
        };
        id = mkOption {
          type = str;
          description = "REQUIRED. Unique Version 4 UUID for pin.";
        };
        url = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional URL text field";
        };
        container = mkOption {
          type = nullOr ints.unsigned;
          default = null;
          description = "Container ID to be used in pin";
        };
        position = mkOption {
          type = ints.unsigned;
          default = 1000;
          description = "Position of the pin.";
        };
        isEssential = mkOption {
          type = bool;
          default = false;
          description = "Required boolean flag for essential items, defaults to false";
        };
        isGroup = mkOption {
          type = bool;
          default = false;
          description = "Required boolean flag for group items, defaults to false";
        };
        editedTitle = mkOption {
          type = bool;
          default = false;
          description = "Required boolean flag for edited title, defaults to false";
        };
        isFolderCollapsed = mkOption {
          type = bool;
          default = false;
          description = "Required boolean flag for folder collapse state, defaults to false";
        };
        folderIcon = mkOption {
          type = nullOr (either str path);
          description = ''
            Folder icon only when `isGroup = true` (sessions `userIcon`). Emoji, `chrome://…`, or path (`file://…`).
            Normal pinned tabs: no declarative icon — set in Zen for now; workspaces use `spaces.*.icon`.
          '';
          apply = v:
            if isPath v
            then "file://${v}"
            else v;
          default = null;
        };
        icon = mkOption {
          type = nullOr (either str path);
          visible = false;
          description = ''
            Ignored on pins (warning if set). Tab icons: configure in Zen for now. Folders: `folderIcon`.
          '';
          apply = v:
            if isPath v
            then "file://${v}"
            else v;
          default = null;
        };
        folderParentId = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional folder parent UUID text field";
        };
      }
      // lib.optionalAttrs includeWorkspace {
        workspace = mkOption {
          type = nullOr str;
          default = null;
          description = "Workspace ID to be used in pin";
        };
      };
  }
