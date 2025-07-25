# Zen Browser

This is a nix flake for the Zen browser.

## Features

- Linux support
- Available for _x86_64_ and _aarch64_
- Support for _twilight_ and _beta_
- Policies can be modified via Home Manager and unwrapped package override
- Fast & Automatic updates via GitHub Actions
- Browser update checks are disabled by default
- The default twilight version is reliable and reproducible

## Installation

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
    # to have it up-to-date or simply don't specify the nixpkgs input
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ...
}
```

### Integration

> [!IMPORTANT]
> Use the **twilight** package to guarantee reproducibility, the artifacts of that package are re-uploaded
> to this repository. However, if you don't agree with that and want to use the official artifacts, use **twilight-official**.

<details>
<summary><h4>Home Manager</h4></summary>

```nix
{
  # home.nix
  imports = [
    inputs.zen-browser.homeModules.beta
    # or inputs.zen-browser.homeModules.twilight
    # or inputs.zen-browser.homeModules.twilight-official
  ];

  programs.zen-browser.enable = true;
}
```

Then build your Home Manager configuration

```shell
$ home-manager switch
```

Check the [Home Manager Reference](#home-manager-reference) and my rice [here](https://github.com/luisnquin/nixos-config/blob/main/home/modules/browser.nix)! :)

</details>

<details>
<summary><h4>With environment.systemPackages or home.packages</h4></summary>

To integrate `Zen Browser` to your NixOS/Home Manager configuration, add the following to your `environment.systemPackages` or `home.packages`:

```nix
# system: only 'x86_64-linux' and 'aarch64-linux' are supported

inputs.zen-browser.packages."${system}".default # beta
inputs.zen-browser.packages."${system}".beta # or "beta-unwrapped"
inputs.zen-browser.packages."${system}".twilight # or "twilight-unwrapped"
# IMPORTANT: this package relies on the twilight release artifacts from the
# official zen repo and no new release is created, the artifacts are replaced
inputs.zen-browser.packages."${system}".twilight-official # or "twilight-official-unwrapped"

# you can even override the package policies
inputs.zen-browser.packages."${system}".default.override {
  policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      # find more options here: https://mozilla.github.io/policy-templates/
  };
}
```

Afterwards you can just build your configuration

```shell
$ sudo nixos-rebuild switch # or home-manager switch
```

</details>

### Start the browser

```shell
# it's a symlink, if you install two versions they will collide and you should either specify "zen-twilight" or "zen-beta"
$ zen
```

## Home Manager reference

This is only an attempt to document some of the options provided by the [mkFirefoxModule](https://github.com/nix-community/home-manager/blob/67f60ebce88a89939fb509f304ac554bcdc5bfa6/modules/programs/firefox/mkFirefoxModule.nix#L207) module, so feel free to
experiment with other program options and help with further documentation.

`programs.zen-browser.*`

- `enable` (_boolean_): Enable the home manager config.

- `nativeMessagingHosts` (listOf package): To [enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).

  **Example:**

  ```nix
  {
    # Add any other native connectors here
    programs.zen-browser.nativeMessagingHosts = [pkgs.firefoxpwa];
  }
  ```

- `policies` (attrsOf anything): You can also modify the **extensions** and **preferences** from here.

  **Some common policies:**

  ```nix
  {
    programs.zen-browser.policies = {
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
  }
  ```

  For more policies [read this](https://mozilla.github.io/policy-templates/).

  **Preferences:**

  ```nix
  {
    programs.zen-browser.policies = {
      Preferences = {
        "browser.tabs.warnOnClose" = {
          "Value" = false;
          "Status" = "locked";
        };
        # and so on...
      };
    };
  }
  ```

  **Zen-specific preferences:**

  Check [this comment](https://github.com/0xc000022070/zen-browser-flake/issues/59#issuecomment-2964607780).

  **Extensions:**

  ```nix
  {
    programs.zen-browser.policies = {
      ExtensionSettings = {
        "wappalyzer@crunchlabz.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi";
          installation_mode = "force_installed";
        };
        "{85860b32-02a8-431a-b2b1-40fbd64c9c69}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/github-file-icons/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    }
  }
  ```

  To setup your own extensions you should:

   1. [Go to Add-ons for Firefox](https://addons.mozilla.org/en-US/firefox/).
   2. Go to the page of the extension that you want to declare.
   3. Go to "_See all versions_".
   4. Copy the link from any button to "Download file".
   5. Exec **wget** with the output of this command:

     ```bash
     echo "<paste-the-link-here>" \
      | sed -E 's|https://addons.mozilla.org/firefox/downloads/file/[0-9]+/([^/]+)-[^/]+\.xpi|\1|' \
      | tr '_' '-' \
      | awk '{print "https://addons.mozilla.org/firefox/downloads/latest/" $1 "/latest.xpi"}'
     ```

   6. Run `unzip -*.xpi -d my-extension && cd my-extension`.
   7. Run `cat manifest.json | jq -r '.browser_specific_settings.gecko.id'` and use the result
   for the _entry key_.
   8. Don't forget to add the `install_url` and set `installation_mode` to `force_installed`.

## 1Password

Zen has to be manually added to the list of browsers that 1Password will communicate with. See [this wiki article](https://wiki.nixos.org/wiki/1Password) for more information. To enable 1Password integration, you need to add the browser identifier to the file `/etc/1password/custom_allowed_browsers`.

```nix
environment.etc = {
  "1password/custom_allowed_browsers" = {
    text = ''
      .zen-wrapped
    ''; # or just "zen" if you use unwrapped package
    mode = "0755";
  };
};
```

## Native Messaging

To [enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging), you can use the following configuration pattern.

### With Home Manager

Check the [Home Manager Reference](#home-manager-reference).

### With package override

```nix
{
  home.packages = [
    (
      inputs.zen-browser.packages."${system}".default.override {
        nativeMessagingHosts = [pkgs.firefoxpwa];
      }
    )
  ];
}
```

## Troubleshooting

#### 1Password constantly requires password

You may want to set `policies.DisableAppUpdate = false;` in your policies.json file. See <https://github.com/0xc000022070/zen-browser-flake/issues/48>.

## Contributing

Before contributing, please make sure that your code is formatted correctly by running

```shell
$ nix fmt
```

## LICENSE

This project is licensed under the [MIT License](./LICENSE).
