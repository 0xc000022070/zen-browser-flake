# Single per-profile activation entry. Modules contribute ordered
# fragments to the internal `activationFragments` bus instead of
# registering their own home.activation entries; the runner declared
# here executes them under one "zen-browser-<profile>" entry, doing the
# browser-running profile-lock check once for all fragments that need
# it and printing a single consolidated skip message. Fragments with
# `requiresLock` keep their own inner lock check as a race guard only.
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;
in {
  options = setAttrByPath modulePath {
    activationFragments = mkOption {
      type = with types;
        attrsOf (listOf (submodule {
          options = {
            priority = mkOption {
              type = int;
              default = 100;
              description = "Run order within the profile's entry (lower first).";
            };
            requiresLock = mkOption {
              type = bool;
              default = false;
              description = "Skip this fragment when the profile lock is held.";
            };
            skipSubject = mkOption {
              type = nullOr str;
              default = null;
              description = "Noun listed in the consolidated browser-running skip message.";
            };
            text = mkOption {
              type = lines;
              description = "Shell fragment run inside the profile's activation entry.";
            };
          };
        }));
      internal = true;
      visible = false;
      default = {};
      description = "Activation fragments keyed by profile name.";
    };
  };

  config = mkIf cfg.enable {
    home.activation = let
      inherit (builtins) concatStringsSep filter map;
      inherit (lib) concatMapStringsSep filterAttrs mapAttrs' nameValuePair optionalString sort unique;
    in
      mapAttrs' (
        profileName: fragments: let
          sorted = sort (a: b: a.priority < b.priority) fragments;
          unguarded = filter (f: !f.requiresLock) sorted;
          guarded = filter (f: f.requiresLock) sorted;
          skipSubjects = concatStringsSep ", " (unique (filter (s: s != null) (map (f: f.skipSubject) guarded)));
          lockFile = "${cfg.profilesPath}/${cfg.profiles.${profileName}.path}/.parentlock";
        in
          nameValuePair "zen-browser-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"] ''
            ${concatMapStringsSep "\n" (f: f.text) unguarded}
            ${optionalString (guarded != []) ''
              if ${lib.getExe pkgs.lsof} "${lockFile}" >/dev/null 2>&1; then
                echo "zen-browser: Zen Browser appears to be running; skipped: ${skipSubjects}."
                echo "zen-browser: Close Zen Browser and rebuild to apply those changes."
              else
                ${concatMapStringsSep "\n" (f: f.text) guarded}
              fi
            ''}
          '')
      )
      (filterAttrs (_: fragments: fragments != []) cfg.activationFragments);
  };
}
