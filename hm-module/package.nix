{
  self,
  name,
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
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package = let
        defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
          policies = cfg.policies;
        };

        getPackage = sine:
          if sine
          then
            defaultPackage.overrideAttrs (oldAttrs: rec {
              sineconfig = builtins.fetchurl {
                url = "https://raw.githubusercontent.com/sineorg/bootloader/refs/heads/main/program/config.js";
                sha256 = "117a6gkaz1kinjflfzqc6qsb4r06x93w08q4lfdzh5a1cng95s5v";
              };
              configpref = builtins.fetchurl {
                url = "https://raw.githubusercontent.com/sineorg/bootloader/refs/heads/main/program/defaults/pref/config-prefs.js";
                sha256 = "1kkyq5qdp7nnq09ckbd3xgdhsm2q80xjmihgiqbzb3yi778jxzbb";
              };
              libname = "zen-bin-*";
              postInstall =
                (oldAttrs.postInstall or "")
                + ''
                  for libdir in "$out"/lib/${libname}; do
                    chmod -R u+w "$libdir"
                    cp "${sineconfig}" "$libdir/config.js"
                    mkdir -p "$libdir/defaults/pref"
                    cp "${configpref}" "$libdir/defaults/pref/config-pref.js"
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
