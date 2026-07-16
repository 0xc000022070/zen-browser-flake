import ../lib/user-js-preset.nix {
  name = "betterfox";
  owner = "yokoffing";
  repo = "Betterfox";
  userJsPath = "zen/user.js";
  description = ''
    Enable the Betterfox preset (yokoffing/Betterfox `zen/user.js`, aka BetterZen):
    Betterfox privacy, telemetry and performance prefs that Zen does
    not ship by default. Every pref is applied with `mkDefault`, so
    any `settings` entry on the profile overrides the preset.
    Disabling the preset resets the prefs it left in prefs.js.
  '';
}
