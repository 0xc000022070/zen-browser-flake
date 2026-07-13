# Shared updater for Zen's .jsonlz4 profile state files: profile-lock
# running guard, backup/restore, mozlz4a round-trip, declared-JSON jq
# merge. Every writer of a jsonlz4 state file goes through here so the
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
  # Shell lines run before the lock check; every early-out must exit.
  preChecks ? "",
  # Shell lines run after the lock check, e.g. first-run creation of a
  # state file the browser has not written yet; every early-out must exit.
  postLockChecks ? "",
}: let
  mozlz4a = lib.getExe pkgs.mozlz4a;
  jq = lib.getExe pkgs.jq;
  slurpArgs =
    lib.concatMapStringsSep " "
    (n: "--slurpfile ${n} ${slurpfiles.${n}}")
    (builtins.attrNames slurpfiles);
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

    ${postLockChecks}

    cp "$STATE_FILE" "$BACKUP_FILE" || {
      echo "${logPrefix}: Failed to create backup of $STATE_FILE"
      exit 1
    }

    ${mozlz4a} -d "$STATE_FILE" "$STATE_TMP" || {
      echo "${logPrefix}: Failed to decompress $STATE_FILE"
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

    ${mozlz4a} "$STATE_MODIFIED" "$STATE_FILE" || {
      echo "${logPrefix}: Failed to recompress ${subject} file"
      restore_and_cleanup
      exit 1
    }

    rm -f "$BACKUP_FILE"
  ''
