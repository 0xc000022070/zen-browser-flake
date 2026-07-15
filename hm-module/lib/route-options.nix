# Space-routing rule submodule shared by `spaceRouting.routes` and the
# space-scoped `spaces.*.routes`. Space-scoped routes exclude `openIn`:
# it is forced to the owning space during desugaring (session/spaces.nix).
{
  lib,
  includeOpenIn ? true,
}: let
  inherit (lib) mkOption types;
in
  {name, ...}: {
    options = with types;
      {
        id = mkOption {
          type = str;
          default = name;
          description = ''
            Route identity used to upsert into `zen-space-routing.jsonlz4`.
            Defaults to the attribute name; routes live in their own file, so
            this need not be a UUID and shares no namespace with pins/spaces.
          '';
        };
        reference = mkOption {
          type = str;
          description = ''
            URL match value. Interpreted per `matchType`: a substring for
            `contains`, a protocol/`www`/trailing-slash-normalized URL for
            `equal-to`, or a JS regular expression for `regex`.
          '';
        };
        matchType = mkOption {
          type = enum [
            "contains"
            "equal-to"
            "regex"
          ];
          default = "contains";
          description = "How `reference` is matched against opened URLs.";
        };
      }
      // lib.optionalAttrs includeOpenIn {
        openIn = mkOption {
          type = str;
          default = "most-recent-space";
          description = ''
            Where matching URLs open: a space id, or the literal
            `"most-recent-space"`. A space id is brace-wrapped automatically
            to match Zen's internal workspace uuid.
          '';
        };
      };
  }
