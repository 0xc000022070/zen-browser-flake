{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      enablePrivateDesktopEntry = true;
    };
  };

  testScript = ''
    pkg_path = machine.succeed(
      "su - testuser -c 'readlink -f $(which zen-beta)' | sed \"s|/bin/zen-beta$||\""
    ).strip()

    machine.succeed(f"test -f {pkg_path}/share/applications/zen-beta.desktop")
    machine.succeed(f"test -f {pkg_path}/share/applications/zen-beta-private.desktop")

    main_desktop_content = machine.succeed(f"cat {pkg_path}/share/applications/zen-beta.desktop")
    assert "Name=Zen Browser (Beta)" in main_desktop_content
    assert "Exec=zen-beta --name zen-beta %U" in main_desktop_content
    assert "Exec=zen-beta --private-window %U" in main_desktop_content

    private_desktop_content = machine.succeed(f"cat {pkg_path}/share/applications/zen-beta-private.desktop")
    assert "Name=Zen Browser (Beta) - Private Session" in private_desktop_content
    assert "Exec=zen-beta --private-window %u" in private_desktop_content
  '';
}
