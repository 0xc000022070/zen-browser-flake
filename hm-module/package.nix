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

  sinePack = mkSinePack {};

  # Sine ships its own autoconfig script. Installing it as a second config.js
  # next to the wrapper's autoconfig.js makes defaults/pref hold two rival
  # general.config.filename values; the directory is read alphabetically, so
  # config-pref.js won and mozilla.cfg -- which carries extraPrefs and
  # extraPrefsFiles -- was never read. Feeding the script through
  # extraPrefsFiles keeps a single autoconfig chain instead.
  sineAutoConfig =
    pkgs.runCommand "sine-autoconfig.js" {}
    ''
      # sine-default-prefs.js exists only because Sine never applies a mod's
      # defaultValue entries outside its settings UI. Fail the build when that
      # TODO disappears, so the seed is re-examined on the sources.json bump
      # that removes it instead of silently double-applying forever.
      if ! grep -q 'TODO: Apply default preferences\.' \
        "${sinePack.manager}/src/core/manager.sys.mjs"; then
        echo "sine: upstream dropped the 'Apply default preferences' TODO." >&2
        echo "sine: recheck hm-module/sine-default-prefs.js -- if Sine now seeds" >&2
        echo "sine: mod defaults itself, delete it and drop this concatenation." >&2
        exit 1
      fi

      cat ${./sine-default-prefs.js} "${sinePack.bootloader}/program/config.js" > $out
    '';

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
          # Policies belong to the unwrapped derivation: wrapFirefox writes its
          # own distribution/policies.json, but the launcher execs through to
          # the unwrapped binary and Gecko reads the file next to
          # /proc/self/exe, so the wrapper's copy is never loaded.
          else if isLinux
          then
            self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
              inherit (cfg) policies enablePrivateDesktopEntry;
            }
          else self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped"
        );

        wrappedPackage =
          ((pkgs.wrapFirefox.override {ffmpeg_7 = pkgs.ffmpeg_8;}) (prepareDarwinWrapper basePackage) {
            icon =
              if cfg.icon != null
              then cfg.icon
              else if name == "beta"
              then "zen-browser"
              else "zen-${name}";
          }).override {
            inherit (cfg) extraPrefs;

            # Sine first so anything the user sets afterwards wins: the wrapper
            # concatenates these into mozilla.cfg in order, then appends extraPrefs.
            extraPrefsFiles =
              lib.optional isSineEnabled "${sineAutoConfig}"
              ++ cfg.extraPrefsFiles;

            # fx-autoconfig needs the sandbox off to reach ChromeUtils.
            extraAutoConfig = lib.optionalString isSineEnabled ''
              pref("general.config.sandbox_enabled", false);
            '';

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
