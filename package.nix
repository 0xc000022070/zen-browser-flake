{
  name,
  variant,
  icon ? null,
  policies ? {},
  extraPolicies ? {},
  enablePrivateDesktopEntry ? false,
  lib,
  stdenv,
  config,
  wrapGAppsHook3,
  autoPatchelfHook,
  ffmpeg_8,
  # ffmpeg_9 is absent on nixpkgs 26.05; Zen dlopens libavcodec 62 and 63
  ffmpeg_9 ? ffmpeg_8,
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
  fetchurl,
  fetchzip,
  makeDesktopItem,
  copyDesktopItems,
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
    // policies
    // extraPolicies;

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON {policies = firefoxPolicies;});

  pname = "zen-${name}-bin-unwrapped";

  checkedPname = assert lib.assertMsg (
    !stdenv.hostPlatform.isDarwin || (policies == {} && extraPolicies == {})
  ) ''
    Direct policy overrides mutate the signed Zen application bundle on Darwin.
    Use programs.zen-browser.policies through the Home Manager module instead.
  ''; pname;

  desktopIconName =
    if name == "beta"
    then "zen-browser"
    else binaryName;

  installDarwin = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -r *.app "$out/Applications/${applicationName}.app"

    # Use symlink path to avoid installs.ini accumulation on Nix rebuilds
    # The symlink is created by home-manager and remains stable across rebuilds
    cat > "$out/bin/${binaryName}" << EOF
    #!/bin/bash
    # Use stable path from home-manager to avoid creating new install IDs
    STABLE_PATH="\$HOME/Applications/Home Manager Apps/${applicationName}.app"
    if [[ -e "\$STABLE_PATH" ]]; then
      exec /usr/bin/open -na "\$STABLE_PATH" --args "\$@"
    else
      # Fallback to nix store path if symlink doesn't exist yet
      exec /usr/bin/open -na "$out/Applications/${applicationName}.app" --args "\$@"
    fi
    EOF

    chmod +x "$out/bin/${binaryName}"

    runHook postInstall
  '';

  installLinux = ''
    runHook preInstall

    # Linux tarball installation
    mkdir -p "$prefix/lib/${libName}"
    cp -r "$src"/* "$prefix/lib/${libName}"

    mkdir -p "$out/bin"
    ln -s "$prefix/lib/${libName}/zen" "$out/bin/${binaryName}"

    mkdir -p "$out/lib/${libName}/distribution"
    ln -s ${policiesJson} "$out/lib/${libName}/distribution/policies.json"

    install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/${desktopIconName}.png

    runHook postInstall
  '';
in
  stdenv.mkDerivation {
    pname = checkedPname;
    inherit (variant) version;

    src =
      if stdenv.hostPlatform.isDarwin
      then
        fetchurl {
          inherit (variant) url;
          hash = variant.sha256;
        }
      else
        fetchzip {
          inherit (variant) url;
          hash = variant.sha256;
        };

    sourceRoot = lib.optionalString stdenv.hostPlatform.isDarwin ".";

    desktopItems = let
      mkDesktopEntry = args:
        makeDesktopItem (args
          // {
            icon =
              if icon != null && (lib.isString icon || lib.isPath icon)
              then icon
              else desktopIconName;
            type = "Application";
            mimeTypes = [
              "text/html"
              "text/xml"
              "application/xhtml+xml"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
              "application/x-xpinstall"
              "application/pdf"
              "application/json"
            ];
            startupWMClass = binaryName;
            categories = ["Network" "WebBrowser"];
            startupNotify = true;
            terminal = false;
            extraConfig.X-MultipleArgs = "false";
            keywords = ["Internet" "WWW" "Browser" "Web" "Explorer"];
          });
    in
      [
        (mkDesktopEntry {
          name = binaryName;
          desktopName = "Zen Browser${lib.optionalString (name == "twilight") " Twilight"}";
          exec = "${binaryName} %u";
          actions = {
            new-windows = {
              name = "Open a New Window";
              exec = "${binaryName} %u";
            };
            new-private-window = {
              name = "Open a New Private Window";
              exec = "${binaryName} --private-window %u";
            };
            profilemanager = {
              name = "Open the Profile Manager";
              exec = "${binaryName} --ProfileManager %u";
            };
          };
        })
      ]
      ++ lib.optionals (enablePrivateDesktopEntry == true) [
        (mkDesktopEntry {
          name = "${binaryName}-private";
          desktopName = "${applicationName} - Private Session";
          exec = "${binaryName} --private-window %u";
        })
      ];

    nativeBuildInputs =
      lib.optionals stdenv.hostPlatform.isLinux [
        wrapGAppsHook3
        autoPatchelfHook
        patchelfUnstable
        copyDesktopItems
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        undmg
      ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libXtst
      ffmpeg_9
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

    preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ffmpeg_9]}"
        --add-flags "--name=''${MOZ_APP_LAUNCHER:-${binaryName}}"
        --add-flags "--class=''${MOZ_APP_LAUNCHER:-${binaryName}}"
      )
    '';

    dontFixup = stdenv.hostPlatform.isDarwin;

    installPhase =
      if stdenv.hostPlatform.isDarwin
      then installDarwin
      else installLinux;

    passthru = {
      inherit applicationName binaryName libName;
      ffmpegSupport = true;
      gssSupport = true;
      gtk3 = gtk3;
    };

    meta = {
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
