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
                    description = "Enable sine option. When enabled, mods option is not allowed.";
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
                CURRENT_MANAGED=$(${lib.getExe pkgs.jq} -r '.[]' "$MANAGED_FILE" 2>/dev/null || echo "")
              else
                CURRENT_MANAGED=""
              fi

              for mod_id in $CURRENT_MANAGED; do
                if [[ " $SINE_MODS " != *" $mod_id "* ]]; then
                  ${lib.getExe pkgs.jq} "del(.[\"$mod_id\"])" "$MODS_FILE" > "$MODS_FILE.tmp" && mv "$MODS_FILE.tmp" "$MODS_FILE"
                  rm -rf "$BASE_DIR/chrome/sine-mods/$mod_id"
                  echo "Removed sine mod $mod_id"
                fi
              done

              for mod_id in $SINE_MODS; do
                MOD_DIR="$BASE_DIR/chrome/sine-mods/$mod_id"
                if [ -d "$MOD_DIR" ]; then
                  continue
                fi

                mkdir -p "$MOD_DIR"
                INSTALLED=false

                # Try Sine store first
                SINE_URL="https://raw.githubusercontent.com/sineorg/store/main/mods/$mod_id/mod.zip"
                TMPZIP=$(mktemp -d)
                echo "Fetching sine mod $mod_id from Sine store..."

                if ${lib.getExe pkgs.curl} -sfL "$SINE_URL" -o "$TMPZIP/mod.zip" 2>/dev/null; then
                  if ${lib.getExe pkgs.unzip} -o "$TMPZIP/mod.zip" -d "$TMPZIP/extracted" >/dev/null 2>&1; then
                    ITEMS=("$TMPZIP/extracted"/*)
                    if [ ''${#ITEMS[@]} -eq 1 ] && [ -d "''${ITEMS[0]}" ]; then
                      cp -r "''${ITEMS[0]}"/* "$MOD_DIR/" 2>/dev/null || true
                      cp -r "''${ITEMS[0]}"/.* "$MOD_DIR/" 2>/dev/null || true
                    else
                      cp -r "$TMPZIP/extracted"/* "$MOD_DIR/" 2>/dev/null || true
                    fi
                    echo "Installed sine mod $mod_id from Sine store"
                    INSTALLED=true
                  fi
                fi

                rm -rf "$TMPZIP"

                if [ "$INSTALLED" = false ]; then
                  echo "Sine store unavailable for $mod_id, trying vanilla Zen theme store..."
                  THEME_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_id/theme.json"

                  THEME_JSON=$(${lib.getExe pkgs.curl} -sfL "$THEME_URL")
                  if [ $? -ne 0 ] || [ -z "$THEME_JSON" ]; then
                    echo "Failed to fetch mod $mod_id from both stores"
                    rm -rf "$MOD_DIR"
                    continue
                  fi

                  if ! echo "$THEME_JSON" | ${lib.getExe pkgs.jq} empty 2>/dev/null; then
                    echo "Invalid JSON for mod $mod_id from vanilla store"
                    rm -rf "$MOD_DIR"
                    continue
                  fi

                  echo "$THEME_JSON" > "$MOD_DIR/theme.json"

                  for file in chrome.css preferences.json readme.md; do
                    FILE_URL="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$mod_id/$file"
                    ${lib.getExe pkgs.curl} -sfL "$FILE_URL" -o "$MOD_DIR/$file" || rm -f "$MOD_DIR/$file"
                  done

                  INSTALLED=true
                  echo "Installed sine mod $mod_id from vanilla Zen theme store"
                fi

                if [ "$INSTALLED" = true ] && [ -f "$MOD_DIR/theme.json" ]; then
                  THEME_DATA=$(cat "$MOD_DIR/theme.json")
                  TRANSFORMED=$(echo "$THEME_DATA" | ${lib.getExe pkgs.jq} --arg id "$mod_id" '
                    def to_local: if (. // "" | test("^https?://")) then (split("/") | last) else . end;

                    .id = $id |
                    .enabled = true |
                    ."no-updates" = false |
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
              echo "$SINE_MODS_JSON" > "$MANAGED_FILE"

              PREF_VALIDITY="{}"
              for mod_id in $SINE_MODS; do
                PREF_NAME=$(${lib.getExe pkgs.jq} -r --arg id "$mod_id" '.[$id].preferences // ""' "$MODS_FILE")
                PREF_VALID=false
                if [ -n "$PREF_NAME" ]; then
                  PREF_PATH="$BASE_DIR/chrome/sine-mods/$mod_id/$PREF_NAME"
                  if [ -s "$PREF_PATH" ] && ${lib.getExe pkgs.jq} empty "$PREF_PATH" 2>/dev/null; then
                    PREF_VALID=true
                  fi
                fi
                PREF_VALIDITY=$(echo "$PREF_VALIDITY" | ${lib.getExe pkgs.jq} --arg id "$mod_id" --argjson v "$PREF_VALID" '.[$id] = $v')
              done

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
