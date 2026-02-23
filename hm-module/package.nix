{
  self,
  name,
  mkSinePack,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkDefault mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  isSineEnabled = lib.any (profile: profile.sine.enable) (lib.attrValues cfg.profiles);
in {
  options = setAttrByPath modulePath {
    extraPrefsFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of extra preference files to be included.";
    };

    extraPrefs = mkOption {
      type = types.str;
      default = "";
      description = "Extra preferences to be included.";
    };

    icon = mkOption {
      type = types.nullOr (types.either types.str types.path);
      default = null;
      description = "Icon to be used for the application. It's only expected to work on Linux.";
    };

    nixGL = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Wrap Zen Browser with config.lib.nixGL for GPU acceleration on non-NixOS Linux.

          See https://github.com/nix-community/nixGL for details.
        '';
      };
    };

    unwrappedPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        An unwrapped Firefox-based browser derivation to use as the base instead of
        the flake's built-in variants (beta, twilight, etc.). When set, this package
        is wrapped with the same settings (policies, extraPrefs, etc.) and used as
        the program. Useful to use a different Zen build, another Firefox-based
        browser, or a custom unwrapped derivation.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package = let
        defaultPackage =
          if cfg.unwrappedPackage != null
          then cfg.unwrappedPackage
          else
            self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
              policies = cfg.policies;
            };

        getPackage = sine:
          if sine
          then let
            sinePack = mkSinePack {};
          in
            defaultPackage.overrideAttrs (oldAttrs: {
              postInstall =
                (oldAttrs.postInstall or "")
                + ''
                  for libdir in "$out"/lib/zen-bin-*; do
                    chmod -R u+w "$libdir"
                    cp "${sinePack.bootloader}/program/config.js" "$libdir/config.js"
                    mkdir -p "$libdir/defaults/pref"
                    cp "${sinePack.bootloader}/program/defaults/pref/config-prefs.js" "$libdir/defaults/pref/config-pref.js"
                  done
                '';
            })
          else defaultPackage;

        wrappedPackage =
          (pkgs.wrapFirefox (getPackage isSineEnabled) {
            icon =
              if cfg.icon != null
              then cfg.icon
              else if name == "beta"
              then "zen-browser"
              else "zen-${name}";
          }).override {
            extraPrefs = cfg.extraPrefs;
            extraPrefsFiles = cfg.extraPrefsFiles;
            nativeMessagingHosts = cfg.nativeMessagingHosts;
          };
      in
        mkDefault (
          if cfg.nixGL.enable
          then config.lib.nixGL.wrap wrappedPackage
          else wrappedPackage
        );

      policies = {
        DisableAppUpdate = mkDefault true;
        DisableTelemetry = mkDefault true;
      };
    };
  };
}
