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
  inherit
    (lib)
    getAttrFromPath
    mkIf
    ;

  cfg = getAttrFromPath modulePath config;

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

  config = mkIf cfg.enable {
    programs.zen-browser = {
      package =
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.system}."${name}-unwrapped".override {
          # Seems like zen uses relative (to the original binary) path to the policies.json file
          # and ignores the overrides by pkgs.wrapFirefox
          policies = cfg.policies;
        }) {}).override
        {
          nativeMessagingHosts = cfg.nativeMessagingHosts;
        };

      # This does not work, the package can't build using these policies
      policies = lib.mkDefault {
        DisableAppUpdate = true;
        DisableTelemetry = true;
      };
    };
  };
}
