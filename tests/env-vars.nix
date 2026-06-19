{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;

      env = {
        GTK_THEME = "Adwaita";
        ZEN_FLAKE_TEST = "marker";
      };
    };
  };

  testScript = ''
    wrapper = machine.succeed(
      "su - testuser -c 'readlink -f $(which zen-beta)'"
    ).strip()

    # The env vars are injected into the unwrapped launcher (a direct reference
    # of the wrapped package), so they must appear somewhere in the closure.
    refs = machine.succeed(f"nix-store -q --references {wrapper}").strip().split()
    haystack = " ".join(refs + [wrapper])

    machine.succeed(f"grep -rqF \"GTK_THEME='Adwaita'\" {haystack}")
    machine.succeed(f"grep -rqF \"ZEN_FLAKE_TEST='marker'\" {haystack}")
  '';
}
