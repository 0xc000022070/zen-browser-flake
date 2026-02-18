{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      suppressXdgMigrationWarning = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-testuser.service")
    machine.succeed("su - testuser -c 'zen-beta --version'")
  '';
}
