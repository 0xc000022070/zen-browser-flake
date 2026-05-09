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
  inherit (lib) mapAttrsToList;

  zenId = import ./id.nix {inherit lib;};

  liveFoldersFetchIntervalMs = 1800000;

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
        lf // {inherit id;}
    )
      profile.liveFolders;

  liveFolderSessionFolder = lf: {
    pinned = true;
    essential = false;
    splitViewGroup = false;
    id = lf.id;
    name = lf.title;
    collapsed = lf.collapsed;
    saveOnWindowClose = true;
    prevSiblingInfo = {
      type = "start";
      id = null;
    };
    emptyTabIds = [];
    userIcon =
      if lf.folderIcon == null
      then ""
      else lf.folderIcon;
    workspaceId =
      if lf.workspace == null
      then null
      else "{${lf.workspace}}";
    parentId =
      if lf.folderParentId == null
      then null
      else "{${lf.folderParentId}}";
    index = lf.position;
    isLiveFolder = true;
  };

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
            options = {
              repoExcludes = lf.githubOptions.repoExcludes;
              authorMe = lf.githubOptions.authorMe;
              assignedMe = lf.githubOptions.assignedMe;
              reviewRequested = lf.githubOptions.reviewRequested;
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

  liveFolderRows =
    map liveFolderSessionFolder liveFolderEntries;

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
