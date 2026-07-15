# Betterfox preset (yokoffing/Betterfox zen/user.js aka BetterZen, pinned in
# sources.json):
# the Betterfox privacy/performance prefs Zen does not ship by default.
# The user.js is parsed into the upstream `settings` option as per-pref
# mkDefault values instead of being appended through extraConfig: extraConfig
# lands after the settings-generated prefs in user.js, where the last write
# wins, so raw text would silently override the profile's own `settings`.
# With mkDefault any profiles.<name>.settings entry beats the preset.
{self}: {
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  sources = builtins.fromJSON (builtins.readFile "${self}/sources.json");

  betterfox = pkgs.fetchFromGitHub {
    inherit (sources.addons.betterfox) rev hash;
    repo = "Betterfox";
    owner = "yokoffing";
  };

  # Every active line is `user_pref("<name>", <value>);` with an optional
  # trailing `//` comment; values are JSON-compatible (string/int/bool).
  # A user_pref line the full pattern cannot parse throws instead of being
  # dropped, so an upstream syntax change fails loudly at eval.
  parseUserJs = file: let
    prefLine = ''[[:space:]]*user_pref\(.*'';
    fullLine = ''[[:space:]]*user_pref\("([^"]+)",[[:space:]]*("[^"]*"|-?[0-9]+|true|false)\);[[:space:]]*(//.*)?'';

    toPref = line: let
      m = builtins.match fullLine line;
    in
      if m != null
      then [(lib.nameValuePair (builtins.elemAt m 0) (builtins.fromJSON (builtins.elemAt m 1)))]
      else if builtins.match prefLine line != null
      then throw "presets.betterfox: unparseable user_pref line in zen/user.js: ${line}"
      else [];
  in
    builtins.listToAttrs (lib.concatMap toPref (lib.splitString "\n" (builtins.readFile file)));

  betterfoxPrefs = parseUserJs "${betterfox}/zen/user.js";
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                presets.betterfox.enable = mkOption {
                  type = bool;
                  default = false;
                  description = ''
                    Enable the Betterfox preset (yokoffing/Betterfox `zen/user.js`, aka BetterZen):
                    Betterfox privacy, telemetry and performance prefs that Zen does
                    not ship by default. Every pref is applied with `mkDefault`, so
                    any `settings` entry on the profile overrides the preset.
                  '';
                };
              };

              config = mkIf config.presets.betterfox.enable {
                settings = lib.mapAttrs (_: mkDefault) betterfoxPrefs;
              };
            }
          )
        );
    };
  };
}
