# Declarative mod installation through Sine (Linux only)
# Mod IDs are the directory names under https://github.com/sineorg/store/tree/main/mods
{
  programs.zen-browser.profiles.default = {
    sine.enable = true;

    sine.mods = [
      "Arc-2.0"
    ];
  };
}
# sine.enable installs the Sine engine and its autoconfig loader.
# sine.mods is fetched at activation, so mods refresh on `home-manager switch`
# rather than by Sine's own updater, which is disabled for managed mods.
#
# A mod ID missing from the Sine store falls back to the vanilla Zen theme
# store. If neither responds, the installed copy is kept and a warning printed.
#
# Mod preference defaults are applied on startup, so a mod renders as its author
# intended without opening about:preferences first. Anything changed later in
# Sine's settings UI overrides them and survives switches.
#
# sine.enable conflicts with the `mods` option (see 05-mods-installation.nix);
# pick one per profile. Note: browser must be restarted for changes to take effect.

