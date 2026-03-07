{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser.enable = true;
  };

  testScript = ''    # python
    machine.succeed("su - testuser -c 'zen-beta --version'")
  '';
}
