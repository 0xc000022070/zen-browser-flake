{
  name,
  variant,
  desktopFile,
  policies ? {},
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
  libGL,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  undmg,
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

  libName = "zen-bin-${variant.version}";

  mozillaPlatforms = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
    aarch64-darwin = "darwin-aarch64";
  };

  firefoxPolicies =
    (config.firefox.policies or {})
    // policies;

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON {policies = firefoxPolicies;});

  pname = "zen-${name}-bin-unwrapped";

  installDarwin = ''
    mkdir -p "$out/Applications" "$out/bin"
    cp -r *.app "$out/Applications/${applicationName}.app"
    ln -s zen "$out/Applications/${applicationName}.app/Contents/MacOS/${binaryName}"

    cat > "$out/bin/${binaryName}" << EOF
#!/bin/bash
exec /usr/bin/open -na "$out/Applications/${applicationName}.app" --args "\$@"
EOF

    chmod +x "$out/bin/${binaryName}"
    ln -s "$out/bin/${binaryName}" "$out/bin/zen"
  '';

  installLinux = ''
    # Linux tarball installation
    mkdir -p "$prefix/lib/${libName}"
    cp -r "$src"/* "$prefix/lib/${libName}"

    mkdir -p "$out/bin"
    ln -s "$prefix/lib/${libName}/zen" "$out/bin/${binaryName}"
    ln -s "$out/bin/${binaryName}" "$out/bin/zen"

    install -D $desktopSrc/${desktopFile} $out/share/applications/${desktopFile}

    mkdir -p "$out/lib/${libName}/distribution"
    ln -s ${policiesJson} "$out/lib/${libName}/distribution/policies.json"

    install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen-${name}.png
    install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen-${name}.png
    install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen-${name}.png
    install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen-${name}.png
    install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen-${name}.png
  '';

in
  stdenv.mkDerivation {
    inherit pname;
    inherit (variant) version;

    src = if stdenv.hostPlatform.isDarwin
      then builtins.fetchurl { inherit (variant) url sha256; }
      else builtins.fetchTarball { inherit (variant) url sha256; };

    sourceRoot = lib.optionalString stdenv.hostPlatform.isDarwin ".";

    desktopSrc = ./assets/desktop;

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
      undmg
    ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libXtst
    ];

    runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
      curl
      libva.out
      pciutils
      libGL
    ];

    appendRunpaths = lib.optionals stdenv.hostPlatform.isLinux [
      "${libGL}/lib"
      "${pipewire}/lib"
    ];

    # Firefox uses "relrhack" to manually process relocations from a fixed offset
    patchelfFlags = ["--no-clobber-old-sections"];

    preFixup = ''
      gappsWrapperArgs+=(
        --add-flags "--name=''${MOZ_APP_LAUNCHER:-${binaryName}}"
      )
    '';

    installPhase = if stdenv.hostPlatform.isDarwin
      then installDarwin
      else installLinux;

    passthru = {
      inherit applicationName binaryName libName;
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