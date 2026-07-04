# Per-profile "is Zen running?" guard for activation scripts that rewrite
# profile state files.
#
# Zen (Firefox core, nsProfileLock) holds the profile lock while running:
# `lock` in the profile dir is a symlink whose target is "<ip>:+<pid>".
# The symlink can outlive a crash or unclean exit, so its presence alone
# means nothing — only a live PID does. Checking it needs nothing beyond
# coreutils and shell builtins, is scoped to the exact profile being
# written (Zen open on another profile no longer blocks), and cannot
# false-positive on unrelated process names the way `pgrep zen` did
# (zenith, zenity, ...).
{
  profileDir,
  tag,
}: ''
  LOCK_PID="$(readlink "${profileDir}/lock" 2>/dev/null || true)"
  LOCK_PID="''${LOCK_PID##*+}"
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    ZEN_RUNNING=1
    # Linux: rule out PID reuse by an unrelated process; on Darwin
    # (no /proc) a live PID conservatively counts as Zen.
    if [ -r "/proc/$LOCK_PID/comm" ]; then
      read -r LOCK_COMM <"/proc/$LOCK_PID/comm"
      case "$LOCK_COMM" in
        *zen*) ;;
        *) ZEN_RUNNING=0 ;;
      esac
    fi
    if [ "$ZEN_RUNNING" = 1 ]; then
      echo "${tag}: Zen Browser is running with this profile (pid $LOCK_PID)."
      echo "${tag}: Close Zen Browser and rebuild to apply changes."
      exit 1
    fi
  fi
''
