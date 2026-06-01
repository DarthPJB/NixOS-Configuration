# modules/nixos-deployment-exporter.nix
# Prometheus exporter for NixOS deployment state tracking
#
# Exposes metrics about:
# - NixOS generation number (booted vs current — detects test mode)
# - NixOS version
# - Kernel version
# - System build timestamp
# - System uptime
{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.nixos-deployment-exporter;

  python = pkgs.python3.withPackages (ps: [ ps.prometheus-client ]);

  exporterScript = pkgs.writeScript "nixos-deployment-exporter.py" ''
    #!${python}/bin/python3
    """
    NixOS Deployment State Prometheus Exporter

    Reads system metadata from standard NixOS paths and exposes
    deployment state metrics for Prometheus scraping.
    """

    import http.server
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


    def get_generation_number(path):
        """Extract generation number from a NixOS system profile path."""
        try:
            resolved = path.resolve()
            match = re.search(r'system-(\d+)-link', str(resolved))
            return int(match.group(1)) if match else None
        except Exception:
            return None


    def get_current_generation():
        """Get the current (latest) generation number and build time."""
        system_profiles = Path("/nix/var/nix/profiles/system")
        default_link = system_profiles / "default"

        if not default_link.is_symlink():
            return None, None

        generation = get_generation_number(default_link)
        build_time = None
        try:
            build_time = int(default_link.stat().st_mtime)
        except Exception:
            pass

        return generation, build_time


    def get_booted_generation():
        """Get the currently booted generation number."""
        current_system = Path("/run/current-system")
        if not current_system.exists():
            return None
        return get_generation_number(current_system)


    def get_nixos_version():
        """Get NixOS version from /etc/os-release."""
        try:
            content = Path("/etc/os-release").read_text()
            match = re.search(r'VERSION="([^"]+)"', content)
            return match.group(1) if match else None
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
            self.generation_number = Gauge(
                'nixos_generation_number',
                'NixOS system generation number',
                ['type'],
            )
            self.nixos_version = Gauge(
                'nixos_version_info',
                'NixOS version information',
                ['version'],
            )
            self.kernel_version = Gauge(
                'nixos_kernel_version_info',
                'Kernel version information',
                ['version'],
            )
            self.build_timestamp = Gauge(
                'nixos_build_timestamp_seconds',
                'System build timestamp (Unix epoch)',
            )
            self.uptime_seconds = Gauge(
                'nixos_uptime_seconds',
                'System uptime in seconds',
            )
            self.generation_match = Gauge(
                'nixos_generation_match',
                '1 if booted generation matches current, 0 if in test mode',
            )
            self.collect_errors = Counter(
                'nixos_deployment_exporter_errors_total',
                'Total errors collecting deployment metrics',
            )

        def collect(self):
            errors = 0

            try:
                current_gen, build_time = get_current_generation()
                booted_gen = get_booted_generation()

                if current_gen is not None:
                    self.generation_number.labels(type='current').set(current_gen)
                if booted_gen is not None:
                    self.generation_number.labels(type='booted').set(booted_gen)
                if build_time is not None:
                    self.build_timestamp.set(build_time)
                if current_gen is not None and booted_gen is not None:
                    self.generation_match.set(1 if current_gen == booted_gen else 0)
            except Exception:
                errors += 1

            try:
                version = get_nixos_version()
                if version:
                    self.nixos_version.labels(version=version).set(1)
            except Exception:
                errors += 1

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

            yield self.generation_number
            yield self.nixos_version
            yield self.kernel_version
            yield self.build_timestamp
            yield self.uptime_seconds
            yield self.generation_match
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
    systemd.services.nixos-deployment-exporter = {
      description = "NixOS Deployment State Prometheus Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        ExecStart = "${python}/bin/python3 ${exporterScript}";
        # Only needs to read system metadata
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadOnlyPaths = [
          "/nix/var/nix/profiles"
          "/run/current-system"
          "/proc/uptime"
          "/etc/os-release"
        ];
      };
    };
  };
}
