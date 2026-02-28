{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mapAttrsToList mkIf mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;

  linuxConfigPath = "${config.xdg.configHome}/zen";
  darwinConfigPath = "${config.home.homeDirectory}/Library/Application Support/Zen";

  profilePath =
    if pkgs.stdenv.isDarwin
    then "${darwinConfigPath}/Profiles"
    else linuxConfigPath;

  flavors = ["Frappe" "Latte" "Macchiato" "Mocha"];
  accents = [
    "Blue"
    "Flamingo"
    "Green"
    "Lavender"
    "Maroon"
    "Mauve"
    "Peach"
    "Pink"
    "Red"
    "Rosewater"
    "Sapphire"
    "Sky"
    "Teal"
    "Yellow"
  ];
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                presets = {
                  catppuccin = {
                    enable = mkOption {
                      type = bool;
                      default = false;
                      description = "Enable Catppuccin theme for this profile. Copies the theme from catppuccin/zen-browser into the profile's chrome directory.";
                    };
                    flavor = mkOption {
                      type = enum flavors;
                      default = "Mocha";
                      description = "Catppuccin flavor (base palette).";
                    };
                    accent = mkOption {
                      type = enum accents;
                      default = "Mauve";
                      description = "Catppuccin accent color for the theme.";
                    };
                  };
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    home.file = let
      profilesWithCatppuccin =
        lib.filterAttrs
        (_: p: (p.presets.catppuccin or {}).enable or false)
        cfg.profiles;
    in
      lib.mkIf ((lib.length (lib.attrNames profilesWithCatppuccin)) > 0) (let
        catppuccinZen = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "zen-browser";
          rev = "c855685442c6040c4dda9c8d3ddc7b708de1cbaa";
          hash = "sha256-5A57Lyctq497SSph7B+ucuEyF1gGVTsuI3zuBItGfg4=";
        };
      in
        lib.mkMerge (
          mapAttrsToList
          (profileName: profile: let
            ctp = profile.presets.catppuccin or {};
            flavor = ctp.flavor or "Mocha";
            accent = ctp.accent or "Mauve";
            themeSource = "${catppuccinZen}/themes/${flavor}/${accent}";
            chromePath =
              lib.removePrefix "${config.home.homeDirectory}/"
              "${profilePath}/${profileName}/chrome";
          in {
            "${chromePath}" = {
              source = themeSource;
              recursive = true;
              force = true;
            };
          })
          profilesWithCatppuccin
        ));
  };
}
