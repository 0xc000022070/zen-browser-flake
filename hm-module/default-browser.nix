{name}: {
  config,
  lib,
  ...
}: let
  inherit (lib) getAttrFromPath mkIf mkOption setAttrByPath;

  modulePath = [
    "programs"
    "zen-browser"
  ];

  cfg = getAttrFromPath modulePath config;
in {
  options = setAttrByPath modulePath {
    setAsDefaultBrowser = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set Zen Browser as the default application for various file types and URL schemes.
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.setAsDefaultBrowser) {
    xdg.mimeApps = let
      value = "zen-${name}.desktop";
      associations = builtins.listToAttrs (map (mime: {
          name = mime;
          value = lib.mkDefault value;
        }) [
          "application/x-extension-shtml"
          "application/x-extension-xhtml"
          "application/x-extension-html"
          "application/x-extension-xht"
          "application/x-extension-htm"
          "x-scheme-handler/unknown"
          "x-scheme-handler/mailto"
          "x-scheme-handler/chrome"
          "x-scheme-handler/about"
          "x-scheme-handler/https"
          "x-scheme-handler/http"
          "application/xhtml+xml"
          "application/json"
          "text/plain"
          "text/html"
        ]);
    in {
      associations.added = associations;
      defaultApplications = associations;
    };

    home.sessionVariables = {
      BROWSER = "zen-${name}";
    };
  };
}
