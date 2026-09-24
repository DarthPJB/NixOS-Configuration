# lib/monitoring/inventory.nix
#
# Monitoring inventory — the canonical, ordered list of hosts Prometheus
# scrapes, grouped by exporter, plus the job unions dashboards query against.
#
# Built as a UNION of two sources, with stable ordering:
#
#   baseline   the blessed current scrape set (membership + order). Pins every
#              target that is scraped today, including stale ones, so the set
#              only ever grows.
#   discovered config-derived discovery: every prometheus exporter that is
#              actually enabled on a machine, read from evaluated NixOS config
#              (self.nixosConfigurations). Newly-enabled hosts are appended
#              after the baseline in deterministic order.
#
# Host IPs come from the topology registry (JSON). Genuinely external hosts
# (Tailscale CI box, out-of-fleet CUDA box) carry explicit IPs because they
# have no topology/<machine>.json and no NixOS config in this flake.
#
# Job mapping files each exporter under the scrape job that actually consumes
# it (e.g. cluster-box's node exporter is scraped as "malayalam-node", not
# "node"), so dashboards' job unions stay correct as hosts come and go.
#
# NOTE: this file is deliberately NOT part of the topology toolset. It reads
# evaluated NixOS config via `self`, which the pure topology generators must
# never touch. Topology supplies IPs only. See documentation/topology-principle.md.
{ lib }:
{ self, registry }:
let
  inherit (builtins) head filter map attrNames listToAttrs;
  inherit (lib) filterAttrs genAttrs;

  # ── Topology IPs ────────────────────────────────────────────
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      networkIp = head parts;
      octets = lib.splitString "." networkIp;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  wgIp = name:
    let
      host = registry.hosts.${name} or null;
      coords = filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
    in
    if host != null && coords != [ ] then coordToIp (head coords) else null;

  # ── External hosts (no NixOS config in this flake) ──────────
  externals = {
    hyperhyper = {
      ip = "100.107.101.14";
      node = { job = "hyperhyper-node"; port = 9100; };
      zfs = { job = "hyperhyper-zfs"; port = 9134; };
      systemd = { job = "hyperhyper-systemd"; port = 9558; };
    };
  };

  # ── Job mapping ─────────────────────────────────────────────
  # Default job name per exporter, then per-host overrides where a host is
  # filed under a bespoke job.
  exporterJob = {
    nvidia-gpu = "nvidia";
    systemd = "systemd";
  };
  jobOverrides = {
    cluster-box = {
      node = "malayalam-node";
      nvidia-gpu = "malayalam-nvidia";
    };
    hyperhyper = {
      node = "hyperhyper-node";
      zfs = "hyperhyper-zfs";
      systemd = "hyperhyper-systemd";
    };
  };
  jobOf = host: exporter:
    jobOverrides.${host}.${exporter} or exporterJob.${exporter} or exporter;

  # Fallback ports for baseline targets that are not enabled in config
  # (stale scrape entries) — used so their entries stay well-formed.
  defaultPort = {
    node = 9100;
    smartctl = 3107;
    zfs = 3102;
    nvidia-gpu = 3103;
    dnsmasq = 9153;
    klipper = 3104;
    nextcloud = 3106;
    nginx = 3105;
    postgres = 9187;
    systemd = 9558;
  };

  # ── Config-derived discovery ────────────────────────────────
  # Probe one exporter attrset. Returns { port; } when enabled and well-formed,
  # null otherwise. tryEval makes removed/broken exporter options (minio,
  # rspamd, tor, ...) safe to enumerate.
  probeOne = ex:
    let
      r = builtins.tryEval (
        if (ex.enable or false) && (ex ? port)
        then { port = ex.port; }
        else null
      );
    in
    if r.success then r.value else null;

  # Active machines only. Dormant machines (self.dormantConfigurations) are
  # deliberately excluded — they are not deployed and not scraped.
  activeHosts = attrNames self.nixosConfigurations;

  enabledOf = host:
    let
      ex = self.nixosConfigurations.${host}.config.services.prometheus.exporters;
      probed = genAttrs (attrNames ex) (n: probeOne ex.${n});
    in
    filterAttrs (_: v: v != null) probed;

  configHas = host: exporter: (enabledOf host) ? ${exporter};
  externalHas = host: exporter: (externals.${host} or { }) ? ${exporter};

  discoveredHosts = exporter:
    (filter (h: configHas h exporter) activeHosts)
    ++ (filter (h: externalHas h exporter) (attrNames externals));

  # ── Baseline: the blessed current scrape set ────────────────
  # Ordered hostnames per exporter. This is the set scraped today — including
  # stale targets that config introspection would not rediscover. Never shrinks.
  baseline = {
    node = [
      "cortex-alpha"
      "local-nas"
      "LINDA"
      "terminal-zero"
      "terminal-nx-01"
      "print-controller"
      "remote-worker"
      "remote-builder"
      "gaming-host-1"
      "display-1"
      "display-2"
      "arm-builder"
      "alpha-one"
      "alpha-three"
      "hyperhyper"
      "cluster-box"
    ];
    zfs = [ "local-nas" "cortex-alpha" "remote-builder" "LINDA" "hyperhyper" ];
    nvidia-gpu = [ "LINDA" "alpha-one" "alpha-three" "terminal-nx-01" "cluster-box" ];
    smartctl = [
      "cortex-alpha"
      "local-nas"
      "LINDA"
      "terminal-zero"
      "terminal-nx-01"
      "print-controller"
      "remote-worker"
      "remote-builder"
      "gaming-host-1"
      "display-1"
      "display-2"
      "arm-builder"
      "alpha-one"
      "alpha-three"
    ];
    dnsmasq = [ "cortex-alpha" ];
    klipper = [ "print-controller" ];
    nextcloud = [ "remote-worker" ];
    nginx = [ "remote-worker" ];
    postgres = [ "local-nas" ];
    systemd = [ "hyperhyper" ];
  };

  # ── Entry builders ──────────────────────────────────────────
  ipOf = host: (externals.${host} or { }).ip or (wgIp host);

  portOf = host: exporter:
    let
      cfgPort =
        if self.nixosConfigurations ? ${host}
        then ((enabledOf host).${exporter} or { }).port or null
        else null;
      extPort = ((externals.${host} or { }).${exporter} or { }).port or null;
    in
    if cfgPort != null then cfgPort
    else if extPort != null then extPort
    else defaultPort.${exporter} or null;

  entryOf = host: exporter: {
    hostname = host;
    ip = ipOf host;
    job = jobOf host exporter;
    port = portOf host exporter;
  };

  # ── Union with stable ordering ──────────────────────────────
  # Baseline order preserved; discovered-only hosts appended in discovery
  # order (active machine names, then externals).
  unionFor = exporter:
    let
      base = baseline.${exporter} or [ ];
      disc = discoveredHosts exporter;
      extra = filter (h: !(builtins.elem h base)) disc;
    in
    map (h: entryOf h exporter) (base ++ extra);

  node = unionFor "node";
  zfs = unionFor "zfs";
  nvidia = unionFor "nvidia-gpu";
in
{
  # Consumed by lib/topology/genDashboard.nix
  inherit node zfs nvidia;

  # PromQL union of every job that exposes node_* metrics.
  nodeJobs = lib.unique (map (e: e.job) node);

  # Full inventory — Phase 2 (scrape generation) consumes these.
  smartctl = unionFor "smartctl";
  dnsmasq = unionFor "dnsmasq";
  klipper = unionFor "klipper";
  nextcloud = unionFor "nextcloud";
  nginx = unionFor "nginx";
  postgres = unionFor "postgres";
  systemd = unionFor "systemd";
}
