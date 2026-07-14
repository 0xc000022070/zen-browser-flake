# Complete real-world setup combining multiple features
# This example shows a fully configured Zen Browser with spaces, containers, pins, and shortcuts.
# ⚠ Close Zen before home-manager switch
# (uses spacesForce, pinsForce, pinsForceAction, keyboardShortcuts—these modify state files)
{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.zen-browser.homeModules.beta];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisablePocket = true;
    };

    nativeMessagingHosts = [
      pkgs.firefoxpwa
      # ... more ...
    ];
    env = {
      GTK_THEME = "Adwaita";
    };

    profiles.default = {
      settings = {
        "zen.workspaces.continue-where-left-off" = true;
        "zen.view.compact.hide-tabbar" = true;
        "zen.urlbar.behavior" = "float";
      };

      mods = [
        "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
        "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
      ];

      search = {
        force = true;
        default = "ddg";
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Quick Links";
            toolbar = true;
            bookmarks = [
              {
                name = "GitHub";
                url = "https://github.com";
              }
            ];
          }
        ];
      };

      containersForce = true; # Delete containers not declared here
      containers = {
        Work = {
          color = "blue";
          icon = "briefcase";
          id = 1;
        };
      };

      spacesForce = true; # Delete spaces not declared here
      spaces = {
        "General" = {
          id = "c6de089c-410d-4206-961d-ab11f988d40a";
          position = 1000;
          icon = "🏠";
        };
        "Work" = {
          id = "cdd10fab-4fc5-494b-9041-325e5759195b";
          position = 2000;
          icon = "💼";
          container = 1;

          # Space-scoped form: same options as `pins.*` minus `workspace`,
          # which is derived from this space's id.
          pins."Tickets" = {
            id = "7f2c91de-3b58-4c2a-9e47-d31f08a6b5c2";
            url = "https://linear.app/";
            position = 102;
          };
        };
      };

      pinsForce = true;
      pinsForceAction = "remove"; # "remove" drops undeclared pins; default is "demote"
      pins = {
        "GitHub" = {
          id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
          url = "https://github.com";
          position = 101;
        };
      };

      keyboardShortcutsVersion = 17;
      keyboardShortcuts = [
        {
          id = "zen-compact-mode-toggle";
          key = "c";
          modifiers = {
            control = true;
            alt = true;
          };
        }
        {
          id = "key_quitApplication";
          disabled = true;
        }
      ];

      presets.catppuccin = {
        enable = true;
        flavor = "Mocha";
        accent = "Mauve";
      };

      # Declaring userChrome overrides the preset's default import, so re-add
      # it on top to keep the theme (userContent stays preset-managed here).
      userChrome = ''
        @import "catppuccin/userChrome.css";

        #navigator-toolbox {
          background-color: #2b2b2b;
        }

        #TabsToolbar {
          min-height: 28px;
        }

        .tab-icon-image {
          width: 16px;
          height: 16px;
        }
      '';
      # workspace is required: every live folder belongs to exactly one space.
      liveFolders = {
        "Prisma blog" = {
          id = "0f3f2f66-64bc-4a43-8f86-01c2a134c4f4";
          kind = "rss";
          feedUrl = "https://www.prisma.io/blog/rss.xml";
          folderIcon = "https://www.prisma.io/favicon.ico";
          workspace = "c6de089c-410d-4206-961d-ab11f988d40a"; # General
          position = 400;
          maxItems = 5;
        };

        "Pull requests" = {
          id = "b7a3d5c1-9e2f-4a68-b0d4-6f1c8e5a2d93";
          kind = "github:pull-requests";
          workspace = "cdd10fab-4fc5-494b-9041-325e5759195b"; # Work
          position = 401;
          github = {
            assignedMe = true; # default
            reviewRequested = true;
          };
        };

        "My issues" = {
          id = "3c9e1f7a-5b24-4d80-9a6c-e2f4b8d10c57";
          kind = "github:issues";
          workspace = "cdd10fab-4fc5-494b-9041-325e5759195b"; # Work
          position = 402;
          github.authorMe = true;
        };
      };
    };
  };
}
