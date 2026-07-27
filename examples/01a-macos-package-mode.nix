# Basic setup on macOS: the upstream Zen code signature is kept (default).
# The .app is installed untouched, so Team ID based integrations keep working:
# 1Password, iCloud Passwords, Touch ID, Gatekeeper.
# See https://github.com/0xc000022070/zen-browser-flake/issues/82
{pkgs, ...}: {
  programs.zen-browser = {
    enable = true;

    darwin.packageMode = "signed";

    # Written to the `app.zen-browser.zen` defaults domain, not into the bundle.
    policies = {
      DisableTelemetry = true;
      BlockAboutConfig = true;
    };

    # Installed under ~/Library/Application Support/Mozilla/NativeMessagingHosts.
    nativeMessagingHosts = [pkgs.firefoxpwa];

    profiles.default = {
      id = 0;
      settings."browser.startup.homepage" = "https://example.com";
    };
  };
}
# "wrapped" restores the wrapFirefox features (extraPrefs, extraPrefsFiles,
# pkcs11Modules) by writing inside the .app, which invalidates the upstream
# signature. Only use it if you need those and accept the trade-off.
#
# Sine is not available in either mode: its bootloader is only implemented for
# the Linux installation layout.
#
# {
#   programs.zen-browser = {
#     enable = true;
#     darwin.packageMode = "wrapped";
#     extraPrefs = ''
#       pref("browser.shell.checkDefaultBrowser", false);
#     '';
#   };
# }

