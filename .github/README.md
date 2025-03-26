# Zen Browser

Originally from [MarceColl/zen-browser-flake](https://github.com/MarceColl/zen-browser-flake) deleted and re-made repo for discoverability as "GitHub does not like to show forks in the search".

This is a flake for the Zen browser.

## Features

- Linux support
- Available for x86_64 and aarch64
- Both **twilight** and **beta** versions are available
- Automatic updated Flake via GitHub Actions
- Integrated browser update checks are disabled
- The default twilight version is reliable and reproducible

## Installation

> [!CAUTION]
> The **twilight** package is not the official from [zen-browser/desktop](https://github.com/zen-browser/desktop). As you can
> check in their [releases page](https://github.com/zen-browser/desktop/releases), there is only one Twilight version of the browser,
> that's because there's only one tag available for that browser version, it means that every release replace the other, deleting the
> artifacts that we referenced once and normally this happens everyday so the package we aim to create won't achieve the goal to be really
> reproducible, for that reason we created a workaround to create releases and copy the artifacts from their repository in order to keep
> alive indefinitely. If you don't trust about this method we're using or that the artifacts won't be infected will malware by the
> repository owner or something else(I don't know, anything!), you can use the **twilight-official** package or simply keep yourself with **beta**.

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
    # to have it up to date or simply don't specify the nixpkgs input  
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ...
}
```

### Integration

To integrate `Zen Browser` to your NixOS/Home Manager configuration, add the following to your `environment.systemPackages` or `home.packages` respectively:

```nix
# Only 'x86_64-linux' and 'aarch64-linux' are supported
inputs.zen-browser.packages."${system}".default # beta
inputs.zen-browser.packages."${system}".beta
inputs.zen-browser.packages."${system}".twilight # artifacts are downloaded from this repository to guarantee reproducibility
inputs.zen-browser.packages."${system}".twilight-official # artifacts are downloaded from the official Zen repository
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
