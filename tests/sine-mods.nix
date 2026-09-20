# The mod's chrome.css encodes all three hand-offs in one pixel: neither
# colour means the stylesheet never applied, blue means -moz-pref() resolved
# nothing, red means only the seed is missing, green means everything worked.
{
  pkgs,
  zen-browser-flake,
  ...
}: let
  modId = "nix-test-mod";

  storeHost = "raw.githubusercontent.com";

  certs = pkgs.runCommand "sine-store-certs" {nativeBuildInputs = [pkgs.openssl];} ''
    mkdir -p $out

    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
      -keyout "$out/ca.key" -out "$out/ca.crt" \
      -subj "/CN=Zen Flake Sine Store CA" \
      -addext "basicConstraints=critical,CA:TRUE" \
      -addext "keyUsage=critical,keyCertSign,cRLSign"

    openssl req -newkey rsa:2048 -nodes -sha256 \
      -keyout "$out/server.key" -out "$out/server.csr" -subj "/CN=${storeHost}"

    openssl x509 -req -in "$out/server.csr" -days 3650 -sha256 \
      -CA "$out/ca.crt" -CAkey "$out/ca.key" -CAcreateserial \
      -out "$out/server.crt" \
      -extfile <(printf "subjectAltName=DNS:%s\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n" "${storeHost}")
  '';

  modChromeCss = ./fixtures/sine-mod-chrome.css;

  modPreferences = builtins.toJSON [
    {
      type = "checkbox";
      property = "nixtest.mod.painted";
      label = "Paint the window";
      defaultValue = true;
    }
    {
      type = "string";
      property = "nixtest.mod.accent";
      label = "Accent";
      defaultValue = "#ff0000";
    }
    {
      type = "checkbox";
      property = "nixtest.mod.unset";
      label = "Stays unset";
      defaultValue = false;
    }
  ];

  modProbeJs = ''
    try {
      Services.prefs.setBoolPref("nixtest.script.ran", true);
    } catch (e) {}
  '';

  modSubdir = "nix-test-sub";

  modZip = pkgs.runCommand "${modId}-mod.zip" {nativeBuildInputs = [pkgs.zip];} ''
    mkdir -p mod/${modSubdir}/scripts mod/unrelated-sibling
    cp ${modChromeCss} mod/${modSubdir}/chrome.css
    cp ${pkgs.writeText "preferences.json" modPreferences} mod/${modSubdir}/preferences.json
    cp ${pkgs.writeText "probe.uc.js" modProbeJs} mod/${modSubdir}/scripts/probe.uc.js
    echo "not this one" > mod/unrelated-sibling/README.md
    (cd mod && zip -qrX $out .)
  '';

  marketplace = builtins.toJSON {
    ${modId} = {
      id = modId;
      name = "Nix Test Mod";
      description = "Fixture served by the in-VM Sine store.";
      version = "1.0.0";
      author = "zen-browser-flake tests";
      homepage = "https://github.com/zen-browser-flake/tests/tree/main/${modSubdir}";
      style = "chrome.css";
      preferences = "preferences.json";
      scripts."scripts/"."probe.uc.js" = {};
      fork = ["zen"];
    };
  };

  webroot = pkgs.runCommand "sine-store-webroot" {} ''
    mkdir -p $out/sineorg/store/main/mods/${modId}
    cp ${modZip} $out/sineorg/store/main/mods/${modId}/mod.zip
    cp ${pkgs.writeText "marketplace.json" marketplace} $out/sineorg/store/main/marketplace.json
  '';
in {
  machineModules = [
    {
      virtualisation.memorySize = 4096;
      virtualisation.diskSize = 4096;

      environment.systemPackages = [pkgs.xorg-server pkgs.imagemagick pkgs.xwd];

      security.pki.certificateFiles = ["${certs}/ca.crt"];
      networking.hosts."127.0.0.1" = [storeHost];

      services.nginx = {
        enable = true;
        virtualHosts.${storeHost} = {
          addSSL = true;
          sslCertificate = "${certs}/server.crt";
          sslCertificateKey = "${certs}/server.key";
          root = webroot;
          extraConfig = "access_log /var/log/nginx/store.log;";
        };
      };
    }
  ];

  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser = {
      enable = true;
      profiles.default = {
        id = 0;

        sine.enable = true;
        sine.mods = [modId];

        settings = {
          "zen.welcome-screen.seen" = true;
          "browser.aboutwelcome.enabled" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.startup.homepage_override.mstone" = "ignore";
        };
      };
    };
  };

  testScript = ''
    import json

    profile = "/home/testuser/.config/zen/default"
    mods_dir = profile + "/chrome/sine-mods"

    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(443)

    machine.succeed("systemctl restart home-manager-testuser.service")
    machine.wait_for_unit("home-manager-testuser.service")

    machine.succeed("grep -q 'mods/${modId}/mod.zip' /var/log/nginx/store.log")
    machine.succeed("grep -q 'marketplace.json' /var/log/nginx/store.log")

    machine.succeed(f"test -f {mods_dir}/${modId}/chrome.css")
    machine.succeed(f"test -f {mods_dir}/${modId}/preferences.json")
    machine.succeed(f"test -f {mods_dir}/${modId}/scripts/probe.uc.js")
    machine.fail(f"test -e {mods_dir}/${modId}/${modSubdir}")
    machine.fail(f"test -e {mods_dir}/${modId}/unrelated-sibling")

    mods = json.loads(machine.succeed(f"cat {mods_dir}/mods.json"))
    assert "${modId}" in mods, f"mod never registered: {mods}"
    entry = mods["${modId}"]
    assert entry["enabled"] is True, entry
    assert entry["no-updates"] is True, entry
    assert entry["style"] == {"chrome": "chrome.css", "content": ""}, entry
    assert entry["preferences"] == "preferences.json", entry
    assert entry.get("origin") == "store", entry
    assert entry["scripts"] == {"scripts/": {"probe.uc.js": {}}}, entry

    seed = machine.succeed(f"cat {mods_dir}/nix-default-prefs.json")
    seeded = json.loads(seed)
    assert seeded.get("nixtest.mod.painted") is True, seed
    assert seeded.get("nixtest.mod.accent") == "#ff0000", seed
    assert "nixtest.mod.unset" not in seeded, seed

    state = json.loads(machine.succeed(f"cat {profile}/zen-sine-mods-nix-managed.json"))
    assert state["${modId}"]["source"] == "sine", state
    assert state["${modId}"]["etag"] != "", state

    machine.succeed("systemctl restart home-manager-testuser.service")
    machine.wait_for_unit("home-manager-testuser.service")

    store_log = machine.succeed("cat /var/log/nginx/store.log")
    hits = [line for line in store_log.splitlines() if "mod.zip" in line]
    payloads = len([line for line in hits if '" 200 ' in line])
    revalidations = len([line for line in hits if '" 304 ' in line])
    assert payloads == 1, \
      f"the mod payload was downloaded {payloads} times, a reswitch must not refetch:\n" + store_log
    assert revalidations >= 1, \
      "the second switch never revalidated, it refetched instead:\n" + store_log

    machine.succeed("( nohup Xvfb :99 -screen 0 1024x768x24 </dev/null >>/tmp/xvfb.log 2>&1 & )")
    machine.sleep(2)


    def launch(settle):
        machine.succeed(
            "su - testuser -c '"
            "DISPLAY=:99 nohup zen-beta --no-remote about:blank"
            " >>/tmp/zen.log 2>&1 &'"
        )
        machine.sleep(settle)


    launch(45)
    machine.succeed("pkill -u testuser -f zen || true")
    machine.sleep(5)

    aggregate = machine.succeed(f"cat {mods_dir}/chrome.css")
    assert "${modId}/chrome.css" in aggregate, \
      "Sine did not import the mod stylesheet: " + aggregate

    prefs = machine.succeed(f"cat {profile}/prefs.js")
    assert 'user_pref("nixtest.script.ran", true);' in prefs, \
      "the mod stylesheet loaded but its script never ran: " + prefs

    launch(45)
    machine.succeed("xwd -root -display :99 -silent | convert xwd:- png:/tmp/sine-mod.png")
    machine.copy_from_machine("/tmp/sine-mod.png", "")

    histogram = machine.succeed(
      "convert /tmp/sine-mod.png -depth 8 -format %c histogram:info:-"
    )
    machine.succeed("pkill -u testuser -f zen || true")

    def share(hexcolor):
        for line in histogram.splitlines():
            if hexcolor in line:
                return int(line.split(":")[0].strip())
        return 0


    green = share("#00FF00")
    blue = share("#0000FF")

    assert green + blue + share("#FF0000") > 200000, \
      "the mod stylesheet never painted anything:\n" + histogram
    assert green > blue, (
      "the mod loaded but its -moz-pref() gate stayed inert, so the "
      "defaultValue seed did not reach the pref branch:\n" + histogram
    )
  '';
}
