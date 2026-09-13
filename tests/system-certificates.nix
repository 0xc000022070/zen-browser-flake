{
  pkgs,
  zen-browser-flake,
  ...
}: let
  trustedHost = "zen-flake-trusted.local";
  untrustedHost = "zen-flake-untrusted.local";

  trustedCaName = "Zen Flake Trusted CA";

  certs = pkgs.runCommand "zen-test-certs" {nativeBuildInputs = [pkgs.openssl];} ''
    mkdir -p $out

    mkCa() {
      openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
        -keyout "$out/$1.ca.key" -out "$out/$1.ca.crt" \
        -subj "/CN=$2" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,keyCertSign,cRLSign"
    }

    mkCert() {
      openssl req -newkey rsa:2048 -nodes -sha256 \
        -keyout "$out/$1.key" -out "$out/$1.csr" -subj "/CN=$2"

      openssl x509 -req -in "$out/$1.csr" -days 3650 -sha256 \
        -CA "$out/$1.ca.crt" -CAkey "$out/$1.ca.key" -CAcreateserial \
        -out "$out/$1.crt" \
        -extfile <(printf "subjectAltName=DNS:%s\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n" "$2")
    }

    mkCa trusted "${trustedCaName}"
    mkCa untrusted "Zen Flake Untrusted CA"

    mkCert trusted "${trustedHost}"
    mkCert untrusted "${untrustedHost}"
  '';

  # Onboarding and the default-browser prompt cover the page in the screenshot.
  probePrefs = pkgs.writeText "user.js" ''
    user_pref("zen.welcome-screen.seen", true);
    user_pref("browser.aboutwelcome.enabled", false);
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("browser.shell.checkDefaultBrowser", false);
  '';

  webroot = pkgs.runCommand "zen-test-webroot" {} ''
    mkdir -p $out
    echo "<!doctype html><title>zen tls probe</title><body>ok</body>" > $out/index.html
  '';

  mkVhost = tag: {
    addSSL = true;
    sslCertificate = "${certs}/${tag}.crt";
    sslCertificateKey = "${certs}/${tag}.key";
    root = webroot;
    extraConfig = "access_log /var/log/nginx/${tag}.log;";
  };
in {
  machineModules = [
    {
      virtualisation.memorySize = 4096;

      environment.systemPackages = [pkgs.nss.tools pkgs.imagemagick pkgs.xwd];

      security.pki.certificateFiles = ["${certs}/trusted.ca.crt"];

      networking.hosts."127.0.0.1" = [trustedHost untrustedHost];

      services.nginx = {
        enable = true;
        virtualHosts = {
          ${trustedHost} = mkVhost "trusted";
          ${untrustedHost} = mkVhost "untrusted";
        };
      };
    }
  ];

  homeModule = {
    imports = [zen-browser-flake.homeModules.beta];

    programs.zen-browser.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(443)

    machine.succeed(
        "grep -q '${trustedCaName}' /etc/ssl/trust-source/ca-bundle.trust.p11-kit"
    )

    # Firefox refuses to create a missing --profile directory.
    machine.succeed("install -d -o testuser -g users /home/testuser/probe")
    machine.succeed(
        "install -o testuser -g users -m 644 ${probePrefs} /home/testuser/probe/user.js"
    )

    machine.succeed("( nohup Xvfb :99 -screen 0 1024x768x24 </dev/null >>/tmp/xvfb.log 2>&1 & )")
    machine.sleep(2)


    def launch(urls, shot, settle=60):
        machine.succeed(
            "su - testuser -c '"
            f"DISPLAY=:99 nohup zen-beta --profile /home/testuser/probe {urls}"
            " >>/tmp/zen.log 2>&1 &'"
        )
        machine.sleep(settle)
        # Xvfb is not the QEMU console, so machine.screenshot() would miss it.
        machine.succeed(f"xwd -root -display :99 -silent | convert xwd:- png:/tmp/{shot}")
        machine.copy_from_machine(f"/tmp/{shot}", "")
        machine.succeed("pkill -u testuser -f zen || true")
        machine.sleep(3)


    launch("https://${trustedHost}/", "zen-trusted.png")

    machine.succeed("grep -q 'System Trust' /home/testuser/probe/pkcs11.txt")

    anchors = machine.succeed("certutil -L -d sql:/home/testuser/probe -h 'System Trust'")
    ca = [line for line in anchors.splitlines() if "${trustedCaName}" in line]
    assert ca, anchors
    # Trailing trust triple; "CT" means trusted CA for TLS server auth.
    assert ca[0].split()[-1].startswith("CT"), ca[0]

    # A rejected chain aborts the handshake, so nginx would log nothing.
    machine.succeed("grep -q 'GET / ' /var/log/nginx/trusted.log")

    # The trusted host is repeated as a positive control: without it a broken
    # launch would satisfy the negative assertions for the wrong reason.
    launch(
        "https://${untrustedHost}/ https://${trustedHost}/",
        "zen-untrusted.png",
    )

    served = int(machine.succeed("grep -c 'GET / ' /var/log/nginx/trusted.log"))
    assert served >= 2, f"second launch never reached the trusted host ({served} requests)"

    machine.fail("grep -q 'GET / ' /var/log/nginx/untrusted.log")
  '';
}
