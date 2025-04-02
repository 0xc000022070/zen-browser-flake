{
  home-manager,
  self,
  name,
}:
{
  pkgs,
  config,
  lib,
  ...
}:
let
  applicationName = "Zen Browser";
  modulePath = [
    "programs"
    "zen-browser"
  ];

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in
{
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "zen-${name}-unwrapped";
      unwrappedPackageName = "zen-${name}";
      visible = true;
      platforms = {
        linux = {
          vendorPath = ".zen";
          configPath = ".zen";
        };
        darwin = {
          configPath = "Library/Application Support/Zen";
        };
      };
    })
  ];

  config = lib.mkIf config.programs.zen-browser.enable {
    programs.zen-browser = {
      package = self.packages.${pkgs.stdenv.system}.${name};
      policies = {
        DisableAppUpdate = lib.mkDefault true;
        DisableTelemetry = lib.mkDefault true;
      };
    };
  };
}
