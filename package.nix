{
  name,
  variant,
  desktopFile,
  lib,
  stdenv,
  config,
  wrapGAppsHook3,
  autoPatchelfHook,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  libva,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  writeText,
  patchelfUnstable, # have to use patchelfUnstable to support --no-clobber-old-sections
  applicationName ?
    "Zen Browser"
    + (
      if name == "beta"
      then " (Beta)"
      else if name == "twilight"
      then " (Twilight)"
      else if name == "twilight-official"
      then " (Twilight)"
      else ""
    ),
}: let
  binaryName = "zen-${name}";

  mozillaPlatforms = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
  };

  policies =
    {
      DisableAppUpdate = true;
    }
    // config.firefox.policies or {};

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON {inherit policies;});

  pname = "zen-${name}-bin-unwrapped";
in
  stdenv.mkDerivation {
    inherit pname;
    inherit (variant) version;

    src = builtins.fetchTarball {inherit (variant) url sha256;};
    desktopSrc = ./assets/desktop;

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];
    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libXtst
    ];
    runtimeDependencies = [
      curl
      libva.out
      pciutils
    ];
    appendRunpaths = [
      "${pipewire}/lib"
    ];
    # Firefox uses "relrhack" to manually process relocations from a fixed offset
    patchelfFlags = ["--no-clobber-old-sections"];

    preFixup = ''
      gappsWrapperArgs+=(
        --add-flags '--name "''${MOZ_APP_LAUNCHER:-${binaryName}}"'
      )
    '';

    installPhase = ''
      mkdir -p "$prefix/lib/zen-bin-${variant.version}"
      cp -r "$src"/* "$prefix/lib/zen-bin-${variant.version}"

      mkdir -p "$out/bin"
      ln -s "$prefix/lib/zen-bin-${variant.version}/zen" "$out/bin/${binaryName}"
      # ! twilight and beta could collide if both are installed
      ln -s "$out/bin/${binaryName}" "$out/bin/zen"

      install -D $desktopSrc/${desktopFile} $out/share/applications/${desktopFile}

      mkdir -p "$out/lib/zen-${variant.version}/distribution"
      ln -s ${policiesJson} "$out/lib/zen-${variant.version}/distribution/policies.json"

      install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen-${name}.png
      install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen-${name}.png
      install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen-${name}.png
      install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen-${name}.png
      install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen-${name}.png
    '';

    passthru = {
      inherit applicationName binaryName;
      libName = "zen-bin-${variant.version}";
      ffmpegSupport = true;
      gssSupport = true;
      gtk3 = gtk3;
    };

    meta = {
      inherit desktopFile;
      description = "Experience tranquillity while browsing the web without people tracking you!";
      homepage = "https://zen-browser.app";
      downloadPage = "https://zen-browser.app/download/";
      changelog = "https://github.com/zen-browser/desktop/releases";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = builtins.attrNames mozillaPlatforms;
      hydraPlatforms = [];
      mainProgram = binaryName;
    };
  }
