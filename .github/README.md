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

  programs.zen-browser.enable = true;
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
# it's a symlink, if you install two versions they will collide and you should either specify "zen-twilight" or "zen-beta"
$ zen
```

## Home Manager reference

This is only an attempt to document some of the options provided by the
[mkFirefoxModule](https://github.com/nix-community/home-manager/blob/67f60ebce88a89939fb509f304ac554bcdc5bfa6/modules/programs/firefox/mkFirefoxModule.nix#L207)
module, so feel free to experiment with other program options and help with
further documentation.

`programs.zen-browser.*`

- `enable` (_boolean_): Enable the Home Manager config.

- `nativeMessagingHosts` (listOf package): To
  [enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).

  **Example:**

  ```nix
  {
    # Add any other native connectors here
    programs.zen-browser.nativeMessagingHosts = [pkgs.firefoxpwa];
  }
  ```

- `policies` (attrsOf anything):

> [!IMPORTANT]\
> If you're on macOS you'll need to configure
> [programs.zen-browser.darwinDefaultsId](https://home-manager-options.extranix.com/?query=programs.firefox.darwinDefaultsId&release=master)
> first.

### Some common policies

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

##### Zen-specific preferences

Check
[this comment](https://github.com/0xc000022070/zen-browser-flake/issues/59#issuecomment-2964607780).

- profiles:
  - [extensions](#extensions)
  - [mods](#mods)
  - [search](#search)
  - [preferences](#preferences)
  - [bookmarks](#bookmarks)
  - [spaces](#spaces)
  - [pinned tabs](#pinned-tabs-pins)
  - [keyboard shortcuts](#keyboard-shortcuts)
  - [userChrome](#userchromecss)

### Extensions

You can use [rycee's firefox-addons](https://nur.nix-community.org/repos/rycee/)
like this:

```nix
inputs = {
  firefox-addons = {
    url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
{
  programs.zen-browser.profiles.*.extensions.packages = 
     with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
          ublock-origin
          dearrow
          proton-pass
          ...
        ];
    ];
}
```

You can search for package names by going to
[the NUR website](https://nur.nix-community.org/repos/rycee/)

> [!IMPORTANT]
> Depending on how your flake is configured, you might not be able to install
> extensions marked "unfree" like [improved-tube](https://improvedtube.com/).
> For those extensions, the only way to install them is through the Firefox
> store
>
> If you are not using the
> [firefox-addons](https://nur.nix-community.org/repos/rycee/) repo, your
> configuration will still build, but the extension will
> not install.\
> Doing so through the repo will throw a build error warning you about the
> package being unfree

### Mods

Mods are themes and extensions available in the [Zen theme store](https://zen-browser.app/themes). You can browse and install them directly in the browser, but to make them declarative, you can list their UUIDs here.

To find the UUID of a mod, visit the mod's page in the Zen theme store and copy the UUID from the URL or the mod details.

> [!NOTE]
> You need to restart the browser to see the changes.

```nix
{
  programs.zen-browser.profiles.*.mods = [
    "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
  ];
}
```

### Search

[Search Engine Aliases](https://github.com/nix-community/home-manager/blob/master/modules/programs/firefox/profiles/search.nix#L211)

```nix
{
   programs.zen-browser.profiles.*.search = {
        force = true; # Needed for nix to overwrite search settings on rebuild
        default = "ddg"; # Aliased to duckduckgo, see other aliases in the link above
        engines = {
           # My NixOS Option and package search shortcut
         mynixos = {
            name = "My NixOS";
            urls = [
              {
                template = "https://mynixos.com/search?q={searchTerms}";
                params = [
                  {
                    name = "query";
                    value = "searchTerms";
                  }
                ];
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@nx"]; # Keep in mind that aliases defined here only work if they start with "@"
          };
        };
      };

}
```

### Preferences

```nix
{
  programs.zen-browser.profiles.*.settings = {
    "browser.tabs.warnOnClose" = false;
    "browser.download.panel.shown" = false;
    # Since this is a json value, it can be nixified and translated by home-manager;
    browser = {
      tabs.warnOnClose = false;
      download.panel.shown = false;
    };
    # Find all settings in about:config
  };
}
```

### Bookmarks

```nix
{
   programs.zen-browser.profiles.*.bookmarks = {
        force = true; # Required for nix to overwrite bookmarks on rebuild
        settings = [
          {
            name = "Nix sites";
            toolbar = true;
            bookmarks = [
              {
                name = "homepage";
                url = "https://nixos.org/";
              }
              {
                name = "wiki";
                tags = ["wiki" "nix"];
                url = "https://wiki.nixos.org/";
              }
            ];
          }
        ];
      };
}
```

### Spaces

> [!WARNING]
> Spaces declaration may change your rebuild experience with Home Manager. Due
> to limitations on how Zen handles spaces, the updating of them is done via a
> activation script on your `home-manager-<user>.service`. This may cause the
> service to fail, to prevent this, it is recommended to close your Zen browser
> instance before rebuilding.

- `profiles.*.spaces` (attrsOf submodule): Declare profile's \[work\]spaces.
  - `name` (string) Name of space, defaults to submodule/attribute name.
  - `id` (string) **Required.** UUID v4 of space. **Changing this after a
    rebuild will re-create the space as a new one,** losing opened tabs, groups,
    etc. If `spacesForce` is true, the space with the previous UUID will be
    deleted.
  - `position` (unsigned integer) Position/order of space in the left bar.
  - `icon` (null or (string or path)) Emoji, URI or file path for icon to be
    used as space icon.
  - `container` (null or unsigned integer) Container ID to be used as default in
    space.
  - `theme.type` (nullOr string) Type of theme, defaults to "gradient".
  - `theme.color` (listOf submodule) List of JSON colors to be used as theme:
    - `red` (integer between 0 and 255) Red value of color (first value of "c"
      array in JSON object).
    - `green` (integer between 0 and 255) Green value of color (second value of
      "c" array in JSON object).
    - `blue` (integer between 0 and 255) Blue value of color (third value of "c"
      array in JSON object).
    - `custom` (boolean) Is custom color ("isCustom" in JSON object).
    - `algorithm` (enum of "complementary", "floating" or "analogous") color
      algorithm (defaults to "floating").
    - `lightness` (integer) Lightness of color.
    - `position.x` (integer) X Position of color in gradient picker on Zen
      browser.
    - `position.y` (integer) Y Position of color in gradient picker on Zen
      browser.
    - `type` (enum of "undefined" or "explicit-lightness") Type of color
      (default to "undefined").
  - `theme.opacity` (null or float) Opacity of theme (defaults to 0.5).
  - `theme.rotation` (null or integer) Rotation of theme gradient (defaults to
    null).
  - `theme.texture` (null or float) Amount of texture of theme (defaults to
    0.0).
- `profiles.*.spacesForce` (boolean) Whether to delete existing spaces not
  declared in the configuration. Recommended to make spaces fully declarative
  (defaults to false).

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

### Pinned Tabs (pins)

You are also able to declare your pinned tabs! For more info, see
[this PR](https://github.com/0xc000022070/zen-browser-flake/pull/132)

```nix
{
  programs.zen-browser.profiles.default = let
    containers = {
      Work = {
        color = "blue";
        icon = "briefcase";
        id = 1;
      };
      Life = {
        color = "green";
        icon = "tree";
        id = 2;
      };
    };
    spaces = {
      "Rendezvous" = {
        id = "572910e1-4468-4832-a869-0b3a93e2f165";
        icon = "🎭";
        position = 1000;
        container = containers.Life.id;
      };
      "Github" = {
        id = "08be3ada-2398-4e63-bb8e-f8bf9caa8d10";
        icon = "🐙";
        position = 2000;
        theme = {
          type = "gradient";
          colors = [
            {
              red = 185;
              green = 200;
              blue = 215;
              algorithm = "floating";
              type = "explicit-lightness";
            }
          ];
          opacity = 0.8;
          texture = 0.5;
        };
      };
      "Nix" = {
        id = "2441acc9-79b1-4afb-b582-ee88ce554ec0";
        icon = "❄️";
        position = 3000;
        theme = {
          type = "gradient";
          colors = [
            {
              red = 150;
              green = 190;
              blue = 230;
              algorithm = "floating";
              type = "explicit-lightness";
            }
          ];
          opacity = 0.2;
          texture = 0.5;
        };
      };
    };
    pins = {
      "mail" = {
        id = "9d8a8f91-7e29-4688-ae2e-da4e49d4a179";
        container = containers.Life.id;
        url = "https://outlook.live.com/mail/";
        isEssential = true;
        position = 101;
      };
      "Notion" = {
        id = "8af62707-0722-4049-9801-bedced343333";
        container = containers.Life.id;
        url = "https://notion.com";
        isEssential = true;
        position = 102;
      };
      "Folo" = {
        id = "fb316d70-2b5e-4c46-bf42-f4e82d635153";
        container = containers.Life.id;
        url = "https://app.folo.is/";
        isEssential = true;
        position = 103;
      };
      "Nix awesome" = {
        id = "d85a9026-1458-4db6-b115-346746bcc692";
        workspace = spaces.Nix.id;
        isGroup = true;
        isFolderCollapsed = false;
        editedTitle = true;
        position = 200;
      };
      "Nix Packages" = {
        id = "f8dd784e-11d7-430a-8f57-7b05ecdb4c77";
        workspace = spaces.Nix.id;
        folderParentId = pins."Nix awesome".id;
        url = "https://search.nixos.org/packages";
        position = 201;
      };
      "Nix Options" = {
        id = "92931d60-fd40-4707-9512-a57b1a6a3919";
        workspace = spaces.Nix.id;
        folderParentId = pins."Nix awesome".id;
        url = "https://search.nixos.org/options";
        position = 202;
      };
      "Home Manager Options" = {
        id = "2eed5614-3896-41a1-9d0a-a3283985359b";
        workspace = spaces.Nix.id;
        folderParentId = pins."Nix awesome".id;
        url = "https://home-manager-options.extranix.com";
        position = 203;
      };
    };
  in {
    containersForce = true;
    pinsForce = true;
    spacesForce = true;
    inherit containers pins spaces;
    # ...
  };
}
```

### Keyboard Shortcuts

Declarative overrides of Zen Browser's keyboard shortcuts with version protection against breaking changes.

```nix
{
  programs.zen-browser.profiles.default = {
    keyboardShortcuts = [
      # Change compact mode toggle to Ctrl+Alt+S
      {
        id = "zen-compact-mode-toggle";
        key = "s";
        modifiers = {
          control = true;
          alt = true;
        };
      }
      # Disable the quit shortcut to prevent accidental closes
      {
        id = "key_quitApplication";
        disabled = true;
      }
    ];
    # Fails activation on schema changes to detect potential regressions
    # Find this in about:config or prefs.js of your profile
    keyboardShortcutsVersion = 14;
  };
}
```

When you declare a shortcut override:

- Identity fields (`id`, `group`, `action`, `l10nId`, `reserved`, `internal`) are preserved from Zen's defaults
- Binding fields (`key`, `keycode`, `modifiers`, `disabled`) are completely replaced with your declaration

#### Configuration Options

- `profiles.*.keyboardShortcuts` (list of submodules): Declarative keyboard shortcuts configuration.
  - `id` (string) **Required.** Unique identifier for the shortcut to modify.
  - `key` (null or string) Character key (e.g., "a", "1", "+"). Leave null to use default.
  - `keycode` (null or string) Virtual key code for special keys (e.g., "VK_F1", "VK_DELETE"). Leave null to use default.
  - `disabled` (null or boolean) Set to true to disable the shortcut. Leave null to use default.
  - `modifiers` (null or submodule) Modifier keys configuration. Leave null to use defaults.
    - `control` (null or boolean) Ctrl key modifier.
    - `alt` (null or boolean) Alt key modifier.
    - `shift` (null or boolean) Shift key modifier.
    - `meta` (null or boolean) Meta/Windows/Command key modifier.
    - `accel` (null or boolean) Accelerator key (Ctrl on Linux/Windows, Cmd on macOS).

- `profiles.*.keyboardShortcutsVersion` (null or integer) Expected version of the keyboard shortcuts schema. If set, activation will fail if the Zen Browser shortcuts version doesn't match, preventing silent breakage after Zen Browser updates. Find the current version in `about:config` as `zen.keyboard.shortcuts.version`.

### Finding Shortcut IDs

Find all shortcuts in `~/.zen/<profile>/zen-keyboard-shortcuts.json`. For example:

```bash
jq -c '.shortcuts[] | {id, key, keycode, action}' ~/.zen/default/zen-keyboard-shortcuts.json
```

### Notes on activation

Keyboard shortcuts are still managed by Zen and the home manager module only overrides them on activation. That means that Zen needs to be started at least once to create the shortcuts file if it doesn't exist yet. Then, every rebuild of your configuration (`nixos-rebuild switch` or `home-manager switch`) will apply your keybindings. Also note that you can just re-run activation scripts with `systemctl start home-manager-${USER}.service`.

### userChrome.css

```nix
{
  programs.zen-browser.profiles.*.userChrome = ''
    #navigator-toolbox {
      background-color: #2b2b2b; /* Changes the toolbar background color */
    }
  '';
}
```

[Article on how to customize userChrome](https://mefmobile.org/how-to-customize-firefoxs-user-interface-with-userchrome-css/)

## User Configurations

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

## Bonus

### XDG MIME Associations

To set Zen Browser as the default application for various file types and URL
schemes, you can add the following configuration to your Home Manager setup:

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
