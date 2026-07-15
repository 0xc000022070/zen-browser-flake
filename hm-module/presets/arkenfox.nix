# Arkenfox preset (pinned in sources.json):
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

  arkenfox = pkgs.fetchFromGitHub {
    inherit (sources.addons.arkenfox) rev hash;
    repo = "user.js";
    owner = "Arkenfox";
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
      then throw "presets.arkenfox: unparseable user_pref line in zen/user.js: ${line}"
      else [];
  in
    builtins.listToAttrs (lib.concatMap toPref (lib.splitString "\n" (builtins.readFile file)));

  arkenfoxPrefs = parseUserJs "${arkenfox}/zen/user.js";
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                presets.arkenfox.enable = mkOption {
                  type = bool;
                  default = false;
                  description = ''
                    Enable the Arkenfox preset (arkenfox/users.js `zen/user.js`):
                    Every pref is applied with `mkDefault`, so any `settings` entry on the profile overrides the preset.
                  '';
                };
              };

              config = mkIf config.presets.arkenfox.enable {
                settings = lib.mapAttrs (_: mkDefault) arkenfoxPrefs;
              };
            }
          )
        );
    };
  };
}
