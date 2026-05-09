# Deterministic ids in the same shape Zen uses when creating a live folder in the UI:
# ``${Date.now()}-${Math.round(Math.random() * 100)}`` (see Zen ``ZenFolders.mjs``).
{lib}: let
  inherit (builtins) hashString substring toString;
  inherit (lib) foldl' mod stringToCharacters;

  hexVal = c: let
    x = lib.toLower c;
  in
    if x >= "0" && x <= "9"
    then builtins.fromJSON x
    else if x == "a"
    then 10
    else if x == "b"
    then 11
    else if x == "c"
    then 12
    else if x == "d"
    then 13
    else if x == "e"
    then 14
    else if x == "f"
    then 15
    else 0;

  hexToInt = hex:
    foldl' (acc: ch: acc * 16 + hexVal ch) 0 (stringToCharacters hex);

  maxMillis = 10000000000000;

  # Stable across rebuilds for the same profile + attribute name + folder fields.
  mkZenLiveFolderId = {
    profileName,
    attrName,
    kind,
    title,
    feedUrl,
    maxItems,
    timeRange,
    repos,
    githubOptions,
    collapsed,
    workspace,
    folderParentId,
    folderIcon,
    position,
  }: let
    payload = builtins.concatStringsSep "\n" [
      profileName
      attrName
      kind
      title
      (toString feedUrl)
      (toString maxItems)
      (toString timeRange)
      (builtins.toJSON repos)
      (builtins.toJSON githubOptions)
      (toString collapsed)
      (toString workspace)
      (toString folderParentId)
      (toString folderIcon)
      (toString position)
    ];
    h = hashString "sha256" payload;
    part1 = mod (hexToInt (substring 0 12 h)) maxMillis;
    part2 = mod (hexToInt (substring 12 8 h)) 100;
    safe1 =
      if part1 == 0
      then mod (hexToInt (substring 24 12 h)) (maxMillis - 1) + 1
      else part1;
  in "${toString safe1}-${toString part2}";
in {
  inherit mkZenLiveFolderId;
}
