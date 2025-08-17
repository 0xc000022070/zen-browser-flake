{
  home-manager,
  self,
  name,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    getAttrFromPath
    isPath
    mkIf
    mkOption
    setAttrByPath
    types
    ;

  cfg = getAttrFromPath modulePath config;

  applicationName = "Zen Browser";
  modulePath = [
    "programs"
    "zen-browser"
  ];

  linuxConfigPath = ".zen";
  darwinConfigPath = "Library/Application Support/Zen";

  configPath = "${config.home.homeDirectory}/${(
    if pkgs.stdenv.isDarwin
    then darwinConfigPath
    else linuxConfigPath
  )}";

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "zen-${name}-unwrapped";
      unwrappedPackageName = "zen-${name}";
      visible = true;
      platforms = {
        linux = {
          vendorPath = linuxConfigPath;
          configPath = linuxConfigPath;
        };
        darwin = {
          configPath = darwinConfigPath;
        };
      };
    })
  ];

  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (submodule ({...}: {
          options = {
            spaces = mkOption {
              type = attrsOf (submodule ({name, ...}: {
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
                };
              }));
              default = {};
            };
          };
        }));
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package =
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.system}."${name}-unwrapped".override {
          # Seems like zen uses relative (to the original binary) path to the policies.json file
          # and ignores the overrides by pkgs.wrapFirefox
          policies = cfg.policies;
        }) {}).override
        {
          nativeMessagingHosts = cfg.nativeMessagingHosts;
        };

      # This does not work, the package can't build using these policies
      policies = lib.mkDefault {
        DisableAppUpdate = true;
        DisableTelemetry = true;
      };
    };

    systemd.user.services."zen-browser-spaces-activation" = let
      inherit
        (lib)
        attrByPath
        concatMapStringsSep
        concatStringsSep
        elemAt
        filterAttrs
        getExe
        getExe'
        isAttrs
        isList
        isStringLike
        lists
        mapAttrsToList
        toJSON
        pipe
        ;

      hasSpaces = pipe cfg.profiles [
        (mapAttrsToList (n: v: v.spaces != {}))
        (lists.any (v: v))
      ];

      # Reference: https://github.com/zen-browser/desktop/blob/4e2dfd8a138fd28767bb4799a3ca9d8aab80430e/src/zen/workspaces/ZenWorkspacesStorage.mjs#L25-L55
      initSpacesTable = pkgs.writeText "init.sql" ''
        CREATE TABLE IF NOT EXISTS zen_workspaces (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          icon TEXT,
          container_id INTEGER,
          position INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      '';

      # Source: https://github.com/zen-browser/desktop/blob/4e2dfd8a138fd28767bb4799a3ca9d8aab80430e/src/zen/workspaces/ZenWorkspacesStorage.mjs#L141-L149
      updateSpacesTable = spaces:
        pkgs.writeText "insert.sql" ''
          INSERT OR REPLACE INTO zen_workspaces (
            uuid,
            name,
            icon,
            container_id,
            "position",

            created_at,
            updated_at
          ) VALUES ${pipe spaces [
            (mapAttrsToList (_: space: [
              "{${space.id}}"
              space.name
              (attrByPath ["icon"] null space)
              (attrByPath ["container"] null space)
              (attrByPath ["position"] 0 space)
            ]))
            (map (row:
              map (
                v:
                  if isStringLike v
                  then "'${v}'"
                  else if (isList v) || (isAttrs v)
                  then "'${toJSON v}'"
                  else if isNull v
                  then "NULL"
                  else builtins.toString v
              )
              row))
            (map (row:
              row
              ++ [
                "COALESCE((SELECT created_at FROM zen_workspaces WHERE uuid = ${elemAt row 0}), strftime('%s', 'now'))"
                "strftime('%s', 'now')"
              ]))
            (map (row: concatStringsSep "," row))
            (concatMapStringsSep "," (row: "(${row})"))
          ]}
        '';
    in
      mkIf hasSpaces {
        Install.WantedBy = ["default.target"];
        Unit.After = ["home-manager-${config.home.username}.service"];
        Service = {
          Type = "oneshot";
          ExecStart = let
            sqlite3 = getExe' pkgs.sqlite "sqlite3";
          in
            pipe cfg.profiles [
              (filterAttrs (_: v: v.spaces != {}))
              (mapAttrsToList (n: v: (pkgs.writeShellScriptBin "zen-browser-spaces-${n}" ''
                mkdir -p "${configPath}/${n}"
                ${sqlite3} "${configPath}/${n}/places.sqlite" ".read ${initSpacesTable}"
                ${sqlite3} "${configPath}/${n}/places.sqlite" ".read ${updateSpacesTable v.spaces}"
              '')))
              (list: map (pkg: getExe pkg) list)
            ];
        };
      };
  };
}
