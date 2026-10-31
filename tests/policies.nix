{
  pkgs,
  zen-browser-flake,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  extraPolicies = {
    DisableDeveloperTools = true;
    OfferToSaveLogins = false;
  };

  twilight = zen-browser-flake.packages.${system}.twilight.override {
    inherit extraPolicies;
  };

  twilightFunctionForm = zen-browser-flake.packages.${system}.twilight.override (old: {
    extraPolicies = (old.extraPolicies or {}) // extraPolicies;
  });

  twilightOverrideAttrs =
    (zen-browser-flake.packages.${system}.twilight.overrideAttrs (old: {
      passthru = old.passthru or {};
    })).override {
      inherit extraPolicies;
    };
in {
  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    home.packages = [twilight];

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
    import glob
    import json

    def app_policies(binary):
        pkg_path = machine.succeed(
          f"su - testuser -c 'readlink -f $(which {binary})' | sed \"s|/bin/{binary}$||\""
        ).strip()

        app_dir = machine.succeed(
          f"dirname $(readlink -f {pkg_path}/lib/zen-bin-*/zen)"
        ).strip()

        return app_dir, json.loads(
          machine.succeed(f"cat {app_dir}/distribution/policies.json")
        )["policies"]

    app_dir, policies = app_policies("zen-beta")

    assert policies.get("AutofillCreditCardEnabled") is False, \
      f"declared policy missing from {app_dir}/distribution/policies.json: {policies}"
    assert policies.get("BlockAboutConfig") is True, \
      f"declared policy missing from {app_dir}/distribution/policies.json: {policies}"

    assert policies.get("DisableAppUpdate") is True, \
      f"module default policy missing: {policies}"
    assert policies.get("DisableTelemetry") is True, \
      f"module default policy missing: {policies}"

    app_dir, policies = app_policies("zen-twilight")

    assert policies.get("DisableDeveloperTools") is True, \
      f"package override policy missing from {app_dir}/distribution/policies.json: {policies}"
    assert policies.get("OfferToSaveLogins") is False, \
      f"package override policy missing from {app_dir}/distribution/policies.json: {policies}"

    assert "SecurityDevices" in policies, \
      f"base policy lost by package override: {policies}"

    def unwrapped_policies(pkg):
        (policies_path,) = glob.glob(
          f"{pkg}/lib/zen-bin-*/distribution/policies.json"
        )

        with open(policies_path) as f:
            return policies_path, json.load(f)["policies"]

    policies_path, policies = unwrapped_policies("${twilightFunctionForm.unwrapped}")

    assert policies.get("DisableDeveloperTools") is True, \
      f"function-form override policy missing from {policies_path}: {policies}"
    assert policies.get("OfferToSaveLogins") is False, \
      f"function-form override policy missing from {policies_path}: {policies}"

    assert "SecurityDevices" in policies, \
      f"base policy lost by function-form override: {policies}"

    policies_path, policies = unwrapped_policies("${twilightOverrideAttrs.unwrapped}")

    assert policies.get("DisableDeveloperTools") is True, \
      f"overrideAttrs policy missing from {policies_path}: {policies}"
    assert policies.get("OfferToSaveLogins") is False, \
      f"overrideAttrs policy missing from {policies_path}: {policies}"

    assert "SecurityDevices" in policies, \
      f"base policy lost by overrideAttrs: {policies}"
  '';
}
