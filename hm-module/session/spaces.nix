# Space-scoped pins (`spaces.*.pins`) and live folders (`spaces.*.liveFolders`)
# desugar into the flat `pins` / `liveFolders` options with `workspace` preset,
# so they inherit every producer behavior (placeholders, folders, pinsForce
# accounting, the zen-live-folders writer) for free.
{lib, ...}: let
  inherit (lib) isPath mkOption setAttrByPath types;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  pinModule = import ../lib/pin-options.nix {
    inherit lib;
    includeWorkspace = false;
  };

  liveFolderModule = import ../lib/live-folder-options.nix {
    inherit lib;
    includeWorkspace = false;
  };
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {config, ...}: {
              options = {
                spacesForce = mkOption {
                  type = bool;
                  description = "Whether to delete existing spaces not declared in the configuration.";
                  default = false;
                };
                spaces = mkOption {
                  type = attrsOf (
                    submodule (
                      {name, ...}: {
                        options = {
                          name = mkOption {
                            type = str;
                            description = "Name of the space.";
                            default = name;
                          };
                          id = mkOption {
                            type = str;
                            description = "REQUIRED. Unique Version 4 UUID for space.";
                          };
                          position = mkOption {
                            type = ints.unsigned;
                            description = "Position of space in the left bar.";
                            default = 1000;
                          };
                          icon = mkOption {
                            type = nullOr (either str path);
                            description = "Emoji or icon URI to be used as space icon.";
                            apply = v:
                              if isPath v
                              then "file://${v}"
                              else v;
                            default = null;
                          };
                          container = mkOption {
                            type = nullOr ints.unsigned;
                            description = "Container ID to be used in space";
                            default = null;
                          };
                          pins = mkOption {
                            type = attrsOf (submodule pinModule);
                            description = ''
                              Pins scoped to this space. Same options as `pins.*` except
                              `workspace`, which is set to this space's `id` automatically.
                            '';
                            default = {};
                          };
                          liveFolders = mkOption {
                            type = attrsOf (submodule liveFolderModule);
                            description = ''
                              Live folders scoped to this space. Same options as `liveFolders.*`
                              except `workspace`, which is set to this space's `id` automatically.
                            '';
                            default = {};
                          };
                          theme.type = mkOption {
                            type = nullOr str;
                            default = "gradient";
                          };
                          theme.colors = mkOption {
                            type = nullOr (
                              listOf (
                                submodule (
                                  {...}: {
                                    options = {
                                      red = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      green = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      blue = mkOption {
                                        type = ints.between 0 255;
                                        default = 0;
                                      };
                                      custom = mkOption {
                                        type = bool;
                                        default = false;
                                      };
                                      algorithm = mkOption {
                                        type = enum [
                                          "complementary"
                                          "floating"
                                          "analogous"
                                        ];
                                        default = "floating";
                                      };
                                      primary = mkOption {
                                        type = bool;
                                        default = true;
                                      };
                                      lightness = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      position.x = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      position.y = mkOption {
                                        type = int;
                                        default = 0;
                                      };
                                      type = mkOption {
                                        type = enum [
                                          "undefined"
                                          "explicit-lightness"
                                        ];
                                        default = "undefined";
                                      };
                                    };
                                  }
                                )
                              )
                            );
                            default = [];
                          };
                          theme.opacity = mkOption {
                            type = nullOr float;
                            default = 0.5;
                          };
                          theme.rotation = mkOption {
                            type = nullOr int;
                            default = null;
                          };
                          theme.texture = mkOption {
                            type = nullOr float;
                            default = 0.0;
                          };
                        };
                      }
                    )
                  );
                  default = {};
                };
              };

              config = let
                inherit (builtins) isNull;
                inherit (lib) flatten listToAttrs mapAttrsToList nameValuePair;
              in {
                sessionStore.spaces =
                  mapAttrsToList (
                    _: s: {
                      uuid = "{${s.id}}";
                      inherit (s) name position;
                      icon = s.icon;
                      containerTabId =
                        if isNull s.container
                        then 0
                        else s.container;
                      theme = {
                        type =
                          if isNull s.theme.type
                          then "gradient"
                          else s.theme.type;
                        gradientColors =
                          if isNull s.theme.colors
                          then []
                          else
                            (map (c: {
                                inherit (c) algorithm lightness position type;
                                c = [c.red c.green c.blue];
                                isCustom = c.custom;
                                isPrimary = c.primary;
                              })
                              s.theme.colors);
                        opacity =
                          if isNull s.theme.opacity
                          then 0.5
                          else s.theme.opacity;
                        rotation = s.theme.rotation;
                        texture =
                          if isNull s.theme.texture
                          then 0
                          else s.theme.texture;
                      };
                      hasCollapsedPinnedTabs = false;
                    }
                  )
                  config.spaces;

                pins = listToAttrs (flatten (mapAttrsToList (
                    spaceName: s:
                      mapAttrsToList (
                        pinName: p:
                          nameValuePair "spaces/${spaceName}/${pinName}" (p // {workspace = s.id;})
                      )
                      s.pins
                  )
                  config.spaces));

                liveFolders = listToAttrs (flatten (mapAttrsToList (
                    spaceName: s:
                      mapAttrsToList (
                        lfName: lf:
                          nameValuePair "spaces/${spaceName}/${lfName}" (lf // {workspace = s.id;})
                      )
                      s.liveFolders
                  )
                  config.spaces));
              };
            }
          )
        );
    };
  };
}
