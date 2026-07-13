# Flattens the nested pin tree (`pins.*.pins`) into the flat attrset the
# producers consume. Children get `folderParentId` and `workspace` from the
# owning folder pin, a pin with children is a folder (`isGroup` implied),
# and keys extend the parent key: "State" -> "State/Cursor".
# Folder nesting is capped at `maxSubfolders` (Zen's
# zen.folders.max-subfolders): the throw doubles as a termination guard,
# so a self-referential (lazily infinite) pin tree fails instead of
# hanging evaluation.
{lib}: let
  inherit (lib) concatLists listToAttrs mapAttrsToList nameValuePair optionalAttrs;

  go = maxSubfolders: prefix: parent: depth: pins:
    concatLists (mapAttrsToList (
        name: p: let
          key =
            if prefix == null
            then name
            else "${prefix}/${name}";
          resolved =
            removeAttrs p ["pins"]
            // {isGroup = p.isGroup || p.pins != {};}
            // optionalAttrs (parent != null) {
              folderParentId = parent.id;
              workspace = parent.workspace;
            };
        in
          [(nameValuePair key resolved)]
          ++ (
            if p.pins != {} && depth > maxSubfolders
            then throw "zen-browser: pin folder '${key}' exceeds zen.folders.max-subfolders (${toString maxSubfolders}); Zen cannot nest folders this deep."
            else
              go maxSubfolders key {
                id = p.id;
                workspace = resolved.workspace;
              } (depth + 1)
              p.pins
          )
      )
      pins);
in
  maxSubfolders: pins: listToAttrs (go maxSubfolders null null 0 pins)
