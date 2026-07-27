# Every wrapFirefox feature is delivered by writing inside the application
# directory. On Darwin that breaks the upstream signature, and with it 1Password,
# iCloud Passwords, Touch ID and Gatekeeper, so `darwin.packageMode = "signed"`
# installs the .app untouched and routes what it can outside of it: policies
# through targets.darwin.defaults, native messaging hosts through
# mozilla.firefoxNativeMessagingHosts. The rest is rejected in default.nix.
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

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isSignedDarwin = isDarwin && cfg.darwin.packageMode == "signed";

  isSineEnabled = lib.any (profile: profile.sine.enable) (lib.attrValues cfg.profiles);

  envWrapperArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (k: v: "--set ${lib.escapeShellArg k} ${lib.escapeShellArg v}") cfg.env
  );

  applyEnv = pkg:
    if cfg.env == {} || !isLinux
    then pkg
    else
      pkg.overrideAttrs (old: {
        preFixup =
          (old.preFixup or "")
          + ''
            gappsWrapperArgs+=(${envWrapperArgs})
          '';
      });

  prepareDarwinWrapper = pkg:
    if !isDarwin || !(pkg ? applicationName && pkg ? binaryName)
    then pkg
    else
      pkg.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            wrapperBinary="$out/Applications/${pkg.applicationName}.app/Contents/MacOS/${pkg.binaryName}"
            if [[ ! -e "$wrapperBinary" && ! -L "$wrapperBinary" ]]; then
              ln -s zen "$wrapperBinary"
            fi
          '';
      });
in {
  options = setAttrByPath modulePath {
    darwin.packageMode = mkOption {
      type = types.enum ["signed" "wrapped"];
      default = "signed";
      description = "`signed` installs the upstream .app untouched, `wrapped` enables wrapFirefox features and drops the signature.";
    };

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

    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        GTK_THEME = "Adwaita";
      };
      description = ''
        Environment variables to set when launching Zen Browser. Each entry is
        injected into the launcher with `makeWrapper --set`, so it applies
        whether the browser is started from its desktop entry or the command
        line.

        Only supported on Linux.
      '';
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
        the flake's built-in variants (beta, twilight, etc.). On Darwin in `signed`
        mode it is installed unchanged. Otherwise it is wrapped with the configured
        wrapper features.
      '';
    };
  };

  config = mkIf cfg.enable {
    mozilla.firefoxNativeMessagingHosts = mkIf isDarwin cfg.nativeMessagingHosts;

    programs.zen-browser = {
      package = let
        basePackage = applyEnv (
          if cfg.unwrappedPackage != null
          then cfg.unwrappedPackage
          else if isLinux
          then
            self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
              inherit (cfg) enablePrivateDesktopEntry;
            }
          else self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped"
        );

        getPackage = sine:
          if sine
          then let
            sinePack = mkSinePack {};
          in
            basePackage.overrideAttrs (oldAttrs: {
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
          else basePackage;

        wrappedPackage =
          ((pkgs.wrapFirefox.override {ffmpeg_7 = pkgs.ffmpeg_8;}) (prepareDarwinWrapper (getPackage isSineEnabled)) {
            icon =
              if cfg.icon != null
              then cfg.icon
              else if name == "beta"
              then "zen-browser"
              else "zen-${name}";
          }).override {
            inherit (cfg) extraPrefs extraPrefsFiles;
            nativeMessagingHosts = lib.optionals isLinux cfg.nativeMessagingHosts;
          };

        selectedPackage =
          if isSignedDarwin
          then basePackage
          else wrappedPackage;
      in
        mkDefault (
          if cfg.nixGL.enable
          then config.lib.nixGL.wrap selectedPackage
          else selectedPackage
        );

      policies = {
        DisableAppUpdate = mkDefault true;
        DisableTelemetry = mkDefault true;
      };
    };
  };
}
