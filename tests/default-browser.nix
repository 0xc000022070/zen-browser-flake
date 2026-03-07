{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.twilight];

    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
    };

    xdg.mimeApps = {
      enable = true;
      associations.added."application/json" = "other-app.desktop";
      defaultApplications."application/json" = "other-app.desktop";
    };
  };

  testScript = ''    # python
    mimeapps = machine.succeed("cat /home/testuser/.config/mimeapps.list")
    assert "application/json=other-app.desktop" in mimeapps, "application/json is not overridden correctly: \n" + mimeapps
    assert "text/html=zen-twilight.desktop" in mimeapps, "text/html default from zen is missing: \n" + mimeapps
  '';
}
