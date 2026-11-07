{zen-browser-flake, ...}: {
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
  '';
}
