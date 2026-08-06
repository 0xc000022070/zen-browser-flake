# Extension id -> CustomizableUI widget id, mirroring makeWidgetId() from
# toolkit ExtensionCommon. Already-suffixed values pass through untouched.
{lib}: let
  inherit (lib) hasSuffix stringAsChars toLower;

  sanitize = stringAsChars (
    c:
      if builtins.match "[a-z0-9_-]" c != null
      then c
      else "_"
  );
in
  id:
    if hasSuffix "-browser-action" id
    then id
    else "${sanitize (toLower id)}-browser-action"
