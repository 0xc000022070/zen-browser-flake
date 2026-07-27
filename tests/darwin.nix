# Eval-time facts are `assert`s so they also fail from Linux under
# `nix flake check --all-systems`. Signature verification itself lives in the
# macOS CI job, not here: /usr/bin/codesign is unreachable from a sandboxed
# derivation unless the daemon allows it as an impure host dep.
{
  self,
  pkgs,
  home-manager,
}: let
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped;

  nativeHost = pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/test.json" (
    builtins.toJSON {
      name = "test";
      description = "Zen Browser test native messaging host";
      path = "/usr/bin/false";
      type = "stdio";
      allowed_extensions = ["test@example.com"];
    }
  );

  mkHome = module:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeModules.beta
        {
          home = {
            username = "testuser";
            homeDirectory = "/Users/testuser";
            stateVersion = "26.05";
          };

          programs.zen-browser = {
            enable = true;
            policies.BlockAboutConfig = true;
            nativeMessagingHosts = [nativeHost];
            profiles.default = {
              id = 0;
              settings."browser.startup.homepage" = "https://example.com";
            };
          };
        }
        module
      ];
    };

  signedHome = mkHome {};
  signedPackage = signedHome.config.programs.zen-browser.finalPackage;
  signedDefaults = signedHome.config.targets.darwin.defaults."app.zen-browser.zen";
  nativeMessagingFiles =
    signedHome.config.home.file."Library/Application Support/Mozilla/NativeMessagingHosts";

  wrappedHome = mkHome {
    programs.zen-browser = {
      darwin.packageMode = "wrapped";
      extraPrefs = ''
        pref("browser.shell.checkDefaultBrowser", false);
      '';
    };
  };
  wrappedPackage = wrappedHome.config.programs.zen-browser.finalPackage;

  policyOverride = builtins.tryEval (
    (package.override {
      extraPolicies.DisableTelemetry = true;
    }).drvPath
  );

  signedWrapperOverride = builtins.tryEval (
    (mkHome {
      programs.zen-browser.extraPrefs = ''
        pref("browser.shell.checkDefaultBrowser", false);
      '';
    }).activationPackage.drvPath
  );

  mkSineEval = mode:
    builtins.tryEval (
      (mkHome {
        programs.zen-browser = {
          darwin.packageMode = mode;
          profiles.default.sine.enable = true;
        };
      })
      .activationPackage
      .drvPath
    );

  signedSine = mkSineEval "signed";
  wrappedSine = mkSineEval "wrapped";
in {
  signed = assert signedPackage.outPath == package.outPath;
  assert signedDefaults.EnterprisePoliciesEnabled;
  assert signedDefaults.DisableAppUpdate;
  assert signedDefaults.DisableTelemetry;
  assert signedDefaults.BlockAboutConfig;
  assert !policyOverride.success;
  assert !signedWrapperOverride.success;
  assert !signedSine.success;
  assert !wrappedSine.success;
    pkgs.runCommand "zen-browser-signed-darwin" {} ''
      app="${signedPackage}/Applications/${signedPackage.applicationName}.app"

      test -e "$app/Contents/_CodeSignature/CodeResources"
      test -e "$app/Contents/MacOS/zen"

      test ! -e "$app/Contents/MacOS/${signedPackage.binaryName}"
      test ! -e "$app/Contents/Resources/distribution/policies.json"

      test -x "${signedPackage}/bin/${signedPackage.binaryName}"

      test -e "${nativeMessagingFiles.source}/test.json"
      test -e "${signedHome.activationPackage}"

      touch "$out"
    '';

  wrapped = pkgs.runCommand "zen-browser-wrapped-darwin" {} ''
    app="${wrappedPackage}/Applications/${wrappedPackage.unwrapped.applicationName}.app"

    test -x "$app/Contents/MacOS/${wrappedPackage.unwrapped.binaryName}"
    test -e "$app/Contents/Resources/distribution/policies.json"

    touch "$out"
  '';
}
