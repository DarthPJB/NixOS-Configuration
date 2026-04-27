/*
Purpose: Transform topology tailscale config into NixOS tailscale config

Inputs:
- topology.tailscale: tailscale configuration including advertisedHosts, advertisedRoutes, subnetRouter
- topology.lan.hosts: host definitions with IPs and routing attributes

Output: NixOS services.tailscale config
*/

{ lib }:

topology:

let
  utils = import ./utils.nix { inherit lib; };

  inherit (builtins)
    attrValues
    concatStringsSep
    filter
    map
    ;

  # Routes from advertisedHosts: convert host names to /32 routes
  advertisedHostsRoutes = map (
    hostName:
    let
      host = topology.lan.hosts.${hostName} or {};
      ip = host.ip or null;
    in
    if ip != null then "${ip}/32" else null
  ) (topology.tailscale.advertisedHosts or [ ]);

  # Filter out nulls
  validAdvertisedHostsRoutes = filter (x: x != null) advertisedHostsRoutes;

  # Routes from lan.hosts where routing.tailscale = true
  lanTailscaleRoutes = map (host: "${host.ip}/32") (
    filter (host: (host.routing or {}).tailscale or false) (attrValues topology.lan.hosts)
  );

  # Direct advertised routes
  directRoutes = topology.tailscale.advertisedRoutes or [ ];

  # Combine all routes (direct routes first to preserve order)
  allRoutes = directRoutes ++ validAdvertisedHostsRoutes ++ lanTailscaleRoutes;

  # Deduplicate while preserving order of first occurrence
  uniqueRoutes = utils.dedupPreserveOrder (r: r) allRoutes;

  # Enable Tailscale if any routing is configured
  enable = (topology.tailscale.subnetRouter or false) || (uniqueRoutes != [ ]);

  # Build configuration
  config = {
    enable = enable;
  }
  // (if topology.tailscale.subnetRouter or false then { useRoutingFeatures = "server"; } else { })
  // (
    if uniqueRoutes != [ ] then
      { extraSetFlags = [ "--advertise-routes=${concatStringsSep "," uniqueRoutes}" ]; }
    else
      { }
  );

  # Helper function to return just the routes
  mkAdvertisedRoutes = uniqueRoutes;

in
{
  inherit config mkAdvertisedRoutes;
}