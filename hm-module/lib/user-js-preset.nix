# Factory for user.js-based presets (arkenfox, betterfox): fetches the
# pinned source (sources.json `addons.<name>`), parses its user.js into
# per-pref `settings` values and registers the pref names on the
# `presets.managedPrefNames` bus so the cleanup engine resets them when
# the preset is disabled.
#
# Prefs land in the upstream `settings` option as per-pref mkDefault
# values instead of being appended through extraConfig: extraConfig lands
# after the settings-generated prefs in user.js, where the last write
# wins, so raw text would silently override the profile's own `settings`.
# With mkDefault any profiles.<name>.settings entry beats the preset.
{
  name,
  owner,
  repo,
  userJsPath,
  description,
}: {self}: {
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

  src = pkgs.fetchFromGitHub {
    inherit (sources.addons.${name}) rev hash;
    inherit owner repo;
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
      then throw "presets.${name}: unparseable user_pref line in ${userJsPath}: ${line}"
      else [];
  in
    builtins.listToAttrs (lib.concatMap toPref (lib.splitString "\n" (builtins.readFile file)));

  presetPrefs = parseUserJs "${src}/${userJsPath}";
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options.presets.${name}.enable = mkOption {
                type = bool;
                default = false;
                inherit description;
              };

              config = mkIf config.presets.${name}.enable {
                settings = lib.mapAttrs (_: mkDefault) presetPrefs;
                presets.managedPrefNames = builtins.attrNames presetPrefs;
              };
            }
          )
        );
    };
  };
}
