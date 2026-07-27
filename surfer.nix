{
  source,
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pkg-config,
  vips,
}:
buildNpmPackage {
  pname = "surfer";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "zen-browser";
    repo = "surfer";
    inherit (source) rev hash;
  };

  patches = [
    ./patches/surfer-disable-update-check.patch
    ./patches/surfer-static-changeset.patch
  ];

  inherit (source) npmDepsHash;
  npmFlags = ["--legacy-peer-deps"];
  makeCacheWritable = true;
  SHARP_IGNORE_GLOBAL_LIBVIPS = false;

  nativeBuildInputs = [pkg-config];
  buildInputs = [vips];

  meta = {
    description = "Build system for Firefox forks";
    homepage = "https://github.com/zen-browser/surfer";
    license = lib.licenses.mpl20;
    mainProgram = "surfer";
    platforms = lib.platforms.unix;
  };
}
