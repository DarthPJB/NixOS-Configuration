{ lib }:

topology:

let
  inherit (builtins) attrNames attrValues concatStringsSep filter listToAttrs map sort;

  # Routes from advertisedHosts: convert host names to /32 routes
  advertisedHostsRoutes = map (hostName:
    let host = topology.lan.hosts.${hostName};
    in "${host.ip}/32"
  ) (topology.tailscale.advertisedHosts or []);

  # Routes from lan.hosts where routing.tailscale = true
  lanTailscaleRoutes = map (host: "${host.ip}/32")
    (filter (host: host.routing.tailscale or false) (attrValues topology.lan.hosts));

  # Direct advertised routes
  directRoutes = topology.tailscale.advertisedRoutes or [];

  # Combine all routes
  allRoutes = directRoutes ++ advertisedHostsRoutes ++ lanTailscaleRoutes;

  # Deduplicate and sort
  uniqueRoutes = sort builtins.lessThan (attrNames (listToAttrs (map (r: { name = r; value = null; }) allRoutes)));

  # Enable Tailscale if any routing is configured
  enable = (topology.tailscale.subnetRouter or false) || (uniqueRoutes != []);

  # Build configuration
  config = {
    enable = enable;
  } // (if topology.tailscale.subnetRouter or false then { useRoutingFeatures = "server"; } else {})
    // (if uniqueRoutes != [] then { extraSetFlags = [ "--advertise-routes=${concatStringsSep "," uniqueRoutes}" ]; } else {});

  # Helper function to return just the routes
  mkAdvertisedRoutes = topology: uniqueRoutes;

in
{
  inherit config mkAdvertisedRoutes;
}