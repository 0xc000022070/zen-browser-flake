# wrapFirefox picks its ffmpeg by `versionAtLeast browser.version <N>`; Zen's
# "1.21.15b" never clears that, so it's stuck on the oldest ffmpeg. Fake the
# version for that check only, restore the real one everywhere else (#386).
# `firefoxVersion` (the Gecko milestone recorded in sources.json) makes the
# wrapper take exactly the branch it takes for the equivalent Firefox; packages
# without it fall back to "always newest".
wrapFirefox: unwrapped: config: let
  wrap = unwrapped: config: let
    wrapped =
      wrapFirefox (unwrapped // {version = unwrapped.firefoxVersion or "9999";})
      ({version = unwrapped.version;} // config)
      // {inherit unwrapped;};
  in
    wrapped
    // {
      override = args: let
        policyArgs =
          builtins.intersectAttrs {
            policies = null;
            extraPolicies = null;
          }
          args;
        wrapperArgs = removeAttrs args ["policies" "extraPolicies"];
      in
        wrap (unwrapped.override policyArgs) (config // wrapperArgs);
    };
in
  wrap unwrapped config
