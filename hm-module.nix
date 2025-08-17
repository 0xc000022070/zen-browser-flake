{
  home-manager,
  self,
  name,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  applicationName = "Zen Browser";
  modulePath = [
    "programs"
    "zen-browser"
  ];

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "zen-${name}";
      unwrappedPackageName = "zen-${name}-unwrapped";
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
      package =
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.hostPlatform.system}."${name}-unwrapped".override {
          # Seems like zen uses relative (to the original binary) path to the policies.json file
          # and ignores the overrides by pkgs.wrapFirefox
          policies = config.programs.zen-browser.policies;
        }) {}).override
        {
          nativeMessagingHosts = config.programs.zen-browser.nativeMessagingHosts;
        };

      # This does not work, the package can't build using these policies
      policies = lib.mkDefault {
        DisableAppUpdate = true;
        DisableTelemetry = true;
      };
    };
  };
}
