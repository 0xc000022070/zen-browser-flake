{
  programs.zen-browser = {
    enable = true;

    profiles.default = {
      # Keys are CustomizableUI areas:
      #
      #   nav-bar                  the toolbar itself ("pin to toolbar")
      #   unified-extensions-area  the extensions panel (the default)
      #   zen-sidebar-top-buttons  Zen's sidebar, above the tabs
      #   zen-sidebar-foot-buttons Zen's sidebar, below the tabs
      #
      # Ids come from about:debugging#/runtime/this-firefox, or from
      # `browser.uiCustomization.state` in about:config (there they already
      # carry the `-browser-action` suffix; those are accepted verbatim).
      extensionButtons = {
        "nav-bar" = [
          "uBlock0@raymondhill.net"
          "authenticator@mymindstorm"
          "78272b6fa58f4a1abaac99321d503a20@proton.me"
        ];

        "unified-extensions-area" = [
          "addon@darkreader.org"
        ];
      };
    };
  };
}
# The placements are merged into the layout Zen saved last, so anything you
# never declared keeps its place. A profile that has never run Zen has no
# layout to merge into: launch it once, close it, and rebuild.

