# Zen writes profiles.ini at startup and on Darwin skips the profile when the
# upstream store symlink is read-only (#285), so ship a 0644 copy instead.
{
  config,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath hasPrefix mkForce mkIf;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  fileKey = "${cfg.configPath}/profiles.ini";
  target =
    if hasPrefix "/" fileKey
    then fileKey
    else "${config.home.homeDirectory}/${fileKey}";
  source = config.home.file.${fileKey}.source;
in {
  config = mkIf (cfg.enable && cfg.profiles != {}) {
    home.file.${fileKey}.enable = mkForce false;

    home.activation.zen-browser-profiles-ini = lib.hm.dag.entryAfter ["linkGeneration"] ''
      profilesIni=${lib.escapeShellArg target}
      if [ -L "$profilesIni" ] || ! cmp -s ${source} "$profilesIni"; then
        run mkdir -p "$(dirname "$profilesIni")"
        run rm -f "$profilesIni"
        run install -m 0644 ${source} "$profilesIni"
      fi
    '';
  };
}
