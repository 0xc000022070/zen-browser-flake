# Override policies via package (without Home Manager)
# Use this approach when not using the Home Manager module.
# Linux only. On Darwin, use programs.zen-browser.policies so Home Manager
# writes policies through the macOS defaults domain without modifying the app.
{
  inputs,
  system,
  pkgs,
  ...
}: {
  home.packages = [
    (
      inputs.zen-browser.packages."${system}".default.override {
        extraPolicies = {
          DisableAppUpdate = true;
          DisableTelemetry = true;

          # The package already registers "System Trust" so `security.pki.*`
          # reaches Zen. Merging is per top-level key, so redefining
          # SecurityDevices drops it unless repeated here.
          SecurityDevices = {
            "System Trust" = "${pkgs.p11-kit}/lib/pkcs11/p11-kit-trust.so";
            "OpenSC" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
          };
        };
      }
    )
  ];
}
