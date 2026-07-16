# Shared cleaner for prefs baked into a profile's prefs.js by a since-
# disabled preset. Mirrors the state-writer.nix contract (profile-lock
# running guard, backup/restore) for the browser-owned prefs.js: it only
# ever deletes a line whose pref name AND value both match what the last
# generation recorded in the managed map, so a pref the user re-set by
# hand after disabling a preset is never touched.
#
# Managed map (zen-prefs-nix-managed.json, sibling of the mods managed
# map): `{ "<pref>": <value> }` — the effective values the enabled
# presets contributed on the previous activation. Diff against the
# currently declared map, strip stale exact `user_pref("<name>", <json
# value>);` lines, then rewrite the map to the declared set (or drop it
# when no preset is enabled).
{
  pkgs,
  lib,
}: {
  name,
  # Message prefix, e.g. "zen-preset-prefs".
  logPrefix,
  profileDir,
  # Zen profile lock; when held (browser running) the cleanup is skipped
  # entirely — the map must not advance past a cleanup that never ran.
  lockFile,
  # Store JSON `{ "<pref>": <value> }` of the prefs currently contributed
  # by enabled presets ({} when none are).
  declaredFile,
}: let
  jq = lib.getExe pkgs.jq;
in
  pkgs.writeShellScript name ''
    PROFILE_DIR="${profileDir}"
    PREFS_FILE="$PROFILE_DIR/prefs.js"
    MANAGED_FILE="$PROFILE_DIR/zen-prefs-nix-managed.json"
    DECLARED_FILE="${declaredFile}"
    BACKUP_FILE="$PREFS_FILE.nix-preset-cleanup.bak"
    LOCK_FILE="${lockFile}"

    PREFS_TMP=""

    cleanup() {
      [ -n "$PREFS_TMP" ] && rm -f "$PREFS_TMP" "$PREFS_TMP.next"
    }

    trap cleanup EXIT

    # Profile dir not created yet: nothing was recorded, nothing to clean.
    [ -d "$PROFILE_DIR" ] || exit 0

    DECLARED_EMPTY="$(${jq} -r 'length == 0' "$DECLARED_FILE")"
    if [ ! -f "$MANAGED_FILE" ] && [ "$DECLARED_EMPTY" = "true" ]; then
      exit 0
    fi

    if "${lib.getExe pkgs.lsof}" "$LOCK_FILE" >/dev/null 2>&1; then
      echo "${logPrefix}: Zen Browser appears to be running; skipping preset pref cleanup."
      echo "${logPrefix}: Close Zen Browser and rebuild to apply it."
      exit 0
    fi

    # Stale = recorded by the previous generation, no longer declared.
    # Emitted as `<name>\t<json value>`; tojson matches how Firefox
    # serializes user_pref values (ints/bools verbatim, strings quoted),
    # so a mismatch means the value changed outside Nix.
    if [ -f "$MANAGED_FILE" ] && [ -f "$PREFS_FILE" ]; then
      STALE="$(${jq} -r --slurpfile decl "$DECLARED_FILE" '
        to_entries[]
        | select(.key as $k | $decl[0] | has($k) | not)
        | "\(.key)\t\(.value | tojson)"' "$MANAGED_FILE" 2>/dev/null)" || STALE=""

      if [ -n "$STALE" ]; then
        cp "$PREFS_FILE" "$BACKUP_FILE" || {
          echo "${logPrefix}: Failed to create backup of $PREFS_FILE"
          exit 1
        }

        PREFS_TMP="$(mktemp)"
        cp "$PREFS_FILE" "$PREFS_TMP"

        while IFS="$(printf '\t')" read -r pref value; do
          [ -n "$pref" ] || continue
          line="user_pref(\"$pref\", $value);"
          if grep -qxF "$line" "$PREFS_TMP"; then
            grep -vxF "$line" "$PREFS_TMP" > "$PREFS_TMP.next" || true
            mv "$PREFS_TMP.next" "$PREFS_TMP"
            echo "${logPrefix}: reset '$pref' (left behind by a disabled preset)"
          elif grep -qF "user_pref(\"$pref\"," "$PREFS_TMP"; then
            echo "${logPrefix}: '$pref' was changed outside Nix since the preset set it; leaving it as-is"
          fi
        done <<EOF
    $STALE
    EOF

        mv "$PREFS_TMP" "$PREFS_FILE" || {
          echo "${logPrefix}: Failed to update $PREFS_FILE, restoring backup"
          mv "$BACKUP_FILE" "$PREFS_FILE"
          exit 1
        }
        PREFS_TMP=""
        rm -f "$BACKUP_FILE"
      fi
    fi

    # Advance the map to this generation's preset prefs; drop it when no
    # preset is enabled so the profile carries no dead state. rm first:
    # the previous map was copied from a read-only store path.
    rm -f "$MANAGED_FILE"
    if [ "$DECLARED_EMPTY" != "true" ]; then
      ${jq} -S . "$DECLARED_FILE" > "$MANAGED_FILE" || {
        echo "${logPrefix}: Failed to write $MANAGED_FILE"
        exit 1
      }
    fi
  ''
