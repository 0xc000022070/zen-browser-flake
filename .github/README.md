# Zen Browser

This is a nix flake for the Zen browser.

## Features

- Linux support
- Available for _x86_64_ and _aarch64_
- Support for _twilight_ and _beta_
- Policies can be modified via Home Manager and unwrapped package override.
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
<summary><h4>Home Manager options</h4></summary>

The options provided by this module come from the [mkFirefoxModule](https://github.com/nix-community/home-manager/blob/67f60ebce88a89939fb509f304ac554bcdc5bfa6/modules/programs/firefox/mkFirefoxModule.nix#L207) utility, so feel free to experiment with other program options.

```nix
{
  # home.nix
  imports = [
    inputs.zen-browser.homeModules.beta
    # or inputs.zen-browser.homeModules.twilight
    # or inputs.zen-browser.homeModules.twilight-official
  ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      # find more options here: https://mozilla.github.io/policy-templates/
    };
  };
}
```

Then build your Home Manager configuration

```shell
$ home-manager switch
```

Check my rice [here](https://github.com/luisnquin/nixos-config/blob/main/home/modules/browser.nix)! :)

</details>

<details>
<summary><h4>With environment.systemPackages or home.packages</h4></summary>

To integrate `Zen Browser` to your NixOS/Home Manager configuration, add the following to your `environment.systemPackages` or `home.packages`:

```nix
# system: only 'x86_64-linux' and 'aarch64-linux' are supported

inputs.zen-browser.packages."${system}".default # beta
inputs.zen-browser.packages."${system}".beta # or "beta-unwrapped"
inputs.zen-browser.packages."${system}".twilight # or "twilight-unwrapped"
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

### Troubleshooting

#### 1Password constantly requires password

You may want to set `policies.DisableAppUpdate = false;` in your policies.json file. See <https://github.com/0xc000022070/zen-browser-flake/issues/48>.

## Native Messaging

To [enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging), you can use the following configuration pattern.

### With Home Manager

```nix
{
  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = [pkgs.firefoxpwa];
    # Add any other native connectors here
  };
}
```

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

## Contributing

Before contributing, please make sure that your code is formatted correctly by running

```shell
$ nix fmt
```

## LICENSE

This project is licensed under the [MIT License](./LICENSE).

You are free to use, modify, and distribute this software, provided that the original copyright and permission notice are retained. For more details, refer to the full [license text](./LICENSE).
