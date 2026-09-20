{
  pkgs,
  zen-browser-flake,
  ...
}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      profiles.default = {
        id = 0;
        sine.enable = true;
      };
    };
  };

  machineModules = [
    {
      virtualisation.memorySize = 4096;
      virtualisation.diskSize = 4096;
      environment.systemPackages = [pkgs.xorg-server];
    }
  ];

  testScript = ''
    profile = "/home/testuser/.config/zen/default"

    pkg_path = machine.succeed(
      "su - testuser -c 'readlink -f $(which zen-beta)' | sed \"s|/bin/zen-beta$||\""
    ).strip()

    app_dir = machine.succeed(
      f"dirname $(readlink -f {pkg_path}/lib/zen-bin-*/zen)"
    ).strip()

    config_prefs = machine.succeed(f"cat {app_dir}/defaults/pref/config-pref.js")
    assert 'general.config.filename' in config_prefs, \
      f"autoconfig is not enabled in {app_dir}: {config_prefs}"
    assert 'general.config.sandbox_enabled' in config_prefs, \
      f"autoconfig sandbox is still on in {app_dir}: {config_prefs}"

    config_js = machine.succeed(f"cat {app_dir}/config.js")
    assert 'nix-default-prefs.json' in config_js, \
      "mod-default seed missing from config.js"
    assert 'sine.sys.mjs' in config_js, \
      "bootloader import missing from config.js"
    assert config_js.index('nix-default-prefs.json') < config_js.index('sine.sys.mjs'), \
      "seed must run before Sine is imported"

    user_js = machine.succeed(f"cat {profile}/user.js")
    assert 'user_pref("sine.engine.auto-update", false);' in user_js, \
      "the engine self-updater was not disabled: " + user_js

    machine.succeed(f"test -d {profile}/chrome/JS")
    machine.succeed(f"test -d {profile}/chrome/utils")

    machine.succeed("( nohup Xvfb :99 -screen 0 1024x768x24 </dev/null >>/tmp/xvfb.log 2>&1 & )")
    machine.succeed("sleep 2")
    machine.succeed(
      "su - testuser -c 'DISPLAY=:99 timeout 60 zen-beta --no-remote about:blank' || true"
    )

    prefs = machine.succeed(f"cat {profile}/prefs.js")
    assert 'user_pref("sine.' in prefs, \
      "Sine never ran -- the autoconfig loader did not reach it: " + prefs
    assert 'user_pref("sine.engine.auto-update", true);' not in prefs, \
      "the engine re-enabled its self-updater: " + prefs
  '';
}
