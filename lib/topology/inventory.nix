# lib/topology/inventory.nix
#
# Monitoring inventory — the canonical, ordered list of hosts that Prometheus
# scrapes, grouped by job, plus the job unions dashboards query against.
#
# This is the one place where fleet monitoring membership is declared. Dashboard
# generators consume it so that adding or removing a machine updates every
# generated dashboard at once, instead of hand-editing rename transforms and job
# regexes across a dozen JSON files.
#
# Host IPs are derived from the topology registry (JSON), not hardcoded. Only
# genuinely external hosts (Tailscale, out-of-fleet CUDA boxes) carry an
# explicit IP override because they have no topology/<machine>.json.
#
# Pure: registry in, inventory data out. No module system, no user Nix.
{ lib }:
{ registry }:
let
  inherit (builtins) head filter;

  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      networkIp = head parts;
      octets = lib.splitString "." networkIp;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Derive the WireGuard IP for a registry host. Returns null if absent.
  wgIp = name:
    let
      host = registry.hosts.${name} or null;
      coords = filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
    in
    if host != null && coords != [ ] then coordToIp (head coords) else null;

  # Build a node inventory entry. IP is derived from the registry unless an
  # explicit override is supplied for an external host.
  mkNode = { hostname, ip ? null, job ? "node", port ? 9100 }:
    {
      inherit hostname job port;
      ip = if ip != null then ip else wgIp hostname;
    };
in
rec {
  # Ordered hosts exposing node_exporter metrics. Everything scraped under the
  # fleet "node" job plus the two bespoke jobs (Tailscale CI box, CUDA box).
  node = [
    (mkNode { hostname = "cortex-alpha"; })
    (mkNode { hostname = "local-nas"; })
    (mkNode { hostname = "LINDA"; })
    (mkNode { hostname = "terminal-zero"; })
    (mkNode { hostname = "terminal-nx-01"; })
    (mkNode { hostname = "print-controller"; })
    (mkNode { hostname = "remote-worker"; })
    (mkNode { hostname = "remote-builder"; })
    (mkNode { hostname = "gaming-host-1"; })
    (mkNode { hostname = "display-1"; })
    (mkNode { hostname = "display-2"; })
    (mkNode { hostname = "arm-builder"; })
    (mkNode { hostname = "alpha-one"; })
    (mkNode { hostname = "alpha-three"; })
    # External CI builder — Tailscale only, no topology JSON.
    (mkNode { hostname = "hyperhyper"; ip = "100.107.101.14"; job = "hyperhyper-node"; })
    # CUDA inference box — scraped under its own job.
    (mkNode { hostname = "cluster-box"; job = "malayalam-node"; })
  ];

  # Hosts exposing ZFS pool metrics (job "zfs" plus "hyperhyper-zfs").
  zfs = [
    (mkNode { hostname = "local-nas"; job = "zfs"; })
    (mkNode { hostname = "cortex-alpha"; job = "zfs"; })
    (mkNode { hostname = "remote-builder"; job = "zfs"; })
    (mkNode { hostname = "LINDA"; job = "zfs"; })
    (mkNode { hostname = "hyperhyper"; ip = "100.107.101.14"; job = "hyperhyper-zfs"; port = 9134; })
  ];

  # Hosts exposing NVIDIA GPU metrics (job "nvidia").
  nvidia = [
    (mkNode { hostname = "LINDA"; job = "nvidia"; })
    (mkNode { hostname = "alpha-one"; job = "nvidia"; })
    (mkNode { hostname = "alpha-three"; job = "nvidia"; })
    (mkNode { hostname = "terminal-nx-01"; job = "nvidia"; })
  ];

  # PromQL union of every job that exposes node_* metrics.
  nodeJobs = [ "node" "hyperhyper-node" "malayalam-node" ];
}
