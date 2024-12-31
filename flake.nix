{
  description = "Zen Browser";

  inputs = {nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";};

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";

    prepareUrl = version: arch: "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-${arch}.tar.bz2";

    beta_version = "1.0.2-b.5";
    beta_hash = "1xp0z86l7z661cwckgr623gwwjsy3h66900xqjq6dvgx5a3njbxi";

    # https://github.com/zen-browser/desktop/releases/download/1.0.2-b.5/zen.linux-x86_64.tar.bz2
    beta = {
      name = "beta";
      url = prepareUrl beta_version "x86_64";
      sha256 = beta_hash;
      version = beta_version;
    };

    # https://github.com/zen-browser/desktop/releases/download/twilight/zen.linux-x86_64.tar.bz2
    twilight = {
      name = "twilight";
      url = prepareUrl "twilight" "x86_64";
      sha256 = "0j5dy58kammrz56j3id149k3kdnc0b2y7h03yq6l1n2fpklxq2kc";
      version = "twilight";
    };

    pkgs = import nixpkgs {inherit system;};

    mkZen = {
      name,
      url,
      sha256,
      version,
    }: let
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
    in
      pkgs.stdenv.mkDerivation {
        inherit version;
        pname = "zen-browser";

        src = builtins.fetchTarball {inherit url sha256;};
        desktopSrc = ./.;

        phases = ["installPhase" "fixupPhase"];

        nativeBuildInputs = [pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook];

        installPhase = ''
          mkdir -p $out/{bin,opt/zen,lib/zen-${version}/distribution} && cp -r $src/* $out/opt/zen
          ln -s $out/opt/zen/zen $out/bin/zen
          ln -s ${policiesJson} "$out/lib/zen-${version}/distribution/policies.json"

          install -D $desktopSrc/zen-${name}.desktop $out/share/applications/zen.desktop

          install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen.png
          install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen.png
          install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen.png
          install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen.png
          install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
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

        meta.mainProgram = "zen";
      };
  in {
    packages."${system}" = {
      default = mkZen beta;
      beta = mkZen beta;
      twilight = mkZen twilight;
    };
  };
}
