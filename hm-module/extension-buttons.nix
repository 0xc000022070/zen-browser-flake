# Merges extension toolbar buttons into the `browser.uiCustomization.state`
# line of the browser-owned prefs.js: that pref is a single JSON blob
# covering every toolbar area at once, and any area left out of it falls
# back to CustomizableUI's compiled-in defaults, so it cannot be declared
# through `settings`/user.js.
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

  toWidgetId = import ./lib/widget-id.nix {inherit lib;};
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                extensionButtons = mkOption {
                  type = attrsOf (listOf str);
                  default = {};
                  example = lib.literalExpression ''
                    {
                      "nav-bar" = ["uBlock0@raymondhill.net"];
                      "unified-extensions-area" = ["addon@darkreader.org"];
                    }
                  '';
                  description = ''
                    Extension ids to place in each toolbar area, appended in the
                    listed order; `nav-bar` is the toolbar itself.
                  '';
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    programs.zen-browser.activationFragments = let
      inherit (builtins) toJSON;
      inherit (lib) getExe mapAttrs' mapAttrs nameValuePair;
    in
      mapAttrs' (
        profileName: profile: let
          profileDir = "${cfg.profilesPath}/${profile.path}";

          declaredFile =
            pkgs.writeText "zen-extension-buttons-${profileName}.json"
            (toJSON (mapAttrs (_: map toWidgetId) profile.extensionButtons));

          jqFilterFile = pkgs.writeText "zen-extension-buttons-${profileName}.jq" ''
            fromjson as $state
            | $declared[0] as $decl
            | ($managed[0] // []) as $managedIds
            | ($state.placements // {}) as $existing
            | ($decl | with_entries(select(.key as $a | $existing | has($a)))) as $applicable
            | [$applicable[] | .[]] as $placedIds
            | ($managedIds - [$decl[] | .[]]) as $stale
            | ($placedIds + $stale) as $detach
            | ($existing
               | with_entries(.value |= map(. as $w | select($detach | index($w) | not)))) as $detached
            | (reduce ($applicable | to_entries[]) as $e ($detached;
                 .[$e.key] += $e.value)) as $placed
            | ($placed | has("unified-extensions-area")) as $hasPanel
            | (($stale | length) > 0) as $hasStale
            | (if $hasStale and $hasPanel
               then $placed | .["unified-extensions-area"] += $stale
               else $placed end) as $finalPlacements
            | ((($state.seen // []) + $placedIds)
               | (if $hasPanel then . else . - $stale end)
               | unique) as $seen
            | ((($state.dirtyAreaCache // [])
                + ($applicable | keys)
                + (if $hasStale and $hasPanel then ["unified-extensions-area"] else [] end))
               | unique) as $dirty
            | $state
            | .placements = $finalPlacements
            | .seen = $seen
            | .dirtyAreaCache = $dirty
            | tojson
            | tojson
          '';

          updateScript =
            pkgs.writeShellScript "zen-extension-buttons-update-${profileName}"
            ''
              PROFILE_DIR="${profileDir}"
              PREFS_FILE="$PROFILE_DIR/prefs.js"
              MANAGED_FILE="$PROFILE_DIR/zen-extension-buttons-nix-managed.json"
              DECLARED_FILE="${declaredFile}"
              LOCK_FILE="${profileDir}/.parentlock"
              BACKUP_FILE="$PREFS_FILE.nix-extension-buttons.bak"
              PREF_NAME="browser.uiCustomization.state"

              MANAGED_TMP=""
              PREFS_TMP=""

              cleanup() {
                rm -f ''${MANAGED_TMP:+"$MANAGED_TMP"} ''${PREFS_TMP:+"$PREFS_TMP"}
              }

              trap cleanup EXIT

              [ -d "$PROFILE_DIR" ] || exit 0

              DECLARED_EMPTY="$(${getExe pkgs.jq} -r '[.[] | .[]] | length == 0' "$DECLARED_FILE")"
              if [ ! -f "$MANAGED_FILE" ] && [ "$DECLARED_EMPTY" = "true" ]; then
                exit 0
              fi

              if "${getExe pkgs.lsof}" "$LOCK_FILE" >/dev/null 2>&1; then
                echo "zen-extension-buttons: Zen Browser appears to be running; skipping extension button placement."
                echo "zen-extension-buttons: Close Zen Browser and rebuild to apply it."
                exit 0
              fi

              if [ ! -f "$PREFS_FILE" ] || ! LINE="$(grep -m1 "^user_pref(\"$PREF_NAME\", " "$PREFS_FILE")"; then
                echo "zen-extension-buttons: Zen has not saved a toolbar layout for profile '${profileName}' yet."
                echo "zen-extension-buttons: Launch Zen once, close it and rebuild to place the buttons."
                exit 0
              fi

              VALUE="''${LINE#user_pref(\"$PREF_NAME\", }"
              VALUE="''${VALUE%);}"

              MISSING="$(printf '%s' "$VALUE" | ${getExe pkgs.jq} -r \
                --slurpfile declared "$DECLARED_FILE" '
                  fromjson
                  | (.placements // {}) as $pl
                  | $declared[0]
                  | keys[]
                  | . as $a
                  | select($pl | has($a) | not)')" || MISSING=""

              for area in $MISSING; do
                echo "zen-extension-buttons: '$area' is not part of the saved toolbar layout; skipping its buttons."
              done

              MANAGED_TMP="$(mktemp)"
              if [ -f "$MANAGED_FILE" ]; then
                cp "$MANAGED_FILE" "$MANAGED_TMP"
              else
                echo '[]' > "$MANAGED_TMP"
              fi

              NEW_VALUE="$(printf '%s' "$VALUE" | ${getExe pkgs.jq} -r \
                --slurpfile declared "$DECLARED_FILE" \
                --slurpfile managed "$MANAGED_TMP" \
                -f ${jqFilterFile})" || {
                echo "zen-extension-buttons: Failed to apply modifications to $PREF_NAME"
                exit 1
              }

              NEW_LINE="user_pref(\"$PREF_NAME\", $NEW_VALUE);"

              if [ "$NEW_LINE" != "$LINE" ]; then
                cp "$PREFS_FILE" "$BACKUP_FILE" || {
                  echo "zen-extension-buttons: Failed to create backup of $PREFS_FILE"
                  exit 1
                }

                PREFS_TMP="$(mktemp)"
                while IFS= read -r prefline; do
                  if [ "$prefline" = "$LINE" ]; then
                    printf '%s\n' "$NEW_LINE"
                  else
                    printf '%s\n' "$prefline"
                  fi
                done < "$PREFS_FILE" > "$PREFS_TMP"

                mv "$PREFS_TMP" "$PREFS_FILE" || {
                  echo "zen-extension-buttons: Failed to update $PREFS_FILE, restoring backup"
                  mv "$BACKUP_FILE" "$PREFS_FILE"
                  exit 1
                }
                PREFS_TMP=""
                rm -f "$BACKUP_FILE"
              fi

              rm -f "$MANAGED_FILE"
              if [ "$DECLARED_EMPTY" != "true" ]; then
                ${getExe pkgs.jq} -S '[.[] | .[]] | unique' "$DECLARED_FILE" > "$MANAGED_FILE" || {
                  echo "zen-extension-buttons: Failed to write $MANAGED_FILE"
                  exit 1
                }
              fi
            '';
        in
          nameValuePair profileName [
            {
              priority = 50;
              requiresLock = true;
              skipSubject = "extension buttons";
              text = ''
                ${updateScript}
                if [[ "$?" -eq 0 ]]; then
                  $VERBOSE_ECHO "zen-extension-buttons: Updated extension buttons for profile '${profileName}'"
                else
                  echo "zen-extension-buttons: Failed to place extension buttons for profile '${profileName}'!" >&2
                fi
              '';
            }
          ]
      )
      cfg.profiles;
  };
}
