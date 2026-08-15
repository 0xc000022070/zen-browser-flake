// Prepended to Sine's autoconfig script (see hm-module/package.nix) so mod
// preference defaults exist before Sine is imported.
//
// Sine materialises a mod's `defaultValue` entries only as a side effect of
// rendering its settings UI in about:preferences: loadMods() in
// core/manager.sys.mjs walks the mods list for that page alone and calls
// parsePref(), and applyCheckbox/applyString/applyDropdown in
// core/preferences.sys.mjs write the pref when it is missing. A mod installed
// declaratively is therefore never visited by that code, so every rule gated on
// `-moz-pref()` stays inert and every `var(--<pref>)` stays undefined -- which
// makes the declaration invalid at computed-value time rather than falling back
// to the mod's intended value.
//
// The values land on the default branch, so a choice the user later makes in
// Sine's UI is a user pref and still wins. hm-module/sine.nix writes the data
// file next to the installed mods.
if (!Services.appinfo.inSafeMode) {
  try {
    const seedFile = Services.dirsvc.get("UChrm", Ci.nsIFile);
    seedFile.append("sine-mods");
    seedFile.append("nix-default-prefs.js");

    if (seedFile.exists()) {
      const scope = {};
      Services.scriptloader.loadSubScript(Services.io.newFileURI(seedFile).spec, scope);

      const branch = Services.prefs.getDefaultBranch("");
      for (const [name, value] of Object.entries(scope.sineNixDefaultPrefs ?? {})) {
        if (!name) continue;

        // A pref the running browser rejects must not strand the rest.
        try {
          if (typeof value === "boolean") {
            branch.setBoolPref(name, value);
          } else if (typeof value === "number" && Number.isInteger(value)) {
            branch.setIntPref(name, value);
          } else {
            branch.setStringPref(name, String(value));
          }
        } catch (err) {
          Components.utils.reportError(err);
        }
      }
    }
  } catch (err) {
    Components.utils.reportError(err);
  }
}
