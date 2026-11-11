# Declarative keyboard shortcut overrides, written to
# ~/.config/zen/<profile>/customKeys.json (the store behind Settings ->
# Customize keyboard shortcuts, about:keyboard). Only the listed ids are
# touched; everything else you changed in about:keyboard stays.
# ⚠ Close Zen before home-manager switch (file read at startup, locked while running)
{
  programs.zen-browser.profiles.default = {
    keyboardShortcuts = [
      {
        id = "zen-compact-mode-toggle";
        key = "c";
        modifiers = {
          control = true;
          alt = true;
        };
      }
      {
        id = "zen-toggle-sidebar";
        key = "x";
        modifiers = {
          control = true;
          alt = true;
        };
      }
      {
        id = "key_quitApplication";
        disabled = true;
      }
      {
        id = "key_reload";
        key = "r";
        modifiers.control = true;
      }
      {
        id = "key_reload_skip_cache";
        key = "r";
        modifiers = {
          control = true;
          shift = true;
        };
      }
    ];
  };
}
# Finding a shortcut id: change the shortcut once in about:keyboard, then
# read the entry it produced:
#   jq . ~/.config/zen/default/customKeys.json
# Reset it there afterwards if you only wanted the id. Zen's own ids are the
# `zen-*` ones; Firefox's are `key_*` / `*Kb`.

