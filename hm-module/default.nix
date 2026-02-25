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
  inherit (lib) getAttrFromPath mkIf mkOption setAttrByPath;

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
  ];

  options = setAttrByPath modulePath {
    suppressXdgMigrationWarning = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set to true to suppress the XDG config directory migration warning.
      '';
    };
  };

  config = mkIf cfg.enable {
    warnings = let
      migrationWarning =
        if pkgs.stdenv.isLinux && !cfg.suppressXdgMigrationWarning
        then ''
          [Zen Browser] Starting from release 18.18.6b, the configuration directory
          has changed from ~/.zen to ~/.config/zen.

          If you haven't migrated yet, please follow the migration guide:
          https://github.com/0xc000022070/zen-browser-flake#missing-configuration-after-update

          To suppress this warning after completing the migration, set:
            programs.zen-browser.suppressXdgMigrationWarning = true;
        ''
        else null;

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
    in
      lib.filter (w: w != null) [
        migrationWarning
        essentialPinsWarning
      ];

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
        cfg.profiles);
  };
}
