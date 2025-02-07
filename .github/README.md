# Zen Browser

Originally from [MarceColl/zen-browser-flake](https://github.com/MarceColl/zen-browser-flake) deleted and re-made repo for discoverability as "GitHub does not like to show forks in the search".

This is a flake for the Zen browser.

## Features

- Linux support
- Available for x86_64 and aarch64
- Automatic updated Flake via GitHub Actions
- Both **twilight** and **beta** versions are distributed
- Integrated browser update checks are disabled

## Installation

> [!CAUTION]
> The **Twilight** version is not really that reproducible over time while trying to download the src again due the way how the official Zen browser repository is managing
> their releases, **a new release replaces the previous one and so on**. When using this version you should compromise yourself to update the flake with `nix flake update zen-browser`.
> Or wait for a contribution that mitigates that behavior in that specific version of the browser.

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  zen-browser.url = "github:0xc000022070/zen-browser-flake";
  ...
}
```

### Integration

To integrate `Zen Browser` to your NixOS/Home Manager configuration, add the following to your `environment.systemPackages` or `home.packages` respectively:

```nix
# Only 'x86_64-linux' and 'aarch64-linux' are supported
inputs.zen-browser.packages."${system}".default # beta
inputs.zen-browser.packages."${system}".beta
inputs.zen-browser.packages."${system}".twilight
```

Afterwards you can just build your configuration and start the `Zen Browser`

```shell
$ sudo nixos-rebuild switch # or home-manager switch
$ zen
```

## 1Password

Zen has to be manually added to the list of browsers that 1Password will communicate with. See [this wiki article](https://wiki.nixos.org/wiki/1Password) for more information. To enable 1Password integration, you need to add the line `.zen-wrapped` to the file `/etc/1password/custom_allowed_browsers`.

## LICENSE

This project is licensed under the [MIT License](./LICENSE).

You are free to use, modify, and distribute this software, provided that the original copyright and permission notice are retained. For more details, refer to the full [license text](./LICENSE).
