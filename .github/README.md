# Zen Browser

This is a nix flake for the Zen browser.

## Features

- Linux and MacOS support
- Available for _x86_64_ and _aarch64_
- Support for _twilight_ and _beta_
- [Policies can be modified via Home Manager and unwrapped package override](#policies)
- Fast & Automatic updates via GitHub Actions
- Browser update checks are disabled by default
- The default twilight version is reliable and reproducible
- [Declarative \[Work\]Spaces (including themes, icons, containers)](#spaces)

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

> [!NOTE]
> **Beta Branch**: To keep the flake input only sync with beta updates, use `inputs.zen-browser.url = "github:0xc000022070/zen-browser-flake/beta"`.

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

Check the [Home Manager Reference](#home-manager-reference) and my rice [here](https://github.com/luisnquin/nixos-config/blob/main/home/modules/programs/browser/zen.nix)! :)

</details>

<details>
<summary><h4>With environment.systemPackages or home.packages</h4></summary>

To integrate `Zen Browser` to your NixOS/Home Manager configuration, add the following to your `environment.systemPackages` or `home.packages`:

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

### Policies

- `policies` (attrsOf anything): You can also modify the **extensions** and **preferences** from here.

#### Some common policies

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

#### Preferences

```nix
{
  programs.zen-browser.policies = let
    mkLockedAttrs = builtins.mapAttrs (_: value: {
      Value = value;
      Status = "locked";
    });
  in {
    Preferences = mkLockedAttrs {
      "browser.tabs.warnOnClose" = false;
      # and so on...
    };
  };
}
```

##### Zen-specific preferences

Check [this comment](https://github.com/0xc000022070/zen-browser-flake/issues/59#issuecomment-2964607780).

#### Extensions

```nix
{
  programs.zen-browser.policies = let
    mkExtensionSettings = builtins.mapAttrs (_: pluginId: {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
      installation_mode = "force_installed";
    });
  in {
    ExtensionSettings = mkExtensionSettings {
      "wappalyzer@crunchlabz.com" = "wappalyzer";
      "{85860b32-02a8-431a-b2b1-40fbd64c9c69}" = "github-file-icons";
    };
  };
}
```

You can find the `pluginId`s to use in the above snippet by
1. installing the extensions you want to use as you would normally
2. use about:debugging#/runtime/this-firefox to find their `Extension ID` 

Or follow the following steps to find their IDs manually:

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

### Spaces

> [!WARNING]
> Spaces declaration may change your rebuild experience with Home Manager. Due to limitations
> on how Zen handles spaces, the updating of them is done via a activation script on your
> `home-manager-<user>.service`. This may cause the service to fail, to prevent this,
> it is recommended to close your Zen browser instance before rebuilding.

- `profiles.*.spaces` (attrsOf submodule): Declare profile's \[work\]spaces.
  - `name` (string) Name of space, defaults to submodule/attribute name.
  - `id` (string) **Required.** UUID v4 of space. **Changing this after a rebuild will re-create the space as
    a new one,** losing opened tabs, groups, etc. If `spacesForce` is true, the space with the previous UUID will be deleted.
  - `position` (unsigned integer) Position/order of space in the left bar.
  - `icon` (null or (string or path)) Emoji, URI or file path for icon to be used as space icon.
  - `container` (null or unsigned integer) Container ID to be used as default in space.
  - `theme.type` (nullOr string) Type of theme, defaults to "gradient".
  - `theme.color` (listOf submodule) List of JSON colors to be used as theme:
    - `red` (integer between 0 and 255) Red value of color (first value of "c" array in JSON object).
    - `green` (integer between 0 and 255) Green value of color (second value of "c" array in JSON object).
    - `blue` (integer between 0 and 255) Blue value of color (third value of "c" array in JSON object).
    - `custom` (boolean) Is custom color ("isCustom" in JSON object).
    - `algorithm` (enum of "complementary", "floating" or "analogous") color algorithm (defaults to "floating").
    - `lightness` (integer) Lightness of color.
    - `position.x` (integer) X Position of color in gradient picker on Zen browser.
    - `position.y` (integer) Y Position of color in gradient picker on Zen browser.
    - `type` (enum of "undefined" or "explicit-lightness") Type of color (default to "undefined").
  - `theme.opacity` (null or float) Opacity of theme (defaults to 0.5).
  - `theme.rotation` (null or integer) Rotation of theme gradient (defaults to null).
  - `theme.texture` (null or float) Amount of texture of theme (defaults to 0.0).
- `profiles.*.spacesForce` (boolean) Whether to delete existing spaces not declared in the configuration.
  Recommended to make spaces fully declarative (defaults to false).

```nix
{
  programs.zen-browser = {
    enable = true;
    profiles."default" = {
      containersForce = true;
      containers = {
        Personal = {
          color = "purple";
          icon = "fingerprint";
          id = 1;
        };
        Work = {
          color = "blue";
          icon = "briefcase";
          id = 2;
        };
        Shopping = {
          color = "yellow";
          icon = "dollarsign";
          id = 3;
        };
      };
      spacesForce = true;
      spaces = let
        containers = config.programs.zen-browser.profiles."default".containers;
      in {
        "Space" = {
          id = "c6de089c-410d-4206-961d-ab11f988d40a";
          position = 1000;
        };
        "Work" = {
          id = "cdd10fab-4fc5-494b-9041-325e5759195b";
          icon = "chrome://browser/skin/zen-icons/selectable/star-2.svg";
          container = containers."Work".id;
          position = 2000;
        };
        "Shopping" = {
          id = "78aabdad-8aae-4fe0-8ff0-2a0c6c4ccc24";
          icon = "💸";
          container = containers."Shopping".id;
          position = 3000;
        };
      };
    };
  };
}
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

## Bonus

### XDG MIME Associations

To set Zen Browser as the default application for various file types and URL schemes, you can add the following configuration to your Home Manager setup:

```nix
{
  xdg.mimeApps = let
    value = let
      zen-browser = inputs.zen-browser.packages.${system}.beta; # or twilight
    in
      zen-browser.meta.desktopFileName;

    associations = builtins.listToAttrs (map (name: {
        inherit name value;
      }) [
        "application/x-extension-shtml"
        "application/x-extension-xhtml"
        "application/x-extension-html"
        "application/x-extension-xht"
        "application/x-extension-htm"
        "x-scheme-handler/unknown"
        "x-scheme-handler/mailto"
        "x-scheme-handler/chrome"
        "x-scheme-handler/about"
        "x-scheme-handler/https"
        "x-scheme-handler/http"
        "application/xhtml+xml"
        "application/json"
        "text/plain"
        "text/html"
      ]);
  in {
    associations.added = associations;
    defaultApplications = associations;
  };
}
```

## Troubleshooting

#### The requested URL returned error: 404

This usually happens when the Zen team deletes a beta release from the official repository. They do this to keep only stable artifacts available. See [#105](https://github.com/0xc000022070/zen-browser-flake/issues/105#issuecomment-3243452133) and [#112](https://github.com/0xc000022070/zen-browser-flake/issues/112#issuecomment-3262519193) for further context.

You can either revert your nix input update or wait until CI refreshes [sources.json](../sources.json).

#### Zen not seeing my GPU

Make sure that you update your flake.lock as to sync up nixpkgs version. Or make zen follow your system nixpkgs by using
`inputs.nixpkgs.follows = "nixpkgs"` (assuming your nixpkgs input is named nixpkgs).

Check [No WebGL context](https://github.com/0xc000022070/zen-browser-flake/issues/86) for details.

#### 1Password constantly requires password

You may want to set `policies.DisableAppUpdate = false;` in your policies.json file. See [#48](https://github.com/0xc000022070/zen-browser-flake/issues/48).

## Contributing

Before contributing, please make sure that your code is formatted correctly by running

```shell
$ nix fmt
```

## LICENSE

This project is licensed under the [MIT License](./LICENSE).
