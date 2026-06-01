# modules/nixos-deployment-exporter.nix
# Prometheus exporter for NixOS deployment state tracking
#
# Two data sources:
# 1. Build-time metadata (Nix store): flake revision, nixpkgs revision, NixOS version
# 2. Activation timestamp (/var/lib/nixos-deployment/): written on every nixos-rebuild switch/test
{ config
, lib
, pkgs
, self
, ...
}:

let
  cfg = config.services.nixos-deployment-exporter;

  python = pkgs.python3.withPackages (ps: [ ps.prometheus-client ]);

  # Build-time metadata — baked into the Nix store, deterministic per generation
  buildMetadata = pkgs.writeText "nixos-deployment-metadata.json" (builtins.toJSON {
    nixosVersion = config.system.nixos.version;
    nixosRelease = config.system.nixos.release;
    nixpkgsRevision = self.inputs.nixpkgs_stable.rev or "dirty";
    nixpkgsShortRev = self.inputs.nixpkgs_stable.shortRev or "dirty";
    flakeRevision = self.rev or "dirty";
    flakeShortRev = self.shortRev or "dirty";
    hostname = config.networking.hostName;
    stateVersion = config.system.stateVersion;
  });

  metadataPath = "/etc/nixos-deployment-metadata.json";
  stateDir = "/var/lib/nixos-deployment";
  stateFile = "${stateDir}/state.json";

  exporterScript = pkgs.writeScript "nixos-deployment-exporter.py" ''
    #!${python}/bin/python3
    """
    NixOS Deployment State Prometheus Exporter

    Reads:
    - Build-time metadata from ${metadataPath} (Nix store, per-generation)
    - Activation timestamp from ${stateFile} (written on nixos-rebuild switch)
    - Runtime system state (generation symlinks, uptime, kernel version)
    """

    import http.server
    import json
    import os
    import re
    import socketserver
    import sys
    from pathlib import Path

    from prometheus_client import (
        CONTENT_TYPE_LATEST,
        CollectorRegistry,
        Counter,
        Gauge,
        generate_latest,
    )

    BUILD_METADATA_PATH = "${metadataPath}"
    STATE_FILE = "${stateFile}"


    def load_json_file(path):
        """Load a JSON file, return dict or empty dict on error."""
        try:
            return json.loads(Path(path).read_text())
        except Exception:
            return {}


    def get_current_generation():
        """Get the current (latest) generation number."""
        system_link = Path("/nix/var/nix/profiles/system")
        if not system_link.is_symlink():
            return None
        try:
            target = os.readlink(str(system_link))
            match = re.search(r'system-(\d+)-link', target)
            return int(match.group(1)) if match else None
        except Exception:
            return None


    def get_booted_generation():
        """Get the currently booted generation by comparing store paths."""
        system_link = Path("/nix/var/nix/profiles/system")
        current_system = Path("/run/current-system")
        if not system_link.exists() or not current_system.exists():
            return None
        try:
            current_path = str(system_link.resolve())
            booted_path = str(current_system.resolve())
            if current_path == booted_path:
                target = os.readlink(str(system_link))
                match = re.search(r'system-(\d+)-link', target)
                return int(match.group(1)) if match else None
            else:
                profiles = Path("/nix/var/nix/profiles")
                for entry in sorted(profiles.iterdir()):
                    if entry.name.startswith("system-") and entry.name.endswith("-link"):
                        if str(entry.resolve()) == booted_path:
                            match = re.search(r'system-(\d+)-link', entry.name)
                            return int(match.group(1)) if match else None
                return None
        except Exception:
            return None


    def get_kernel_version():
        """Get kernel version from uname."""
        try:
            return os.uname().release
        except Exception:
            return None


    def get_uptime():
        """Get system uptime in seconds from /proc/uptime."""
        try:
            with open("/proc/uptime", "r") as f:
                return int(float(f.read().split()[0]))
        except Exception:
            return None


    # Global registry — metrics registered once
    registry = CollectorRegistry()

    # Build-time metadata (info metrics — value always 1, labels carry data)
    nixos_version = Gauge(
        'nixos_version_info', 'NixOS version information',
        ['version', 'release', 'state_version'], registry=registry,
    )
    flake_info = Gauge(
        'nixos_flake_info', 'Flake and nixpkgs metadata from build time',
        ['flake_revision', 'nixpkgs_revision', 'hostname'], registry=registry,
    )

    # Generation tracking
    generation_number = Gauge(
        'nixos_generation_number', 'NixOS system generation number',
        ['type'], registry=registry,
    )
    generation_match = Gauge(
        'nixos_generation_match',
        '1 if booted generation matches current, 0 if in test mode',
        registry=registry,
    )

    # Activation timestamp
    activation_timestamp = Gauge(
        'nixos_activation_timestamp_seconds',
        'Timestamp of last nixos-rebuild switch/test (Unix epoch)',
        registry=registry,
    )

    # Runtime
    kernel_version = Gauge(
        'nixos_kernel_version_info', 'Kernel version information',
        ['version'], registry=registry,
    )
    uptime_seconds = Gauge(
        'nixos_uptime_seconds', 'System uptime in seconds',
        registry=registry,
    )

    # Error tracking
    collect_errors = Counter(
        'nixos_deployment_exporter_errors_total',
        'Total errors collecting deployment metrics', registry=registry,
    )


    def update_metrics():
        """Read system state and update all metrics."""
        errors = 0

        # Build-time metadata
        try:
            meta = load_json_file(BUILD_METADATA_PATH)
            if meta:
                nixos_version.labels(
                    version=meta.get('nixosVersion', 'unknown'),
                    release=meta.get('nixosRelease', 'unknown'),
                    state_version=meta.get('stateVersion', 'unknown'),
                ).set(1)
                flake_info.labels(
                    flake_revision=meta.get('flakeRevision', 'unknown'),
                    nixpkgs_revision=meta.get('nixpkgsRevision', 'unknown'),
                    hostname=meta.get('hostname', 'unknown'),
                ).set(1)
        except Exception:
            errors += 1

        # Generation state
        try:
            current_gen = get_current_generation()
            booted_gen = get_booted_generation()
            if current_gen is not None:
                generation_number.labels(type='current').set(current_gen)
            if booted_gen is not None:
                generation_number.labels(type='booted').set(booted_gen)
            if current_gen is not None and booted_gen is not None:
                generation_match.set(1 if current_gen == booted_gen else 0)
        except Exception:
            errors += 1

        # Activation timestamp
        try:
            state = load_json_file(STATE_FILE)
            ts = state.get('activation_timestamp')
            if ts is not None:
                activation_timestamp.set(ts)
        except Exception:
            errors += 1

        # Runtime
        try:
            kv = get_kernel_version()
            if kv:
                kernel_version.labels(version=kv).set(1)
        except Exception:
            errors += 1

        try:
            up = get_uptime()
            if up is not None:
                uptime_seconds.set(up)
        except Exception:
            errors += 1

        if errors > 0:
            collect_errors.inc(errors)


    class MetricsHandler(http.server.BaseHTTPRequestHandler):
        """HTTP handler serving Prometheus metrics."""

        def do_GET(self):
            if self.path in ('/metrics', '/'):
                update_metrics()
                output = generate_latest(registry)
                self.send_response(200)
                self.send_header('Content-Type', CONTENT_TYPE_LATEST)
                self.send_header('Content-Length', str(len(output)))
                self.end_headers()
                self.wfile.write(output)
            elif self.path == '/health':
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK\n')
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, format, *args):
            pass  # Suppress request logging


    def main():
        import argparse
        parser = argparse.ArgumentParser(description='NixOS Deployment State Exporter')
        parser.add_argument('--port', type=int, default=${toString cfg.port})
        parser.add_argument('--host', default='${cfg.listenAddress}')
        args = parser.parse_args()

        socketserver.TCPServer.allow_reuse_address = True
        with socketserver.TCPServer((args.host, args.port), MetricsHandler) as httpd:
            print(f"NixOS Deployment Exporter listening on {args.host}:{args.port}")
            httpd.serve_forever()


    if __name__ == '__main__':
        main()
  '';
in
{
  options.services.nixos-deployment-exporter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NixOS deployment state Prometheus exporter";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3111;
      description = "Port to listen on";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    # Build-time metadata — written into the Nix store as a JSON file
    environment.etc."nixos-deployment-metadata.json".source = buildMetadata;

    # State directory for activation timestamps
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];

    # Activation script — writes timestamp on every nixos-rebuild switch/test
    system.activationScripts.nixos-deployment-state = {
      deps = [ "etc" ];
      text = ''
        mkdir -p ${stateDir}
        ${pkgs.coreutils}/bin/date +%s > ${stateDir}/activation-timestamp
        ${pkgs.coreutils}/bin/date -Iseconds > ${stateDir}/activation-iso
        ${pkgs.coreutils}/bin/printf '{"activation_timestamp":%d,"generation":%d,"hostname":"%s"}\n' \
          "$(${pkgs.coreutils}/bin/date +%s)" \
          "$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system | ${pkgs.gnused}/bin/sed -n 's/.*system-\([0-9]*\)-link/\1/p')" \
          "${config.networking.hostName}" \
          > ${stateFile}
      '';
    };

    # Exporter service
    systemd.services.nixos-deployment-exporter = {
      description = "NixOS Deployment State Prometheus Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        ExecStart = "${python}/bin/python3 ${exporterScript}";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadOnlyPaths = [
          "/nix/var/nix/profiles"
          "/run/current-system"
          "/proc/uptime"
          "/etc/os-release"
          "/etc/nixos-deployment-metadata.json"
          stateDir
        ];
      };
    };
  };
}
