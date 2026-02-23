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

  linuxConfigPath = "${config.xdg.configHome}/zen";
  darwinConfigPath = "${config.home.homeDirectory}/Library/Application Support/Zen";

  profilePath = "${(
    if pkgs.stdenv.isDarwin
    then "${darwinConfigPath}/Profiles"
    else linuxConfigPath
  )}";
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
      in
        lib.concatMapAttrs (
          profileName: profile:
            if profile.sine.enable
            then {
              "${profilePath}/${profileName}/chrome/JS/engine" = {
                source = sinePack.manager + "/engine";
                recursive = true;
                force = true;
              };
              "${profilePath}/${profileName}/chrome/JS/sine.sys.mjs" = {
                source = sinePack.manager + "/sine.sys.mjs";
                recursive = false;
                force = true;
              };
              "${profilePath}/${profileName}/chrome/utils" = {
                source = sinePack.bootloader + "/profile/utils";
                recursive = true;
                force = true;
              };
              "${profilePath}/${profileName}/chrome/locales" = {
                source = sinePack.manager + "/locales";
                recursive = true;
                force = true;
              };
            }
            else {}
        )
        cfg.profiles
      else {};

    home.activation = let
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
          modsFilePath = "${profilePath}/${profileName}/chrome/sine-mods/mods.json";

          updateSineModsScript = pkgs.writeShellScript "zen-sine-mods-update-${profileName}" ''            # bash
            MODS_FILE="${modsFilePath}"
            SINE_MODS="${lib.concatStringsSep " " profile.sine.mods}"
            BASE_DIR="${profilePath}/${profileName}"
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

                THEME_JSON=$(${lib.getExe pkgs.curl} -s "$THEME_URL")
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
                  ${lib.getExe pkgs.curl} -s "$FILE_URL" -o "$MOD_DIR/$file" || true
                done

                INSTALLED=true
                echo "Installed sine mod $mod_id from vanilla Zen theme store"
              fi

              if [ "$INSTALLED" = true ] && [ -f "$MOD_DIR/theme.json" ]; then
                THEME_DATA=$(cat "$MOD_DIR/theme.json")
                TRANSFORMED=$(echo "$THEME_DATA" | ${lib.getExe pkgs.jq} '
                  def to_local: if (. // "" | test("^https?://")) then (split("/") | last) else . end;

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

            echo "$SINE_MODS" | tr ' ' '\n' | ${lib.getExe pkgs.jq} -R -s 'split("\n") | map(select(. != ""))' > "$MANAGED_FILE"

            CHROME_CSS="$BASE_DIR/chrome/sine-mods/chrome.css"
            CONTENT_CSS="$BASE_DIR/chrome/sine-mods/content.css"

            {
              echo "/* Sine Mods - Generated by Zen Browser Flake."
              echo " * DO NOT EDIT THIS FILE DIRECTLY!"
              echo " * Your changes will be overwritten."
              echo " */"
            } > "$CHROME_CSS"

            {
              echo "/* Sine Mods - Generated by Zen Browser Flake."
              echo " * DO NOT EDIT THIS FILE DIRECTLY!"
              echo " * Your changes will be overwritten."
              echo " */"
            } > "$CONTENT_CSS"

            ENABLED_MODS=$(${lib.getExe pkgs.jq} -r 'to_entries[] | select(.value.enabled == null or .value.enabled == true) | .key' "$MODS_FILE")

            for mod_id in $ENABLED_MODS; do
              CHROME_FILE=$(${lib.getExe pkgs.jq} -r ".\"$mod_id\".style.chrome // empty" "$MODS_FILE")
              CONTENT_FILE=$(${lib.getExe pkgs.jq} -r ".\"$mod_id\".style.content // empty" "$MODS_FILE")
              MOD_NAME=$(${lib.getExe pkgs.jq} -r ".\"$mod_id\".name // \"$mod_id\"" "$MODS_FILE")
              MOD_AUTHOR=$(${lib.getExe pkgs.jq} -r ".\"$mod_id\".author // \"unknown\"" "$MODS_FILE")

              if [ -n "$CHROME_FILE" ] && [ -f "$BASE_DIR/chrome/sine-mods/$mod_id/$CHROME_FILE" ]; then
                {
                  echo "/* Name: $MOD_NAME */"
                  echo "/* Author: @$MOD_AUTHOR */"
                  cat "$BASE_DIR/chrome/sine-mods/$mod_id/$CHROME_FILE"
                  echo ""
                } >> "$CHROME_CSS"
              fi

              if [ -n "$CONTENT_FILE" ] && [ -f "$BASE_DIR/chrome/sine-mods/$mod_id/$CONTENT_FILE" ]; then
                {
                  echo "/* Name: $MOD_NAME */"
                  echo "/* Author: @$MOD_AUTHOR */"
                  cat "$BASE_DIR/chrome/sine-mods/$mod_id/$CONTENT_FILE"
                  echo ""
                } >> "$CONTENT_CSS"
              fi
            done

            echo "/* End of Sine Mods */" >> "$CHROME_CSS"
            echo "/* End of Sine Mods */" >> "$CONTENT_CSS"

            if ! ${lib.getExe pkgs.jq} empty "$MODS_FILE" 2>/dev/null; then
              echo "Error: Generated invalid JSON in $MODS_FILE"
              exit 1
            fi
          '';
        in
          nameValuePair "zen-sine-mods-${profileName}" (lib.hm.dag.entryAfter ["writeBoundary"] ''            # bash
            ${updateSineModsScript}
            if [[ "$?" -eq 0 ]]; then
              $VERBOSE_ECHO "zen-sine-mods: Updated sine mods for profile '${profileName}'"
            else
              echo "zen-sine-mods: Failed to update sine mods for profile '${profileName}'!" >&2
            fi
          '')
      )
      profilesWithSineMods;
  };
}
