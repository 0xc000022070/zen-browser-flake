{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    version = "1.0.1-a.19";
    downloadUrl = {
      specific.url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
      specific.sha256 = "1g7nq1yfaya97m43vnkjj1nd9g570viy8hj45c523hcyr1z92rjq";

      generic.url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-generic.tar.bz2";
      generic.sha256 = "1v8ndw5gd3yb5k6rplwb2cr1x4ag0xw43wayg8dyagywqzhwjcr7";
    };

    pkgs = import nixpkgs {
      inherit system;
    };

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

    mkZen = {variant}: let
      downloadData = downloadUrl."${variant}";
    in
      pkgs.stdenvNoCC.mkDerivation {
        inherit version;
        pname = "zen-browser";

        src = builtins.fetchTarball {
          url = downloadData.url;
          sha256 = downloadData.sha256;
        };

        desktopSrc = ./.;

        phases = ["installPhase" "fixupPhase"];

        nativeBuildInputs = [pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook];

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/bin"
          mkdir -p "$out/opt/zen"
          cp -r $src/* "$out/opt/zen/"
          ln -sf "$out/opt/zen/zen" "$out/bin/zen"

          install -D "$desktopSrc/zen.desktop" "$out/share/applications/zen.desktop"

          for size in 16 32 48 64 128; do
            install -D "$src/browser/chrome/icons/default/default''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/zen.png"
          done

          runHook postInstall
        '';

        fixupPhase = ''
          runHook preFixup

          chmod 755 "$out/bin/zen" $out/opt/zen/*

          INTERPRETER="${pkgs.stdenv.cc.bintools.dynamicLinker}"
          LIBS="${pkgs.lib.makeLibraryPath runtimeLibs}"

          for bin in zen zen-bin glxtest updater vaapitest; do
            patchelf --set-interpreter "$INTERPRETER" "$out/opt/zen/$bin"

            if [[ "$bin" == "zen" || "$bin" == "zen-bin" ]]; then
              wrapProgram "$out/opt/zen/$bin" \
                --set LD_LIBRARY_PATH "$LIBS" \
                --set MOZ_LEGACY_PROFILES 1 \
                --set MOZ_ALLOW_DOWNGRADE 1 \
                --set MOZ_APP_LAUNCHER zen \
                --prefix XDG_DATA_DIRS : \"$GSETTINGS_SCHEMAS_PATH\"
            else
              wrapProgram "$out/opt/zen/$bin" \
                --set LD_LIBRARY_PATH "$LIBS"
            fi
          done

          runHook postFixup
        '';

        meta.mainProgram = "zen";
      };
  in {
    packages."${system}" = {
      generic = mkZen {variant = "generic";};
      specific = mkZen {variant = "specific";};
      default = self.packages."${system}".specific;
    };
  };
}
