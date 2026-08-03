{zen-browser-flake, ...}: {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;

      policies = {
        AutofillCreditCardEnabled = false;
        BlockAboutConfig = true;
      };
    };
  };

  # Gecko resolves its application directory from /proc/self/exe, so the only
  # policies.json it reads is the one next to the fully dereferenced binary.
  # wrapFirefox writes its own copy into the wrapper's lib dir, which the
  # launcher never reaches: it execs straight through to the unwrapped store
  # path.
  testScript = ''
    import json

    pkg_path = machine.succeed(
      "su - testuser -c 'readlink -f $(which zen-beta)' | sed \"s|/bin/zen-beta$||\""
    ).strip()

    app_dir = machine.succeed(
      f"dirname $(readlink -f {pkg_path}/lib/zen-bin-*/zen)"
    ).strip()

    policies = json.loads(
      machine.succeed(f"cat {app_dir}/distribution/policies.json")
    )["policies"]

    assert policies.get("AutofillCreditCardEnabled") is False, \
      f"declared policy missing from {app_dir}/distribution/policies.json: {policies}"
    assert policies.get("BlockAboutConfig") is True, \
      f"declared policy missing from {app_dir}/distribution/policies.json: {policies}"

    assert policies.get("DisableAppUpdate") is True, \
      f"module default policy missing: {policies}"
    assert policies.get("DisableTelemetry") is True, \
      f"module default policy missing: {policies}"
  '';
}
