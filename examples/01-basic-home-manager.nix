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

    # Catppuccin theme (catppuccin/zen-browser), symlinked into the profile's
    # chrome/catppuccin and loaded via userChrome/userContent imports.
    profiles.default.presets.catppuccin = {
      enable = true;
      flavor = "Mocha"; # Frappe | Latte | Macchiato | Mocha
      accent = "Mauve"; # Blue, Flamingo, Green, Lavender, Maroon, Mauve, ...
    };

    # Betterfox for Zen (yokoffing/Betterfox zen/user.js, aka BetterZen):
    # privacy/telemetry/performance prefs applied as mkDefault settings —
    # any profile `settings` entry wins.
    profiles.default.presets.betterfox.enable = true;
  };
}
