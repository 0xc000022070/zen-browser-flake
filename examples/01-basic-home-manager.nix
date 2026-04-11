# Add to your flake.nix inputs:
# inputs.zen-browser = {
#   url = "github:0xc000022070/zen-browser-flake";
#   inputs = {
#     nixpkgs.follows = "nixpkgs";
#     home-manager.follows = "home-manager";
#   };
# };
# In your home.nix:
{inputs, ...}: {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };
}
