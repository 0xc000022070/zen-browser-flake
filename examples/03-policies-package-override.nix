# Override policies via package (without Home Manager)
# Use this approach when not using the Home Manager module.
# Linux only. On Darwin, use programs.zen-browser.policies so Home Manager
# writes policies through the macOS defaults domain without modifying the app.
{
  inputs,
  system,
  ...
}: {
  home.packages = [
    (
      inputs.zen-browser.packages."${system}".default.override {
        extraPolicies = {
          DisableAppUpdate = true;
          DisableTelemetry = true;
        };
      }
    )
  ];
}
