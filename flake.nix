{
  description = "Zen Browser";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    mkZen = name: system: let
      pkgs = import nixpkgs {inherit system;};
      variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${name}.${system};

      runtimeLibs = with pkgs;
        [
          libGL
          libGLU
          libevent
          libffi
          libjpeg
          libpng
          libstartup_notification
          libvpx
          libwebp
          stdenv.cc.cc
          fontconfig
          libxkbcommon
          zlib
          freetype
          gtk3
          libxml2
          dbus
          xcb-util-cursor
          alsa-lib
          libpulseaudio
          pango
          atk
          cairo
          gdk-pixbuf
          glib
          udev
          libva
          mesa
          libnotify
          cups
          pciutils
          ffmpeg
          libglvnd
          pipewire
          speechd
        ]
        ++ (with pkgs.xorg; [
          libxcb
          libX11
          libXcursor
          libXrandr
          libXi
          libXext
          libXcomposite
          libXdamage
          libXfixes
          libXScrnSaver
        ]);

      policiesJson = pkgs.writeText "firefox-policies.json" (builtins.toJSON {
        # https://mozilla.github.io/policy-templates/#disableappupdates
        policies = {
          DisableAppUpdate = true;
        };
      });

      desktopFile =
        if name == "beta"
        then "zen.desktop"
        else "zen_${name}.desktop";
    in
      pkgs.stdenv.mkDerivation {
        inherit (variant) version;
        pname = "zen-browser";

        src = builtins.fetchTarball {inherit (variant) url sha256;};
        desktopSrc = ./.;

        phases = ["installPhase" "fixupPhase"];

        nativeBuildInputs = [pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook];

        installPhase = ''
          mkdir -p $out/{bin,opt/zen,lib/zen-${variant.version}/distribution} && cp -r $src/* $out/opt/zen
          ln -s $out/opt/zen/zen $out/bin/zen
          ln -s ${policiesJson} "$out/lib/zen-${variant.version}/distribution/policies.json"
          ln -s $out/bin/zen $out/bin/zen-${name}

          install -D $desktopSrc/zen-${name}.desktop $out/share/applications/${desktopFile}

          install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen-${name}.png
          install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen-${name}.png
          install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen-${name}.png
          install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen-${name}.png
          install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen-${name}.png
        '';

        fixupPhase = ''
          chmod 755 $out/bin/zen $out/opt/zen/*

          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/zen
          wrapProgram $out/opt/zen/zen --set LD_LIBRARY_PATH "${
            pkgs.lib.makeLibraryPath runtimeLibs
          }" \
                               --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/zen-bin
               wrapProgram $out/opt/zen/zen-bin --set LD_LIBRARY_PATH "${
            pkgs.lib.makeLibraryPath runtimeLibs
          }" \
                               --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/glxtest
               wrapProgram $out/opt/zen/glxtest --set LD_LIBRARY_PATH "${
            pkgs.lib.makeLibraryPath runtimeLibs
          }"

          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/updater
               wrapProgram $out/opt/zen/updater --set LD_LIBRARY_PATH "${
            pkgs.lib.makeLibraryPath runtimeLibs
          }"

          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/vaapitest
               wrapProgram $out/opt/zen/vaapitest --set LD_LIBRARY_PATH "${
            pkgs.lib.makeLibraryPath runtimeLibs
          }"
        '';

        meta = {
          inherit desktopFile;

          description = "Experience tranquillity while browsing the web without people tracking you!";
          homepage = "https://zen-browser.app";
          downloadPage = "https://zen-browser.app/download/";
          changelog = "https://github.com/zen-browser/desktop/releases";
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "zen";
        };
      };

    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: {
      default = mkZen "beta" system;
      beta = mkZen "beta" system;
      twilight = mkZen "twilight" system;
      twilight-resilient = mkZen "twilight-resilient" system;
    });
  };
}
