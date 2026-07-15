{
  home-manager,
  self,
  name,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkIf;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  mkSinePack = {}: let
    sources = builtins.fromJSON (builtins.readFile "${self}/sources.json");
  in {
    manager = pkgs.fetchFromGitHub {
      inherit (sources.addons.sine.manager) rev hash;
      repo = "Sine";
      owner = "CosmoCreeper";
    };
    bootloader = pkgs.fetchFromGitHub {
      inherit (sources.addons.sine.bootloader) rev hash;
      repo = "bootloader";
      owner = "sineorg";
    };
  };

  applicationName = "Zen";
  linuxConfigPath = "${config.xdg.configHome}/zen";
  darwinConfigPath = "${config.home.homeDirectory}/Library/Application Support/Zen";

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "zen-${name}";
      unwrappedPackageName = "zen-${name}-unwrapped";
      platforms = {
        linux = {
          vendorPath = linuxConfigPath;
          configPath = linuxConfigPath;
        };
        darwin = {
          configPath = darwinConfigPath;
          defaultsId = "app.zen-browser.zen";
        };
      };
    })
    (import ./package.nix {inherit self name mkSinePack;})
    (import ./session/store.nix)
    (import ./session/spaces.nix)
    (import ./session/pins.nix)
    (import ./session/joined-tabs.nix)
    (import ./session/live-folders.nix)
    (import ./keyboard-shortcuts.nix)
    (import ./mods.nix)
    (import ./sine.nix {inherit mkSinePack;})
    (import ./default-browser.nix {inherit name;})
    (import ./presets/catppuccin.nix {inherit self;})
    (import ./presets/betterfox.nix {inherit self;})
    (import ./presets/arkenfox.nix {inherit self;})
  ];

  config = mkIf cfg.enable {
    warnings = let
      essentialPinsWarning = let
        hasIssue = lib.any (
          profile:
            ((profile.settings or {})."zen.window-sync.enabled" or true)
            == false
            && lib.any (p: p.isEssential or false) (lib.attrValues (profile.pinsResolved or {}))
        ) (lib.attrValues cfg.profiles);
      in
        if hasIssue
        then ''
          [Zen Browser] You have essential pins (isEssential = true) but window-sync is disabled.
          Essentials may not display. Consider enabling window-sync, e.g. with:
            "zen.window-sync.enabled" = true;
            "zen.window-sync.sync-only-pinned-tabs" = true;
        ''
        else null;

      liveFoldersWindowSyncWarning = let
        hasIssue = lib.any (
          profile:
            ((profile.settings or {})."zen.window-sync.enabled" or true)
            == false
            && (profile.liveFolders or {}) != {}
        ) (lib.attrValues cfg.profiles);
      in
        if hasIssue
        then ''
          [Zen Browser] You have liveFolders but window-sync is disabled. Zen restores live
          folders through the synced window; without it the folder may not attach and Zen
          can clear zen-live-folders.jsonlz4 on its next save. Consider:
            "zen.window-sync.enabled" = true;
        ''
        else null;

      pinIconIgnoredWarnings = lib.concatLists (
        lib.mapAttrsToList (
          profileName: profile:
            lib.concatLists (
              lib.mapAttrsToList (
                pinName: pin:
                  lib.optional ((pin.icon or null) != null) ''
                    [Zen Browser] '${profileName}' / '${pinName}': `pins.*.icon` does nothing — tab icons are not declarative here; set them in Zen for now. Folders only: `folderIcon` with `isGroup`; workspaces: `spaces.*.icon`.
                  ''
              )
              (profile.pinsResolved or {})
            )
        )
        cfg.profiles
      );

      urlOnFolderWarnings = lib.concatLists (
        lib.mapAttrsToList (
          profileName: profile:
            lib.concatLists (
              lib.mapAttrsToList (
                pinName: pin:
                  lib.optional (pin.isGroup && (pin.url or null) != null) ''
                    [Zen Browser] '${profileName}' / '${pinName}': `url` does nothing on a folder pin — folders have no page. Note that nesting child pins under a pin makes it a folder (`isGroup` is implied).
                  ''
              )
              (profile.pinsResolved or {})
            )
        )
        cfg.profiles
      );

      folderIconMisuseWarnings = lib.concatLists (
        lib.mapAttrsToList (
          profileName: profile:
            lib.concatLists (
              lib.mapAttrsToList (
                pinName: pin:
                  lib.optional ((pin.folderIcon or null) != null && !(pin.isGroup or false)) ''
                    [Zen Browser] '${profileName}' / '${pinName}': `folderIcon` only applies when `isGroup = true`; ignored here.
                  ''
              )
              (profile.pinsResolved or {})
            )
        )
        cfg.profiles
      );
    in
      lib.filter (w: w != null) ([essentialPinsWarning liveFoldersWindowSyncWarning] ++ pinIconIgnoredWarnings ++ urlOnFolderWarnings ++ folderIconMisuseWarnings);

    assertions =
      [
        {
          assertion = cfg.icon == null || pkgs.stdenv.isLinux;
          message = "The 'icon' option is only supported on Linux.";
        }
        {
          assertion = cfg.env == {} || pkgs.stdenv.isLinux;
          message = "The 'env' option is only supported on Linux.";
        }
        {
          assertion = !cfg.nixGL.enable || (config.lib ? nixGL && config.lib.nixGL ? wrap);
          message = "You don't meet the requirements to use the 'nixGL.enable' option. See https://github.com/nix-community/nixGL for details.";
        }
      ]
      ++ (lib.mapAttrsToList (profileName: profile: {
          assertion = !(profile.sine.enable && profile.mods != []);
          message = "Profile '${profileName}': sine.enable and mods options are mutually exclusive. When sine.enable is true, mods must be empty.";
        })
        cfg.profiles)
      ++ (lib.mapAttrsToList (profileName: profile: {
          assertion = !(profile.sine.mods != [] && !profile.sine.enable);
          message = "Profile '${profileName}': sine.mods requires sine.enable to be true.";
        })
        cfg.profiles)
      ++ (lib.flatten (lib.mapAttrsToList (
          profileName: profile:
            lib.mapAttrsToList (groupName: group: [
              {
                assertion = builtins.length group.tabs >= 2;
                message = "Profile '${profileName}' joinedTabs '${groupName}': at least two tabs are required.";
              }
              {
                assertion = builtins.length group.tabs <= 3;
                message = "Profile '${profileName}' joinedTabs '${groupName}': at most three tabs are allowed.";
              }
              {
                assertion = group.sizes == [] || builtins.length group.sizes == builtins.length group.tabs;
                message = "Profile '${profileName}' joinedTabs '${groupName}': sizes length (${toString (builtins.length group.sizes)}) must match tabs length (${toString (builtins.length group.tabs)}).";
              }
              {
                assertion = group.sizes == [] || lib.foldl' (a: b: a + b) 0 group.sizes == 100;
                message = "Profile '${profileName}' joinedTabs '${groupName}': sizes must sum to 100 (got ${toString (lib.foldl' (a: b: a + b) 0 group.sizes)}).";
              }
              {
                assertion =
                  group.folderParentId
                  == null
                  || lib.any (p: p.isGroup && p.id == group.folderParentId) (lib.attrValues (profile.pinsResolved or {}));
                message = "Profile '${profileName}' joinedTabs '${groupName}': folderParentId must match the id of a pin with isGroup = true.";
              }
            ])
            (profile.joinedTabs or {})
        )
        cfg.profiles))
      ++ (lib.flatten (lib.mapAttrsToList (
          profileName: profile:
            lib.mapAttrsToList (lfName: lf: [
              {
                assertion = lf.kind != "rss" || lf.feedUrl != null;
                message = "Profile '${profileName}' liveFolders '${lfName}': feedUrl is required when kind = \"rss\".";
              }
              {
                assertion = lf.kind == "rss" || lf.feedUrl == null;
                message = "Profile '${profileName}' liveFolders '${lfName}': feedUrl only applies to kind = \"rss\".";
              }
              {
                assertion = lf.workspace or null != null;
                message = "Profile '${profileName}' liveFolders '${lfName}': workspace is required — Zen folders belong to exactly one space. Use spaces.<name>.liveFolders, or set workspace to a space id (without declared spaces: copy the zen.workspaces.active pref from about:config, minus the braces).";
              }
            ])
            (profile.liveFolders or {})
        )
        cfg.profiles))
      ++ (lib.mapAttrsToList (profileName: profile: let
          # Spaces, pins, joinedTabs and liveFolders all become rows keyed by
          # id in zen-sessions.jsonlz4, so they share one id namespace: the
          # upsert merges entries sharing an id into the first declaration and
          # silently drops the rest.
          declared =
            lib.mapAttrsToList (n: v: {
              inherit (v) id;
              name = "pins.'${n}'";
            }) (profile.pinsResolved or {})
            ++ lib.mapAttrsToList (n: v: {
              inherit (v) id;
              name = "spaces.'${n}'";
            }) (profile.spaces or {})
            ++ lib.mapAttrsToList (n: v: {
              inherit (v) id;
              name = "joinedTabs.'${n}'";
            }) (profile.joinedTabs or {})
            ++ lib.mapAttrsToList (n: v: {
              inherit (v) id;
              name = "liveFolders.'${n}'";
            }) (profile.liveFolders or {});
          byId = lib.foldl' (acc: d: acc // {${d.id} = (acc.${d.id} or []) ++ [d.name];}) {} declared;
          collisions = lib.filterAttrs (_: names: builtins.length names > 1) byId;
        in {
          assertion = collisions == {};
          message = "Profile '${profileName}': duplicate ids — entries sharing an id merge into the first declaration and the rest are silently dropped. Reused: ${
            lib.concatStringsSep "; " (
              lib.mapAttrsToList (
                id: names: "'${id}' by ${lib.concatStringsSep ", " names}"
              )
              collisions
            )
          }";
        })
        cfg.profiles)
      ++ (lib.flatten (lib.mapAttrsToList (
          profileName: profile:
            lib.mapAttrsToList (pinName: pin: {
              assertion = !(pin.isEssential && pin.folderParentId != null);
              message = "Profile '${profileName}' pins '${pinName}': essential pins live in the essentials strip and cannot be inside a folder (isEssential = true with a folder parent).";
            })
            (profile.pinsResolved or {})
        )
        cfg.profiles));
  };
}
