# Override policies via package (without Home Manager)
# Use this approach when not using the Home Manager module.
{
  inputs,
  system,
  ...
}: {
  home.packages = [
    (
      inputs.zen-browser.packages."${system}".default.override {
        policies = {
          DisableAppUpdate = true;
          DisableTelemetry = true;
        };
      }
    )
  ];
}
