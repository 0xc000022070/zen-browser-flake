# Declarative JSON / jq fragments for zen-live-folders.jsonlz4 and zen-sessions live-folder filtering.
{
  pkgs,
  lib,
  profile,
  profileName,
  profilePath,
  optionalString,
}: let
  inherit (builtins) map toJSON;
  inherit (lib) imap0 mapAttrsToList optionalAttrs sort;

  zenId = import ./id.nix {inherit lib;};

  liveFoldersFetchIntervalMs = 1800000;

  singleDeclaredSpaceId = let
    names = builtins.attrNames profile.spaces;
  in
    if builtins.length names != 1
    then null
    else (builtins.getAttr (builtins.elemAt names 0) profile.spaces).id;

  resolvedWorkspace = lf:
    if lf.workspace != null
    then lf.workspace
    else singleDeclaredSpaceId;

  liveFolderEntries =
    mapAttrsToList (
      attrName: lf: let
        id =
          if lf.id != null && lf.id != ""
          then lf.id
          else
            zenId.mkZenLiveFolderId {
              inherit profileName attrName;
              inherit (lf) kind title feedUrl maxItems timeRange repos githubOptions collapsed workspace folderParentId folderIcon position;
            };
      in
        lf // {inherit attrName id;}
    )
    profile.liveFolders;

  sortedLiveFolderEntries = sort (a: b: a.position < b.position) liveFolderEntries;

  liveFolderSessionFolder = lf: {
    pinned = true;
    splitViewGroup = false;
    id = lf.id;
    name = lf.title;
    collapsed = lf.collapsed;
    saveOnWindowClose = true;
    userIcon =
      if lf.folderIcon == null
      then ""
      else lf.folderIcon;
    workspaceId = let
      w = resolvedWorkspace lf;
    in
      if w == null
      then null
      else "{${w}}";
    parentId =
      if lf.folderParentId == null
      then null
      else "{${lf.folderParentId}}";
    index = lf.position;
    isLiveFolder = true;
  };

  liveFolderRows =
    imap0 (
      idx: lf: let
        prevId =
          if idx == 0
          then null
          else (builtins.elemAt sortedLiveFolderEntries (idx - 1)).id;
        prevSiblingInfo =
          if prevId == null
          then {
            type = "start";
            id = null;
          }
          else {
            type = "group";
            id = prevId;
          };
        placeholderSyncId = zenId.mkZenLiveFolderPlaceholderTabSyncId {
          inherit profileName;
          inherit (lf) attrName;
          folderId = lf.id;
        };
      in
        (liveFolderSessionFolder lf)
        // {
          inherit prevSiblingInfo;
          emptyTabIds = [placeholderSyncId];
        }
    )
    sortedLiveFolderEntries;

  liveFolderPlaceholderTabs =
    map (lf: let
      placeholderSyncId = zenId.mkZenLiveFolderPlaceholderTabSyncId {
        inherit profileName;
        inherit (lf) attrName;
        folderId = lf.id;
      };
    in {
      entries = [
        {
          url = "about:blank";
          triggeringPrincipal_base64 = "{\"3\":{}}";
        }
      ];
      lastAccessed = 0;
      pinned = true;
      hidden = false;
      groupId = lf.id;
      zenWorkspace = null;
      zenSyncId = placeholderSyncId;
      zenEssential = false;
      zenDefaultUserContextId = null;
      zenPinnedIcon = null;
      zenIsEmpty = true;
      zenHasStaticIcon = false;
      zenGlanceId = null;
      zenIsGlance = false;
      _zenPinnedInitialState = {
        entry = {url = "about:blank";};
        image = null;
      };
      zenLiveFolderItemId = null;
      searchMode = null;
      userContextId = 0;
      attributes = {};
      index = 1;
      image = "";
      userTypedValue = "";
      userTypedClear = 0;
    })
    sortedLiveFolderEntries;

  liveFolderZenEntry = lf: let
    interval = liveFoldersFetchIntervalMs;
    common = {
      id = lf.id;
      dismissedItems = [];
      tabsState = [];
    };
  in
    if lf.kind == "rss"
    then
      common
      // {
        type = "rss";
        data = {
          state = {
            url = lf.feedUrl;
            maxItems = lf.maxItems;
            timeRange = lf.timeRange;
            inherit interval;
            lastFetched = 0;
            lastErrorId = null;
            options = {};
          };
        };
      }
    else
      common
      // {
        type = "github";
        data = {
          state = {
            type =
              if lf.kind == "github-pull-requests"
              then "pull-requests"
              else "issues";
            url =
              if lf.kind == "github-pull-requests"
              then "https://github.com/pulls"
              else "https://github.com/issues";
            repos = lf.repos;
            options =
              {repoExcludes = lf.githubOptions.repoExcludes;}
              // optionalAttrs lf.githubOptions.authorMe {
                inherit (lf.githubOptions) authorMe;
              }
              // optionalAttrs (!lf.githubOptions.assignedMe) {
                assignedMe = false;
              }
              // optionalAttrs lf.githubOptions.reviewRequested {
                inherit (lf.githubOptions) reviewRequested;
              };
            inherit interval;
            lastFetched = 0;
            lastErrorId = null;
            isJsonApi = false;
          };
        };
      };

  liveFoldersZenList = map liveFolderZenEntry liveFolderEntries;
  liveFoldersZenJson = toJSON liveFoldersZenList;

  runLiveFoldersUpdate = profile.liveFolders != {} || profile.liveFoldersForce;

  liveFoldersDeclaredIdsJson =
    toJSON (map (lf: lf.id) liveFolderEntries);
  liveFoldersIdsFile =
    pkgs.writeText "zen-declared-live-folder-ids-${profileName}.json" liveFoldersDeclaredIdsJson;

  liveFoldersDeclaredJsonFile = pkgs.writeText "zen-declared-live-folders-${profileName}.json" liveFoldersZenJson;

  liveFoldersJqFilterFile = pkgs.writeText "zen-live-folders-filter-${profileName}.jq" ''
    (. // []) as $existing |
    ($declaredLiveFolders[0]) as $decl |
    ($decl
      | map(
          . as $new |
          (($existing | map(select(.id == $new.id))) | .[0]) as $old |
          if $old == null then
            $new
          else
            $old
            | .data.state = (
                ($new.data.state) as $ns |
                ($old.data.state // {}) as $os |
                $ns
                | .lastFetched = ($os.lastFetched // $ns.lastFetched)
                | .lastErrorId = ($os.lastErrorId // $ns.lastErrorId)
              )
            | .dismissedItems = ($old.dismissedItems // [])
            | .tabsState = ($old.tabsState // [])
          end
        )) as $from_decl |
    ${optionalString (!profile.liveFoldersForce) ''
      ($existing
        | map(select(.id as $id | [$decl[].id] | index($id) == null))) as $orphans |
    ''}
    $from_decl ${optionalString (!profile.liveFoldersForce) "+ $orphans"}
  '';

  liveFolderPlaceholderTabsJson = toJSON liveFolderPlaceholderTabs;

  # SessionStore expects a matching `groups[]` tab-group entry so Zen can attach the DOM node
  # before LiveFolders applies metadata (`ZenFolders.mjs` restore path).
  liveFolderGroupRows =
    map (lf: {
      pinned = true;
      splitView = false;
      id = lf.id;
      name = lf.title;
      color = "zen-workspace-color";
      collapsed = lf.collapsed;
      saveOnWindowClose = true;
      index = lf.position;
    })
    liveFolderEntries;

  jqZenSessionsLiveFoldersForce = optionalString profile.liveFoldersForce ''
    .folders = [.folders[] |
      if .isLiveFolder == true then
        select(.id as $id | ($declaredLiveFolderIds[0]) | index($id) != null)
      else . end
    ] |
  '';
in {
  inherit
    liveFolderRows
    liveFolderGroupRows
    liveFolderPlaceholderTabsJson
    liveFoldersZenJson
    runLiveFoldersUpdate
    liveFoldersDeclaredIdsJson
    liveFoldersIdsFile
    liveFoldersDeclaredJsonFile
    liveFoldersJqFilterFile
    jqZenSessionsLiveFoldersForce
    ;

  liveFoldersFile = "${profilePath}/${profileName}/zen-live-folders.jsonlz4";
}
