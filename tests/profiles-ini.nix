{
  zen-browser-flake,
  wrapWithX11,
  ...
}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      profiles.default.id = 0;
    };
  };

  testScript =
    wrapWithX11
    ''
      ini = "/home/testuser/.config/zen/profiles.ini"

      machine.succeed(f"test -f {ini} && test ! -L {ini}")
      machine.succeed(f"test $(stat -c %a {ini}) = 644")
      machine.succeed(f"grep -q 'Name=default' {ini}")
      machine.succeed(f"su - testuser -c 'echo Drift=1 >> {ini}'")

      machine.succeed("systemctl restart home-manager-testuser.service")
      machine.wait_for_unit("home-manager-testuser.service")

      machine.succeed(f"test -f {ini} && test ! -L {ini}")
      machine.fail(f"grep -q 'Drift=1' {ini}")
      machine.succeed(f"grep -q 'Name=default' {ini}")
    '';
}
