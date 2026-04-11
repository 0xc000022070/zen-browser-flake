# Native messaging hosts for browser-application communication
# Reference: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging
# Option 1: Via Home Manager
{pkgs, ...}: {
  programs.zen-browser.nativeMessagingHosts = [
    pkgs.firefoxpwa
    # ... more
  ];
}
# Option 2: Via package override
# { inputs, system, ... }:
#
# {
#   home.packages = [
#     (
#       inputs.zen-browser.packages."${system}".default.override {
#         nativeMessagingHosts = [pkgs.firefoxpwa];
#       }
#     )
#   ];
# }
# For 1Password integration in configuration.nix or home-manager:
# environment.etc = {
#   "1password/custom_allowed_browsers" = {
#     text = ".zen-wrapped";
#     mode = "0755";
#   };
# };

