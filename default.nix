{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # wrapper.nix picks between its `ffmpeg_7` and `ffmpeg_8` formals with
  # `versionAtLeast browser.version "146"`, which reads Zen's "1.21.15b" rather
  # than a Gecko number and so always resolves to `ffmpeg_7`. Override both
  # slots so the branch it takes stops mattering. Both formals exist since
  # 26.05; 25.11 and older declare only `ffmpeg_7` and throw here.
  zenFfmpeg = pkgs.ffmpeg_9 or pkgs.ffmpeg_8;

  wrapZen = pkgs.wrapFirefox.override {
    ffmpeg_7 = zenFfmpeg;
    ffmpeg_8 = zenFfmpeg;
  };

  mkZen = name: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).variants.${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };
in rec {
  beta-unwrapped = mkZen "beta" "beta";
  twilight-unwrapped = mkZen "twilight" "twilight";
  twilight-official-unwrapped = mkZen "twilight" "twilight-official";

  beta =
    if isDarwin
    then beta-unwrapped
    else
      wrapZen beta-unwrapped {
        icon = "zen-browser";
      };
  twilight =
    if isDarwin
    then twilight-unwrapped
    else wrapZen twilight-unwrapped {};
  twilight-official =
    if isDarwin
    then twilight-official-unwrapped
    else
      wrapZen twilight-official-unwrapped {
        icon = "zen-twilight";
      };

  default = beta;
}
