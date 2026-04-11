# Custom userChrome.css for UI customization
# Reference: https://mefmobile.org/how-to-customize-firefoxs-user-interface-with-userchrome-css/
{
  programs.zen-browser.profiles.default.userChrome = ''
    #navigator-toolbox {
      background-color: #2b2b2b;
    }

    #TabsToolbar {
      min-height: 28px;
    }

    .tab-icon-image {
      width: 16px;
      height: 16px;
    }
  '';
}
