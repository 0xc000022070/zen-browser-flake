# Zen Browser

This is a nix flake for the Zen browser.

## Features

- Linux and macOS support
- Available for _x86_64_ and _aarch64_
- Support for _twilight_ and _beta_
- [Policies can be modified via Home Manager and unwrapped package override](#policies)
- Fast & Automatic updates via GitHub Actions
- Browser update checks are disabled by default
- The default twilight version is reliable and reproducible
- [Declarative \[Work\]Spaces (including themes, icons, containers)](#spaces)
- [Declarative keyboard shortcuts with version protection](#keyboard-shortcuts)
- [Declarative mods installation from Zen theme store](#mods)

_A flake for Zen Browser that lets you fine-tune more than other flakes._

## Installation

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
      # IMPORTANT: To ensure compatibility with the latest Firefox version, use nixpkgs-unstable.
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };
  # ...
}
```

> [!NOTE]
> **Beta Branch**: To keep the flake input only sync with beta updates, use
> `inputs.zen-browser.url = "github:0xc000022070/zen-browser-flake/beta"`.

### Integration

> [!IMPORTANT]
> Use the **twilight** package to guarantee reproducibility, the artifacts of
> that package are re-uploaded to this repository. However, if you don't agree
> with that and want to use the official artifacts, use **twilight-official**.

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

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };
}
```

Then build your Home Manager configuration

```shell
$ home-manager switch
```

Check the [Home Manager Reference](#home-manager-reference) and my rice
[here](https://github.com/luisnquin/nixos-config/blob/main/home/modules/programs/browser/zen.nix)!
:)

</details>

<details>
<summary><h4>With environment.systemPackages or home.packages</h4></summary>

To integrate `Zen Browser` into your NixOS/Home Manager configuration, add the
following to your `environment.systemPackages` or `home.packages`:

```nix
# options are: 'x86_64-linux', 'aarch64-linux' and 'aarch64-darwin'

inputs.zen-browser.packages."${system}".default # beta
inputs.zen-browser.packages."${system}".beta
inputs.zen-browser.packages."${system}".twilight
# IMPORTANT: this package relies on the twilight release artifacts from the
# official zen repo and those artifacts are always replaced, causing hash mismatch
inputs.zen-browser.packages."${system}".twilight-official

# you can even override the package policies
inputs.zen-browser.packages."${system}".default.override {
  policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      # more and more
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
$ zen-beta # or zen-twilight
```

## Configuration Examples

See the `examples/` directory for standalone configuration examples:

| Example                                                                       | Description                               |
| ----------------------------------------------------------------------------- | ----------------------------------------- |
| [01-basic-home-manager.nix](../examples/01-basic-home-manager.nix)               | Minimal Home Manager setup                |
| [02-policies-configuration.nix](../examples/02-policies-configuration.nix)       | System policies (policies.json)           |
| [02a-policies-preferences.nix](../examples/02a-policies-preferences.nix)         | Locked preferences (policies.Preferences) |
| [02b-settings-preferences.nix](../examples/02b-settings-preferences.nix)         | User settings (profiles.\*.settings)      |
| [03-policies-package-override.nix](../examples/03-policies-package-override.nix) | Package-level policy override             |
| [04-extensions.nix](../examples/04-extensions.nix)                               | Firefox addons                            |
| [04b-extensions-rycee.nix](../examples/04b-extensions-rycee.nix)                 | Firefox addons via rycee.nix              |
| [05-mods-installation.nix](../examples/05-mods-installation.nix)                 | Zen theme store mods                      |
| [06-search-engines.nix](../examples/06-search-engines.nix)                       | Custom search engines                     |
| [07-bookmarks.nix](../examples/07-bookmarks.nix)                                 | Bookmark organization                     |
| [08-containers.nix](../examples/08-containers.nix)                               | Multi-container setup                     |
| [09-spaces-themes.nix](../examples/09-spaces-themes.nix)                         | Spaces with themes                        |
| [10-pinned-tabs.nix](../examples/10-pinned-tabs.nix)                             | Pinned tabs and folders                   |
| [11-keyboard-shortcuts.nix](../examples/11-keyboard-shortcuts.nix)               | Keyboard shortcut overrides               |
| [12-userchrome-css.nix](../examples/12-userchrome-css.nix)                       | userChrome CSS customization              |
| [13-complete-setup.nix](../examples/13-complete-setup.nix)                       | Full real-world configuration             |
| [14-native-messaging.nix](../examples/14-native-messaging.nix)                   | Native messaging hosts (1Password, etc.)  |

## Home Manager Reference

This module is based on Home Manager's
[mkFirefoxModule](https://github.com/nix-community/home-manager/blob/67f60ebce88a89939fb509f304ac554bcdc5bfa6/modules/programs/firefox/mkFirefoxModule.nix#L207).
Refer to the examples above for common patterns.

Core options:

- `enable` (boolean): Enable Home Manager config
- `setAsDefaultBrowser` (boolean): Set Zen as default for URLs and file types

> [!IMPORTANT]
> macOS users need to configure `programs.zen-browser.darwinDefaultsId` first.
> See [home-manager options](https://home-manager-options.extranix.com/?query=programs.firefox.darwinDefaultsId&release=master).

## Configuration Layers

Three distinct configuration layers, stored differently:

| Layer                  | File                                                                    | Storage       | User Can Override |
| ---------------------- | ----------------------------------------------------------------------- | ------------- | ----------------- |
| **System Policies**    | [02-policies-configuration.nix](../examples/02-policies-configuration.nix) | policies.json | No (enforced)     |
| **Locked Preferences** | [02a-policies-preferences.nix](../examples/02a-policies-preferences.nix)   | policies.json | No (enforced)     |
| **User Settings**      | [02b-settings-preferences.nix](../examples/02b-settings-preferences.nix)   | prefs.js      | Yes (defaults)    |

## Profile Configuration

Profiles support many sub-options. See examples directory for:

- **Extensions**: [04-extensions.nix](../examples/04-extensions.nix), [04b-extensions-unfree.nix](../examples/04b-extensions-unfree.nix) (rycee's NUR)
- **Mods**: [05-mods-installation.nix](../examples/05-mods-installation.nix) (Zen theme store)
- **Search**: [06-search-engines.nix](../examples/06-search-engines.nix) (custom search shortcuts)
- **Bookmarks**: [07-bookmarks.nix](../examples/07-bookmarks.nix)
- **Containers**: [08-containers.nix](../examples/08-containers.nix)
- **Spaces**: [09-spaces-themes.nix](../examples/09-spaces-themes.nix) with custom gradient themes
- **Pinned Tabs**: [10-pinned-tabs.nix](../examples/10-pinned-tabs.nix) with folder grouping
- **Keyboard Shortcuts**: [11-keyboard-shortcuts.nix](../examples/11-keyboard-shortcuts.nix)
- **userChrome.css**: [12-userchrome-css.nix](../examples/12-userchrome-css.nix)

### Browser State Management

> [!CRITICAL]
> **Close Zen browser before `home-manager switch`** if you declare:
>
> - Any `spaces` (with or without `spacesForce`)
> - Any `pins` (with or without `pinsForce`)
> - Any `containers` (with or without `containersForce`)
> - Any `keyboardShortcuts`

If you only declare simple options like policies/extensions/bookmarks, rebuilding while Zen is open is ok, and closure won't be required.

Spaces, pins, and containers are stored in `zen-sessions.jsonlz4` (Mozilla LZ4 compressed JSON). The activation script:

1. Checks if Zen is running via `pgrep "zen"`—exits with error if browser is open
2. Decompresses zen-sessions.jsonlz4 from LZ4 to JSON
3. Modifies it with jq to apply your declared config
4. Recompresses back to LZ4
5. Restores backup on any failure

Browser must be closed because the file is locked in memory while Zen runs. The `*Force` options just control whether undeclared items are deleted—the state modification happens either way.

## Showcase

Here are some user configurations that showcase different setups using this flake:

- [ch1bo](https://github.com/ch1bo/dotfiles/blob/master/home-modules/browser/zen.nix)
- [luisnquin](https://github.com/luisnquin/nixos-config/blob/main/home/modules/programs/browser/zen/default.nix)
- [skifli](https://github.com/skifli/nixos/blob/main/users/programs/browser/zen.nix)

## 1Password

Zen has to be manually added to the list of browsers that 1Password will
communicate with. See [this wiki article](https://wiki.nixos.org/wiki/1Password)
for more information. To enable 1Password integration, you need to add the
browser identifier to the file `/etc/1password/custom_allowed_browsers`.

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

To
[enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging),
you can use the following configuration pattern.

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

### Missing configuration after update

1. The release [18.18.6b](****https://github.com/zen-browser/desktop/releases/tag/1.18.6b)
   changed the configuration location.
   Please move your configuration from ~/.zen to ~/.config/zen and restart the browser

   ```bash
   mkdir -p ~/.config/zen
   mv ~/.zen/* ~/.config/zen/
   rmdir ~/.zen
   ```

   Then change every occurrence of ".zen" to ".config/zen" in:
   - `.config/zen/<profile_name>/extensions.json`
   - `.config/zen/<profile_name>/pkcs11.txt`
   - `.config/zen/<profile_name>/chrome_debugger_profile/pkcs11.txt`

   Then run zen in safe mode once and close it (it will perform the required migrations):

   ```bash
   # or zen-twilight
   zen-beta --safe-mode
   ```

2. Please check that you're using the wrapped version of the package.
   The -unwrapped variants should not be used directly. Instead, they should be wrapped with wrapFirefox or custom wrappers.

Alternatively, you can review [this discussion](https://github.com/zen-browser/desktop/discussions/12366#discussioncomment-15810794) in the official Zen Browser repository.

#### The requested URL returned error: 404

This usually happens when the Zen team deletes a beta release from the official
repository. They do this to keep only stable artifacts available. See
[#105](https://github.com/0xc000022070/zen-browser-flake/issues/105#issuecomment-3243452133)
and
[#112](https://github.com/0xc000022070/zen-browser-flake/issues/112#issuecomment-3262519193)
for further context.

You can either revert your nix input update or wait until CI refreshes
[sources.json](../sources.json).

#### Zen not seeing my GPU

Make sure that you update your flake.lock as to sync up nixpkgs version. Or make
zen follow your system nixpkgs by using `inputs.nixpkgs.follows = "nixpkgs"`
(assuming your nixpkgs input is named nixpkgs).

Check
[No WebGL context](https://github.com/0xc000022070/zen-browser-flake/issues/86)
for details.

#### 1Password constantly requires password

You may want to set `policies.DisableAppUpdate = false;` in your policies.json
file. See [#48](https://github.com/0xc000022070/zen-browser-flake/issues/48).

## Contributing

Before contributing, please make sure that your code is formatted correctly by
running

```shell
$ nix fmt
```

## LICENSE

This project is licensed under the [MIT License](./LICENSE).
