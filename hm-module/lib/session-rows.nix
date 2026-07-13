# Row shapes shared by the session-store producers.
{lib}: {
  wrapTabId = id:
    if lib.hasPrefix "{" id
    then id
    else "{${id}}";

  # about:blank placeholder pinned tab. Zen only materializes a folder's
  # tab-group element on restore when some tab references it via groupId;
  # folders without declared children (childless group pins, live folders)
  # need the same placeholder the browser itself creates in
  # ZenFolders.createFolder. tabId/groupId are final session ids;
  # workspace is a bare UUID or null.
  mkEmptyTabRow = {
    tabId,
    groupId,
    workspace,
    position,
  }: {
    pinned = true;
    hidden = false;
    zenWorkspace =
      if workspace == null
      then null
      else "{${workspace}}";
    zenSyncId = tabId;
    id = tabId;
    zenEssential = false;
    zenDefaultUserContextId = null;
    zenPinnedIcon = null;
    zenIsEmpty = true;
    zenHasStaticIcon = false;
    zenGlanceId = null;
    zenIsGlance = false;
    searchMode = null;
    userContextId = 0;
    attributes = {};
    index = position;
    lastAccessed = 0;
    inherit groupId;
    entries = [
      {
        url = "about:blank";
        triggeringPrincipal_base64 = "{\"3\":{}}";
      }
    ];
  };
}
