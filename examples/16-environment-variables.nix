# Set environment variables for the Zen Browser launcher (Linux only).
# Useful for theming/rendering workarounds, e.g. forcing a readable GTK theme
# under Wayland. See https://github.com/0xc000022070/zen-browser-flake/issues/290
{
  programs.zen-browser = {
    enable = true;

    env = {
      GTK_THEME = "Adwaita";
    };
  };
}
