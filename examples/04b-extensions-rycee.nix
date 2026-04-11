# Firefox extensions via rycee's NUR repository
# Reference: https://nur.nix-community.org/repos/rycee/
# Add to flake.nix inputs:
# firefox-addons = {
#   url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
#   inputs.nixpkgs.follows = "nixpkgs";
# };
{
  inputs,
  pkgs,
  ...
}: let
  firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in {
  programs.zen-browser.profiles.default.extensions.packages = with firefox-addons; [
    ublock-origin
    dearrow
    proton-pass
    vimium-ff
  ];
}
