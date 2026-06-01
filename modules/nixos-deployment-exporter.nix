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


    class DeploymentCollector:
        """Prometheus collector for NixOS deployment state."""

        def __init__(self):
            # Build-time metadata (info metrics — value always 1, labels carry data)
            self.nixos_version = Gauge(
                'nixos_version_info',
                'NixOS version information',
                ['version', 'release', 'state_version'],
            )
            self.flake_info = Gauge(
                'nixos_flake_info',
                'Flake and nixpkgs metadata from build time',
                ['flake_revision', 'nixpkgs_revision', 'hostname'],
            )

            # Generation tracking
            self.generation_number = Gauge(
                'nixos_generation_number',
                'NixOS system generation number',
                ['type'],
            )
            self.generation_match = Gauge(
                'nixos_generation_match',
                '1 if booted generation matches current, 0 if in test mode',
            )

            # Activation timestamp
            self.activation_timestamp = Gauge(
                'nixos_activation_timestamp_seconds',
                'Timestamp of last nixos-rebuild switch/test (Unix epoch)',
            )

            # Runtime
            self.kernel_version = Gauge(
                'nixos_kernel_version_info',
                'Kernel version information',
                ['version'],
            )
            self.uptime_seconds = Gauge(
                'nixos_uptime_seconds',
                'System uptime in seconds',
            )

            # Error tracking
            self.collect_errors = Counter(
                'nixos_deployment_exporter_errors_total',
                'Total errors collecting deployment metrics',
            )

        def collect(self):
            errors = 0

            # Build-time metadata
            try:
                meta = load_json_file(BUILD_METADATA_PATH)
                if meta:
                    self.nixos_version.labels(
                        version=meta.get('nixosVersion', 'unknown'),
                        release=meta.get('nixosRelease', 'unknown'),
                        state_version=meta.get('stateVersion', 'unknown'),
                    ).set(1)
                    self.flake_info.labels(
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
                    self.generation_number.labels(type='current').set(current_gen)
                if booted_gen is not None:
                    self.generation_number.labels(type='booted').set(booted_gen)
                if current_gen is not None and booted_gen is not None:
                    self.generation_match.set(1 if current_gen == booted_gen else 0)
            except Exception:
                errors += 1

            # Activation timestamp
            try:
                state = load_json_file(STATE_FILE)
                ts = state.get('activation_timestamp')
                if ts is not None:
                    self.activation_timestamp.set(ts)
            except Exception:
                errors += 1

            # Runtime
            try:
                kernel = get_kernel_version()
                if kernel:
                    self.kernel_version.labels(version=kernel).set(1)
            except Exception:
                errors += 1

            try:
                uptime = get_uptime()
                if uptime is not None:
                    self.uptime_seconds.set(uptime)
            except Exception:
                errors += 1

            if errors > 0:
                self.collect_errors.inc(errors)

            yield self.nixos_version
            yield self.flake_info
            yield self.generation_number
            yield self.generation_match
            yield self.activation_timestamp
            yield self.kernel_version
            yield self.uptime_seconds
            yield self.collect_errors


    class MetricsHandler(http.server.BaseHTTPRequestHandler):
        """HTTP handler serving Prometheus metrics."""

        collector = None

        def do_GET(self):
            if self.path in ('/metrics', '/'):
                registry = CollectorRegistry()
                registry.register(self.collector)
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

        collector = DeploymentCollector()
        MetricsHandler.collector = collector

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
