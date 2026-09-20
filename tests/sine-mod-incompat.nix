{
  pkgs,
  zen-browser-flake,
  ...
}: let
  modId = "nix-incompat-mod";
  storeHost = "raw.githubusercontent.com";

  certs = pkgs.runCommand "sine-incompat-certs" {nativeBuildInputs = [pkgs.openssl];} ''
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

  modZip = pkgs.runCommand "${modId}-mod.zip" {nativeBuildInputs = [pkgs.zip];} ''
    mkdir -p mod
    echo "#browser { background-color: red !important; }" > mod/chrome.css
    (cd mod && zip -qrX $out .)
  '';

  marketplace = builtins.toJSON {
    ${modId} = {
      id = modId;
      name = "Nix Incompatible Mod";
      description = "Declares support for everything except Zen.";
      version = "1.0.0";
      author = "zen-browser-flake tests";
      homepage = "https://github.com/zen-browser-flake/tests";
      style = "chrome.css";
      fork = ["floorp" "firefox" "waterfox" "librewolf"];
    };
  };

  webroot = pkgs.runCommand "sine-incompat-webroot" {} ''
    mkdir -p $out/sineorg/store/main/mods/${modId}
    cp ${modZip} $out/sineorg/store/main/mods/${modId}/mod.zip
    cp ${pkgs.writeText "marketplace.json" marketplace} $out/sineorg/store/main/marketplace.json
  '';
in {
  waitForActivation = false;

  machineModules = [
    {
      security.pki.certificateFiles = ["${certs}/ca.crt"];
      networking.hosts."127.0.0.1" = [storeHost];

      services.nginx = {
        enable = true;
        virtualHosts.${storeHost} = {
          addSSL = true;
          sslCertificate = "${certs}/server.crt";
          sslCertificateKey = "${certs}/server.key";
          root = webroot;
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
      };
    };
  };

  testScript = ''
    mods_dir = "/home/testuser/.config/zen/default/chrome/sine-mods"

    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(443)

    machine.fail("systemctl restart home-manager-testuser.service")

    journal = machine.succeed("journalctl -u home-manager-testuser.service --no-pager")
    assert "cannot run in Zen" in journal, journal
    assert "floorp, firefox, waterfox, librewolf" in journal, journal

    machine.fail(f"test -e {mods_dir}/mods.json && grep -q '${modId}' {mods_dir}/mods.json")
  '';
}
