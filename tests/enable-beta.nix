{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      suppressXdgMigrationWarning = true;
    };
  };

  testScript = /* python */ ''
    machine.succeed("su - testuser -c 'zen-beta --version'")
  '';
}
