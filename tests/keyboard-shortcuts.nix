{
  zen-browser-flake,
  pkgs,
  ...
}: {
  machineModules = [{environment.systemPackages = [pkgs.perl];}];

  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      profiles.default.keyboardShortcuts = [
        {
          id = "zen-compact-mode-toggle";
          key = "c";
          modifiers = {
            control = true;
            alt = true;
          };
        }
        {
          id = "zen-glance-expand";
          keycode = "VK_F1";
          modifiers.alt = true;
        }
        {
          id = "key_quitApplication";
          disabled = true;
        }
      ];
    };
  };

  testScript = ''
    import json

    state = "/home/testuser/.config/zen/default/customKeys.json"
    expected = {
        "zen-compact-mode-toggle": {"modifiers": "alt,control", "key": "C"},
        "zen-glance-expand": {"modifiers": "alt", "keycode": "VK_F1"},
        "key_quitApplication": {},
    }

    # First activation: the browser never wrote the file, so it is created.
    data = json.loads(machine.succeed(f"cat {state}"))
    assert data == expected, f"created file differs: {data}"

    # Simulate about:keyboard customizations made between activations.
    foreign = {"key_gotoHistory": {"modifiers": "accel", "key": "Y"}, "zen-glance-expand": {"key": "G", "modifiers": "accel"}}
    machine.succeed(f"echo '{json.dumps(foreign)}' > {state}")
    machine.succeed("systemctl restart home-manager-testuser.service")

    data = json.loads(machine.succeed(f"cat {state}"))
    assert data == {**foreign, **expected}, f"merged file differs: {data}"

    # The live browser must honor the file: read the <key> elements over
    # Marionette, then press the old default chord and the declared one.
    machine.succeed(f"echo '{json.dumps(expected)}' > {state}")
    machine.succeed("( nohup Xvfb :99 -screen 0 1024x768x24 </dev/null >>/tmp/xvfb.log 2>&1 & )")
    machine.wait_for_file("/tmp/.X11-unix/X99")
    machine.succeed(
        "su - testuser -c 'DISPLAY=:99 MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1 nohup zen-beta --marionette about:blank >>/tmp/zen.log 2>&1 &'"
    )
    machine.wait_for_open_port(2828)
    first = json.dumps(expected["zen-compact-mode-toggle"])
    probe = json.loads(machine.succeed(
        f"perl ${./fixtures/keys-probe.pl} '{first}' {' '.join(expected)}"
    ))
    print(f"keys-probe: {probe}")
    assert probe["keys"] == expected, f"live <key> bindings differ: {probe}"
    initial, after_default, after_declared = probe["compact"]
    assert after_default == initial, "default accel+S still toggles compact mode"
    assert after_declared != initial, "declared control+alt+C does not toggle compact mode"

    machine.succeed("pkill -u testuser -f zen || true")
    machine.wait_until_fails("pgrep -u testuser -f zen")
    data = json.loads(machine.succeed(f"cat {state}"))
    assert data == expected, f"browser rewrote the file: {data}"
  '';
}
