{ lib }:
# genDnsmasqHorizons: horizon -> dnsmasq settings attrset
#
# Phase B: Dead code stub. No callers.
#
# Takes horizon settings (output of mkHorizons) and produces a dnsmasq
# configuration attrset with per-subnet auth-server directives.
#
# Per the plan (§3.5): single dnsmasq instance with per-subnet
# `--auth-server=<zone>,<plane-ip>` directives.  Listens on all addresses
# derived from the host's coordinate.
#
# The returned attrset maps directly to services.dnsmasq.settings:
#   listen-address  — One entry per coordinate element, computed as the
#                     actual IP from (subnet, peer_id).
#   bind-interfaces — true (per plan §3.5).
#   localise-queries — true (per plan §3.5).
#   auth-server     — Phase B: empty.  No topology files have dns.zones
#                     yet.  Phase 5 (C) populates zones from the registry.
#   server          — Upstream DNS servers (stub for Phase B).
#
# Phase 5 (C) wires this into mkDnsSettings and core-router-topology.nix.
horizon:
let
  inherit (builtins) elemAt toString;
  inherit (lib) splitString concatStringsSep init;

  # ── Helpers ─────────────────────────────────────────────────

  # Compute the IP address from a (subnet, peer_id) pair.
  # For subnet "10.88.128.0/24" and peer_id 1 → "10.88.128.1"
  subnetPeerToIP = subnet: peer_id:
    let
      parts   = splitString "/" subnet;
      ip      = elemAt parts 0;                        # "10.88.128.0"
      octets  = splitString "." ip;
      prefix  = concatStringsSep "." (init octets);    # "10.88.128"
    in
      "${prefix}.${toString peer_id}";

  # ── Inputs ──────────────────────────────────────────────────

  coordinate = horizon.coordinate or [];

  # ── Listen addresses ────────────────────────────────────────
  # Listen on every IP address this host has (one per coordinate entry).
  listenAddresses = map (c: subnetPeerToIP c.subnet c.peer_id) coordinate;

  # ── Auth-server entries ─────────────────────────────────────
  # Phase B: Empty.  No topology files have dns.zones yet.
  # Phase 5 (C) will collect zones from topology data and emit:
  #   auth-server = [ "<zone>,<plane-ip>" ... ];
  authServers = [];

in
{
  listen-address  = listenAddresses;
  bind-interfaces = true;
  localise-queries = true;
  auth-server     = authServers;
  server          = [ "8.8.8.8" "1.0.0.1" ];
}
