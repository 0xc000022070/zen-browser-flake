# Evaluates `programs.zen-browser` Home Manager options into user-facing JSON records.
{
  flakePath,
  system ? "x86_64-linux",
  variant ? "beta",
  includeInternal ? false,
}: let
  flake = builtins.getFlake flakePath;
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  lib = pkgs.lib;
  hm = flake.inputs.home-manager;

  zenModule =
    if variant == "beta"
    then flake.homeModules.beta
    else if variant == "twilight"
    then flake.homeModules.twilight
    else if variant == "twilight-official"
    then flake.homeModules.twilight-official
    else throw "tooling/export-hm-options.nix: unknown variant '${variant}' (use beta, twilight, twilight-official)";

  evaluated = hm.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      zenModule
      {
        home.username = "hm-options-export";
        home.homeDirectory = "/home/hm-options-export";
        home.stateVersion = "24.05";
      }
    ];
  };

  rawDocs = lib.optionAttrSetToDocList evaluated.options.programs.zen-browser;

  filtered =
    if includeInternal
    then rawDocs
    else builtins.filter (o: !(o.internal or false)) rawDocs;

  strip = s: lib.removeSuffix "\n" (lib.removePrefix "\n" s);

  # `null or ""` keeps null (only missing attrs use the default); descriptions may be null.
  safeDescription = o: let
    attempt = builtins.tryEval (o.description or "");
  in
    if !attempt.success || attempt.value == null
    then ""
    else strip (builtins.toString attempt.value);

  simplifyDocValue = v:
    if v == null
    then null
    else if builtins.isAttrs v && (v._type or "") == "literalExpression"
    then v.text
    else builtins.toJSON v;

  optionRootParts = [
    "programs"
    "zen-browser"
  ];

  toFriendly = o: let
    desc = safeDescription o;
    rel = lib.drop (builtins.length optionRootParts) o.loc;
    path =
      if rel == []
      then ""
      else lib.concatStringsSep "." rel;
  in
    {
      inherit (o) name type readOnly;
      label = lib.last o.loc;
      inherit path;
      description = desc;
    }
    // lib.optionalAttrs (o ? default) {default = simplifyDocValue o.default;}
    // lib.optionalAttrs (o ? example) {example = simplifyDocValue o.example;};
  friendly = map toFriendly filtered;

  byPath = builtins.sort (a: b: a.path < b.path) friendly;
in {
  meta = {
    schemaVersion = 1;
    inherit variant;
    optionRoot = lib.concatStringsSep "." optionRootParts;
    optionCount = builtins.length byPath;
    note = "0xc000022070/zen-browser-flake's nix options (beta).";
  };
  options = byPath;
}
