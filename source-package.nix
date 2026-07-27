{
  source,
  surfer,
  lib,
  stdenv,
  buildMozillaMach,
  fetchFromGitHub,
  fetchurl,
  git,
  python3,
  rustPlatform,
}: let
  inherit (source) version firefoxVersion;

  desktop = fetchFromGitHub {
    owner = "zen-browser";
    repo = "desktop";
    inherit (source) rev hash;
  };

  firefox = fetchurl {
    url = "mirror://mozilla/firefox/releases/${firefoxVersion}/source/firefox-${firefoxVersion}.source.tar.xz";
    hash = source.firefoxHash;
  };

  ffprefs = rustPlatform.buildRustPackage {
    pname = "zen-ffprefs";
    inherit version;
    src = desktop;
    sourceRoot = "source/tools/ffprefs";
    cargoHash = source.cargoHash;
  };

  preparedSource = stdenv.mkDerivation {
    pname = "zen-browser-prepared-source";
    inherit version;
    src = desktop;

    nativeBuildInputs = [
      ffprefs
      git
      python3
      surfer
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export SURFER_COMPAT=x86_64
      export SURFER_CHANGESET=${source.rev}
      export SURFER_DISABLE_UPDATE_CHECK=1
      export SURFER_MOZCONFIG_ONLY=1
      export ZEN_DOWNLOAD_DONT_INIT_GIT=1
      export ZEN_RELEASE=1

      surfer ci --brand release --display-version ${version}

      mkdir -p .surfer/engine
      install -Dm644 \
        ${firefox} \
        .surfer/engine/firefox-${firefoxVersion}.source.tar.xz

      surfer download
      ffprefs "$PWD"
      python3 scripts/update_service_dumps.py
      surfer import
      surfer build --skip-patch-check

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -aL engine/. "$out/"

      runHook postInstall
    '';
  };
in
  ((buildMozillaMach {
      pname = "zen-beta-source";
      packageVersion = version;
      version = firefoxVersion;
      src = preparedSource;
      applicationName = "Zen Browser (Beta)";
      binaryName = "zen-beta";
      branding = "browser/branding/release";
      requireSigning = false;
      allowAddonSideload = true;
      extraPassthru = {
        inherit preparedSource;
      };

      meta = {
        description = "Zen Browser built from source";
        homepage = "https://zen-browser.app";
        changelog = "https://github.com/zen-browser/desktop/releases";
        license = lib.licenses.mpl20;
        mainProgram = "zen-beta";
        platforms = ["x86_64-linux"];
        sourceProvenance = with lib.sourceTypes; [fromSource];
      };
    }).override {
      crashreporterSupport = false;
      enableDebugSymbols = false;
      enableOfficialBranding = false;
      ltoSupport = false;
      pgoSupport = false;
    }).overrideAttrs (old: {
    patches =
      builtins.filter (
        patch: !lib.hasInfix "link-freebl-explicitly-for-system-nss-builds" (toString patch)
      )
      old.patches;
  })
