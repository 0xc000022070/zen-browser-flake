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

  applicationName = "Zen Browser";
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

  config = mkIf cfg.enable {
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
