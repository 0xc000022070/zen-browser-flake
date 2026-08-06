{mkSinePack}: {
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

  isSineEnabled = lib.any (profile: profile.sine.enable) (lib.attrValues cfg.profiles);
in {
  options = setAttrByPath modulePath {
    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {
                sine = {
                  enable = mkOption {
                    type = bool;
                    default = false;
                    description = "Enable sine option. When enabled, mods option is not allowed. Linux only.";
                  };
                  mods = mkOption {
                    type = listOf str;
                    default = [];
                    description = "List of mod IDs to install from the Sine store. Falls back to the Zen theme store if unavailable in the Sine store.";
                  };
                };
              };
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    home.file =
      if isSineEnabled
      then let
        sinePack = mkSinePack {};

        engineVersionFile =
          pkgs.runCommand "sine-engine.json" {
            nativeBuildInputs = [pkgs.jq];
          } ''
            jq '.updates[0]' ${sinePack.manager}/engine.json > $out
          '';
      in
        lib.concatMapAttrs (
          _: profile:
            if profile.sine.enable
            then {
              "${cfg.profilesPath}/${profile.path}/chrome/JS" = {
                source = sinePack.manager + "/src";
                recursive = true;
                force = true;
              };
              "${cfg.profilesPath}/${profile.path}/chrome/JS/locales" = {
                source = sinePack.manager + "/locales";
                recursive = true;
                force = true;
              };
              "${cfg.profilesPath}/${profile.path}/chrome/JS/engine.json" = {
                source = engineVersionFile;
                force = true;
              };
              "${cfg.profilesPath}/${profile.path}/chrome/utils" = {
                source = sinePack.bootloader + "/profile/utils";
                recursive = true;
                force = true;
              };
            }
            else {}
        )
        cfg.profiles
      else {};

    programs.zen-browser.activationFragments = let
      inherit
        (lib)
        filterAttrs
        mapAttrs'
        nameValuePair
        ;

      profilesWithSineMods =
        filterAttrs
        (_: profile: profile.sine.mods != [])
        cfg.profiles;
    in
      mapAttrs'
      (
        profileName: profile: let
          modsFilePath = "${cfg.profilesPath}/${profile.path}/chrome/sine-mods/mods.json";

          updateSineModsScript =
            pkgs.writeShellScript "zen-sine-mods-update-${profileName}"
            ''
              MODS_FILE="${modsFilePath}"
              SINE_MODS="${lib.concatStringsSep " " profile.sine.mods}"
              BASE_DIR="${cfg.profilesPath}/${profile.path}"
              MANAGED_FILE="$BASE_DIR/zen-sine-mods-nix-managed.json"

              mkdir -p "$BASE_DIR/chrome/sine-mods"

              if [ ! -f "$MODS_FILE" ]; then
                echo '{}' > "$MODS_FILE"
              fi

              if [ -f "$MANAGED_FILE" ]; then
                # Generations before mod updating stored a bare id array; the object
                # form pairs each id with the hash of what was installed.
                PREV_STATE=$(${lib.getExe pkgs.jq} -c '
                  if type == "array" then (map({(.): ""}) | add // {})
                  elif type == "object" then .
                  else {} end
                ' "$MANAGED_FILE" 2>/dev/null || echo "{}")
              else
                PREV_STATE="{}"
              fi

              for mod_id in $(echo "$PREV_STATE" | ${lib.getExe pkgs.jq} -r 'keys[]'); do
                if [[ " $SINE_MODS " != *" $mod_id "* ]]; then
                  ${lib.getExe pkgs.jq} "del(.[\"$mod_id\"])" "$MODS_FILE" > "$MODS_FILE.tmp" && mv "$MODS_FILE.tmp" "$MODS_FILE"
                  rm -rf "$BASE_DIR/chrome/sine-mods/$mod_id"
                  echo "Removed sine mod $mod_id"
                fi
              done

              NEW_STATE="{}"

              for mod_id in $SINE_MODS; do
                MOD_DIR="$BASE_DIR/chrome/sine-mods/$mod_id"
                STAGING="$BASE_DIR/chrome/sine-mods/.staging-$mod_id"
                PREV_HASH=$(echo "$PREV_STATE" | ${lib.getExe pkgs.jq} -r --arg id "$mod_id" '.[$id] // ""')

                rm -rf "$STAGING"
                CURRENT_HASH=""
                SYNCED=false
                CHANGED=false

                # Try Sine store first
                SINE_URL="https://raw.githubusercontent.com/sineorg/store/main/mods/$mod_id/mod.zip"
                TMPZIP=$(mktemp -d)
                echo "Fetching sine mod $mod_id from Sine store..."

                if ${lib.getExe pkgs.curl} -sfL "$SINE_URL" -o "$TMPZIP/mod.zip" 2>/dev/null; then
                  CURRENT_HASH=$(sha256sum "$TMPZIP/mod.zip" | cut -c1-64)

                  mkdir -p "$STAGING/extracted" "$STAGING/mod"

                  if [ -d "$MOD_DIR" ] && [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
                    SYNCED=true
                  elif ${lib.getExe pkgs.unzip} -o "$TMPZIP/mod.zip" -d "$STAGING/extracted" >/dev/null 2>&1; then
                    ITEMS=("$STAGING/extracted"/*)
                    if [ ''${#ITEMS[@]} -eq 1 ] && [ -d "''${ITEMS[0]}" ]; then
                      cp -r "''${ITEMS[0]}"/* "$STAGING/mod/" 2>/dev/null || true
                      cp -r "''${ITEMS[0]}"/.* "$STAGING/mod/" 2>/dev/null || true
                    else
                      cp -r "$STAGING/extracted"/* "$STAGING/mod/" 2>/dev/null || true
                    fi
                    SYNCED=true
                    CHANGED=true
                  fi
                fi

                rm -rf "$TMPZIP"

                if [ "$SYNCED" = false ]; then
                  echo "Sine store unavailable for $mod_id, trying vanilla Zen theme store..."
                  THEME_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_id/theme.json"

                  THEME_JSON=$(${lib.getExe pkgs.curl} -sfL "$THEME_URL")
                  if [ -n "$THEME_JSON" ] && echo "$THEME_JSON" | ${lib.getExe pkgs.jq} empty 2>/dev/null; then
                    CURRENT_HASH=$(printf '%s' "$THEME_JSON" | sha256sum | cut -c1-64)

                    if [ -d "$MOD_DIR" ] && [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
                      SYNCED=true
                    else
                      mkdir -p "$STAGING/mod"
                      echo "$THEME_JSON" > "$STAGING/mod/theme.json"

                      for file in chrome.css preferences.json readme.md; do
                        FILE_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_id/$file"
                        ${lib.getExe pkgs.curl} -sfL "$FILE_URL" -o "$STAGING/mod/$file" || rm -f "$STAGING/mod/$file"
                      done

                      SYNCED=true
                      CHANGED=true
                    fi
                  fi
                fi

                if [ "$CHANGED" = true ]; then
                  # Same-directory rename, so a torn write cannot leave a half mod behind.
                  rm -rf "$MOD_DIR"
                  mv "$STAGING/mod" "$MOD_DIR"
                  if [ -n "$PREV_HASH" ]; then
                    echo "Updated sine mod $mod_id"
                  else
                    echo "Installed sine mod $mod_id"
                  fi
                fi

                rm -rf "$STAGING"

                if [ "$SYNCED" = false ]; then
                  if [ -d "$MOD_DIR" ]; then
                    # Offline, or both stores hiccuped. Keep the working copy and carry
                    # its hash forward so the next switch can still detect a change.
                    echo "Warning: could not reach either store for $mod_id, keeping installed copy"
                    CURRENT_HASH="$PREV_HASH"
                  else
                    echo "Failed to fetch mod $mod_id from both stores"
                    continue
                  fi
                fi

                NEW_STATE=$(echo "$NEW_STATE" | ${lib.getExe pkgs.jq} -c \
                  --arg id "$mod_id" --arg h "$CURRENT_HASH" '.[$id] = $h')

                NEEDS_ENTRY=false
                if [ "$CHANGED" = true ]; then
                  NEEDS_ENTRY=true
                elif ! ${lib.getExe pkgs.jq} -e --arg id "$mod_id" 'has($id)' "$MODS_FILE" >/dev/null 2>&1; then
                  NEEDS_ENTRY=true
                fi

                if [ "$NEEDS_ENTRY" = true ] && [ -f "$MOD_DIR/theme.json" ]; then
                  THEME_DATA=$(cat "$MOD_DIR/theme.json")
                  TRANSFORMED=$(echo "$THEME_DATA" | ${lib.getExe pkgs.jq} --arg id "$mod_id" '
                    def to_local: if (. // "" | test("^https?://")) then (split("/") | last) else . end;

                    .id = $id |
                    .enabled = true |
                    # Nix owns the mod directory, so Sine must not fetch over it
                    # (manager.sys.mjs skips a mod when this is set).
                    ."no-updates" = true |
                    .style = (
                      if (.style | type) == "string" then
                        { "chrome": (.style | to_local), "content": "" }
                      elif (.style | type) == "object" then
                        {
                          "chrome": ((.style.chrome // "") | to_local),
                          "content": ((.style.content // "") | to_local)
                        }
                      else
                        { "chrome": "", "content": "" }
                      end
                    ) |
                    if .preferences then .preferences = (.preferences | to_local) else . end |
                    if .readme then .readme = (.readme | to_local) else . end
                  ')

                  ${lib.getExe pkgs.jq} --arg id "$mod_id" --argjson theme "$TRANSFORMED" \
                    '.[$id] = $theme' "$MODS_FILE" > "$MODS_FILE.tmp" && mv "$MODS_FILE.tmp" "$MODS_FILE"
                fi
              done

              SINE_MODS_JSON=$(echo "$SINE_MODS" | tr ' ' '\n' | ${lib.getExe pkgs.jq} -R -s 'split("\n") | map(select(. != ""))')
              echo "$NEW_STATE" | ${lib.getExe pkgs.jq} '.' > "$MANAGED_FILE"

              PREF_VALIDITY="{}"
              DEFAULT_PREFS="{}"
              for mod_id in $SINE_MODS; do
                PREF_NAME=$(${lib.getExe pkgs.jq} -r --arg id "$mod_id" '.[$id].preferences // ""' "$MODS_FILE")
                PREF_VALID=false
                if [ -n "$PREF_NAME" ]; then
                  PREF_PATH="$BASE_DIR/chrome/sine-mods/$mod_id/$PREF_NAME"
                  if [ -s "$PREF_PATH" ] && ${lib.getExe pkgs.jq} empty "$PREF_PATH" 2>/dev/null; then
                    PREF_VALID=true

                    # Mirrors what Sine's settings UI would write on first render:
                    # the raw defaultValue, and for checkboxes only when it is true.
                    MOD_DEFAULTS=$(${lib.getExe pkgs.jq} -c '
                      (if type == "array" then . else [] end)
                      | map(select((.property // "") != "" and has("defaultValue")))
                      | map(select(.type != "checkbox" or .defaultValue == true))
                      | map({(.property): .defaultValue})
                      | add // {}
                    ' "$PREF_PATH")
                    DEFAULT_PREFS=$(${lib.getExe pkgs.jq} -c -n \
                      --argjson acc "$DEFAULT_PREFS" --argjson new "$MOD_DEFAULTS" '$acc * $new')
                  fi
                fi
                PREF_VALIDITY=$(echo "$PREF_VALIDITY" | ${lib.getExe pkgs.jq} --arg id "$mod_id" --argjson v "$PREF_VALID" '.[$id] = $v')
              done

              printf 'var sineNixDefaultPrefs = %s;\n' "$DEFAULT_PREFS" \
                > "$BASE_DIR/chrome/sine-mods/nix-default-prefs.js"

              ${lib.getExe pkgs.jq} --argjson ids "$SINE_MODS_JSON" --argjson valid "$PREF_VALIDITY" '
                reduce $ids[] as $id (.;
                  if has($id) then
                    .[$id].enabled = true
                    | (if ($valid[$id] // false) then . else del(.[$id].preferences) end)
                  else . end)
              ' "$MODS_FILE" > "$MODS_FILE.tmp" && mv "$MODS_FILE.tmp" "$MODS_FILE"

              if ! ${lib.getExe pkgs.jq} empty "$MODS_FILE" 2>/dev/null; then
                echo "Error: Generated invalid JSON in $MODS_FILE"
                exit 1
              fi
            '';
        in
          nameValuePair profileName [
            {
              text = ''
                ${updateSineModsScript}
                if [[ "$?" -eq 0 ]]; then
                  $VERBOSE_ECHO "zen-sine-mods: Updated sine mods for profile '${profileName}'"
                else
                  echo "zen-sine-mods: Failed to update sine mods for profile '${profileName}'!" >&2
                fi
              '';
            }
          ]
      )
      profilesWithSineMods;
  };
}
