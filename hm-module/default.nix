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
    (import ./places.nix)
    (import ./keyboard-shortcuts.nix)
    (import ./mods.nix)
    (import ./sine.nix {inherit mkSinePack;})
    (import ./default-browser.nix {inherit name;})
    (lib.mkRemovedOptionModule [
      "programs"
      "zen-browser"
      "suppressXdgMigrationWarning"
    ] "The XDG migration stage has ended.")
  ];

  config = mkIf cfg.enable {
    warnings = let
      essentialPinsWarning = let
        hasIssue = lib.any (
          profile:
            ((profile.settings or {})."zen.window-sync.enabled" or true)
            == false
            && lib.any (p: p.isEssential or false) (lib.attrValues (profile.pins or {}))
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
              (profile.pins or {})
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
              (profile.pins or {})
            )
        )
        cfg.profiles
      );
    in
      lib.filter (w: w != null) ([essentialPinsWarning] ++ pinIconIgnoredWarnings ++ folderIconMisuseWarnings);

    assertions =
      [
        {
          assertion = cfg.icon == null || pkgs.stdenv.isLinux;
          message = "The 'icon' option is only supported on Linux.";
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
            lib.mapAttrsToList (groupName: group: {
              assertion = builtins.length group.tabs >= 2;
              message = "Profile '${profileName}' joinedTabs '${groupName}': at least two tabs are required.";
            })
            (profile.joinedTabs or {})
        )
        cfg.profiles));
  };
}
