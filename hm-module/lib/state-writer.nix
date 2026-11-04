# Shared updater for Zen's profile state files: profile-lock running
# guard, backup/restore, optional mozlz4a round-trip, declared-JSON jq
# merge. Every writer of a profile state file goes through here so the
# guard/backup/upsert contract stays in one place.
{
  pkgs,
  lib,
}: {
  name,
  # Message prefix, e.g. "zen-sessions".
  logPrefix,
  # Noun in error messages, e.g. "sessions" -> "Failed to recompress sessions file".
  subject,
  # Noun in the browser-running skip message, e.g. "spaces/pins".
  skipSubject,
  stateFile,
  # Zen profile lock; when held (browser running) the update is skipped.
  lockFile,
  # attrsOf store path, passed as `jq --slurpfile <name> <path>`.
  slurpfiles,
  jqFilterFile,
  compressed ? true,
  # Shell lines run before the lock check; every early-out must exit.
  preChecks ? "",
  # Store JSON installed as the state file when the browser has not
  # written it yet; null = nothing to do until the browser creates it.
  initialFile ? null,
}: let
  mozlz4a = lib.getExe pkgs.mozlz4a;
  jq = lib.getExe pkgs.jq;
  slurpArgs =
    lib.concatMapStringsSep " "
    (n: "--slurpfile ${n} ${slurpfiles.${n}}")
    (builtins.attrNames slurpfiles);
  decompress =
    if compressed
    then ''${mozlz4a} -d "$STATE_FILE" "$STATE_TMP"''
    else ''cp "$STATE_FILE" "$STATE_TMP"'';
  recompress =
    if compressed
    then ''${mozlz4a} "$STATE_MODIFIED" "$STATE_FILE"''
    else ''cp "$STATE_MODIFIED" "$STATE_FILE"'';
  createMissing = lib.optionalString (initialFile != null) ''
    if [ ! -f "$STATE_FILE" ]; then
      mkdir -p "$(dirname "$STATE_FILE")" && ${
      if compressed
      then ''${mozlz4a} ${initialFile} "$STATE_FILE"''
      else ''cat ${initialFile} > "$STATE_FILE"''
    } || {
        echo "${logPrefix}: Failed to create $STATE_FILE"
        exit 1
      }
      exit 0
    fi
  '';
in
  pkgs.writeShellScript name ''
    STATE_FILE="${stateFile}"
    STATE_TMP="$(mktemp)"
    STATE_MODIFIED="$(mktemp)"
    BACKUP_FILE="''${STATE_FILE}.backup"
    LOCK_FILE="${lockFile}"

    cleanup() {
      rm -f "$STATE_TMP" "$STATE_MODIFIED"
    }

    restore_and_cleanup() {
      if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "$STATE_FILE"
      fi
      cleanup
    }

    trap cleanup EXIT

    ${preChecks}

    if "${lib.getExe pkgs.lsof}" "$LOCK_FILE" >/dev/null 2>&1; then
      echo "${logPrefix}: Zen Browser appears to be running; skipping ${skipSubject} changes."
      echo "${logPrefix}: Close Zen Browser and rebuild to apply them."
      exit 0
    fi

    ${createMissing}

    cp "$STATE_FILE" "$BACKUP_FILE" || {
      echo "${logPrefix}: Failed to create backup of $STATE_FILE"
      exit 1
    }

    ${decompress} || {
      echo "${logPrefix}: Failed to read $STATE_FILE"
      restore_and_cleanup
      exit 1
    }

    ${jq} ${slurpArgs} \
      -f ${jqFilterFile} \
      "$STATE_TMP" > "$STATE_MODIFIED" || {
      echo "${logPrefix}: Failed to apply modifications to ${subject} data"
      restore_and_cleanup
      exit 1
    }

    if [ ! -s "$STATE_MODIFIED" ]; then
      echo "${logPrefix}: Modified ${subject} file is empty, restoring backup"
      restore_and_cleanup
      exit 1
    fi

    ${recompress} || {
      echo "${logPrefix}: Failed to write ${subject} file"
      restore_and_cleanup
      exit 1
    }

    rm -f "$BACKUP_FILE"
  ''
