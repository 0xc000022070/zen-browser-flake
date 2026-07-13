# Flattens the nested pin tree (`pins.*.pins`) into the flat attrset the
# producers consume. Children get `folderParentId` and `workspace` from the
# owning folder pin, a pin with children is a folder (`isGroup` implied),
# and keys extend the parent key: "State" -> "State/Cursor".
{lib}: let
  inherit (lib) concatLists listToAttrs mapAttrsToList nameValuePair optionalAttrs;

  go = prefix: parent: pins:
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
          ++ go key {
            id = p.id;
            workspace = resolved.workspace;
          }
          p.pins
      )
      pins);
in
  pins: listToAttrs (go null null pins)
