import ../lib/user-js-preset.nix {
  name = "arkenfox";
  owner = "Arkenfox";
  repo = "user.js";
  userJsPath = "user.js";
  description = ''
    Enable the Arkenfox preset (arkenfox/user.js):
    Every pref is applied with `mkDefault`, so any `settings` entry on the profile overrides the preset.
    Disabling the preset resets the prefs it left in prefs.js.
  '';
}
