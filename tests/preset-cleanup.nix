# Preset pref cleanup engine (hm-module/presets/cleanup.nix): the managed
# map records preset-contributed prefs, and prefs recorded by a previous
# generation but no longer declared are stripped from prefs.js — unless
# their value changed outside Nix. `presets.managedPrefNames` is set
# directly to simulate an enabled preset without fetching a real one.
{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      profiles.default = {
        settings."test.nix.managed" = 1;
        presets.managedPrefNames = ["test.nix.managed"];
      };
    };
  };

  testScript = ''
    profile = "/home/testuser/.config/zen/default"
    prefs = profile + "/prefs.js"
    managed = profile + "/zen-prefs-nix-managed.json"

    # First activation records the declared preset pref.
    managed_out = machine.succeed(f"cat {managed}")
    assert '"test.nix.managed": 1' in managed_out, "declared pref not recorded: " + managed_out

    # Simulate a previous generation: the browser baked three preset prefs
    # into prefs.js; the map recorded them, but ui.systemUsesDarkTheme was
    # later changed by hand (recorded 5, prefs.js has 1).
    machine.succeed(f"rm -f {prefs}")
    for line in [
        'user_pref("test.nix.managed", 1);',
        'user_pref("browser.startup.page", 0);',
        'user_pref("ui.systemUsesDarkTheme", 1);',
        'user_pref("unrelated.pref", "keep me");',
    ]:
        machine.succeed(f"echo '{line}' >> {prefs}")
    machine.succeed(
        f"echo '{{\"test.nix.managed\":1,\"browser.startup.page\":0,\"ui.systemUsesDarkTheme\":5}}' > {managed}"
    )

    machine.succeed("systemctl restart home-manager-testuser.service")

    prefs_out = machine.succeed(f"cat {prefs}")
    assert "browser.startup.page" not in prefs_out, "stale preset pref survived: " + prefs_out
    assert 'user_pref("ui.systemUsesDarkTheme", 1);' in prefs_out, "hand-changed pref was removed: " + prefs_out
    assert 'user_pref("unrelated.pref", "keep me");' in prefs_out, "unrelated pref was touched: " + prefs_out
    assert 'user_pref("test.nix.managed", 1);' in prefs_out, "still-declared pref was removed: " + prefs_out

    managed_out = machine.succeed(f"cat {managed}")
    assert "browser.startup.page" not in managed_out, "map kept an undeclared pref: " + managed_out
    assert '"test.nix.managed": 1' in managed_out, "map lost the declared pref: " + managed_out
  '';
}
