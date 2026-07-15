# Writes zen-space-routing.jsonlz4: URL->space routing rules plus the
# global default route for external links. Independent of zen-sessions;
# `openIn`/`defaultExternalRoute` reference space ids (brace-wrapped to
# match Zen's internal workspace uuid) or the literal "most-recent-space".
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

  mkJsonlz4Updater = import ../lib/state-writer.nix {inherit pkgs lib;};
  routeModule = import ../lib/route-options.nix {inherit lib;};

  # A space id becomes braced "{uuid}"; the sentinel passes through.
  braceSpace = v:
    if v == "most-recent-space"
    then v
    else "{${v}}";
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options.spaceRouting = {
                force = mkOption {
                  type = bool;
                  default = false;
                  description = "Whether to delete existing routes not declared in the configuration.";
                };
                defaultExternalRoute = mkOption {
                  type = nullOr str;
                  default = null;
                  description = ''
                    Default route for external links (opened from outside the
                    browser) when no rule matches: a space id, or
                    `"most-recent-space"`. `null` leaves whatever Zen has set.
                  '';
                };
                routes = mkOption {
                  type = attrsOf (submodule routeModule);
                  default = {};
                  description = "URL->space routing rules.";
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    home.activation = let
      inherit (builtins) toJSON;
      inherit (lib) attrValues boolToString filterAttrs getExe mapAttrs' nameValuePair;

      profilesWithRouting =
        filterAttrs (
          _: profile:
            profile.spaceRouting.routes != {} || profile.spaceRouting.defaultExternalRoute != null
        )
        cfg.profiles;
    in
      mapAttrs' (
        profileName: profile: let
          routingFile = "${cfg.profilesPath}/${profile.path}/zen-space-routing.jsonlz4";

          sr = profile.spaceRouting;
          manageDefault = sr.defaultExternalRoute != null;

          declaredJson = toJSON {
            routes =
              map (r: {
                inherit (r) id reference matchType;
                openIn = braceSpace r.openIn;
              })
              (attrValues sr.routes);
            defaultRouteExternal =
              if manageDefault
              then braceSpace sr.defaultExternalRoute
              else "most-recent-space";
          };

          declaredJsonFile = pkgs.writeText "zen-declared-space-routing-${profileName}.json" declaredJson;

          # Merge by route id (declared wins), append unknown ids; force prunes
          # undeclared routes. defaultRouteExternal is replaced only when managed,
          # otherwise the browser's value is preserved.
          jqFilterFile = pkgs.writeText "zen-space-routing-filter-${profileName}.jq" ''
            ($declaredRouting[0]) as $decl |
            (if type == "object" then . else {} end) as $existing |
            ($existing.routes // []) as $eRoutes |
            $decl.routes as $dRoutes |
            [$eRoutes[].id] as $eIds |
            {
              routes: (
                [$eRoutes[] |
                  . as $e |
                  ($dRoutes | map(select(.id == $e.id)) | .[0] // null) as $o |
                  if $o != null then ($e * $o)
                  else (if ${boolToString sr.force} then empty else . end) end
                ] + [$dRoutes[] | select(.id as $id | $eIds | index($id) | not)]
              ),
              defaultRouteExternal: (
                if ${boolToString manageDefault} then $decl.defaultRouteExternal
                else ($existing.defaultRouteExternal // "most-recent-space") end
              )
            }
          '';

          updateScript = mkJsonlz4Updater {
            name = "zen-space-routing-update-${profileName}";
            logPrefix = "zen-space-routing";
            subject = "space routing";
            skipSubject = "space routing";
            stateFile = routingFile;
            lockFile = "${cfg.profilesPath}/${profile.path}/.parentlock";
            slurpfiles = {
              declaredRouting = declaredJsonFile;
            };
            inherit jqFilterFile;
            postLockChecks = ''
              if [ ! -f "$STATE_FILE" ]; then
                ${getExe pkgs.mozlz4a} ${declaredJsonFile} "$STATE_FILE" || {
                  echo "zen-space-routing: Failed to create $STATE_FILE"
                  exit 1
                }
                exit 0
              fi
            '';
          };
        in
          nameValuePair "zen-space-routing-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"]
            ''
              ${updateScript}
              if [[ "$?" -eq 0 ]]; then
                $VERBOSE_ECHO "zen-space-routing: Updated space routing for profile '${profileName}'"
              else
                YELLOW="\033[1;33m"
                NC="\033[0m"
                echo -e "zen-space-routing:''${YELLOW} Failed to update zen-space-routing.jsonlz4 for Zen browser \"${profileName}\" profile.''${NC}"
                echo -e "zen-space-routing:''${YELLOW} If Zen Browser was open, close it and rebuild to apply changes.''${NC}"
              fi
            '')
      )
      profilesWithRouting;
  };
}
