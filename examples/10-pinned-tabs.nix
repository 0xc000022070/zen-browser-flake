# Pinned tabs with groups, folders, and container assignment
# Pins can be organized in folders and assigned to specific containers/spaces.
#
# ⚠ Only if using pins or pinsForce: close Zen before home-manager switch
# (activation script needs exclusive access to modify zen-sessions.jsonlz4)
{
  programs.zen-browser.profiles.default = let
    pins = {
      "Email" = {
        id = "9d8a8f91-7e29-4688-ae2e-da4e49d4a179";
        url = "https://mail.protonmail.com";
        position = 101;
        isEssential = true;
      };
      "GitHub" = {
        id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
        url = "https://github.com";
        position = 102;
      };
      "Dev Tools" = {
        id = "d85a9026-1458-4db6-b115-346746bcc692";
        isGroup = true;
        isFolderCollapsed = false;
        editedTitle = true;
        position = 200;
        folderIcon = "chrome://browser/skin/zen-icons/selectable/eye.svg";
      };
      "NixOS Packages" = {
        id = "f8dd784e-11d7-430a-8f57-7b05ecdb4c77";
        url = "https://search.nixos.org/packages";
        folderParentId = pins."Dev Tools".id;
        position = 201;
      };
      "NixOS Options" = {
        id = "92931d60-fd40-4707-9512-a57b1a6a3919";
        url = "https://search.nixos.org/options";
        folderParentId = pins."Dev Tools".id;
        position = 202;
      };
    };
  in {
    pinsForce = true; # Delete pins not declared here
    inherit pins;
  };
}
