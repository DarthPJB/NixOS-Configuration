{ lib }:

topology:

let
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
      host = topology.lan.hosts.${hostName};
    in
    "${host.ip}/32"
  ) (topology.tailscale.advertisedHosts or [ ]);

  # Routes from lan.hosts where routing.tailscale = true
  lanTailscaleRoutes = map (host: "${host.ip}/32") (
    filter (host: host.routing.tailscale or false) (attrValues topology.lan.hosts)
  );

  # Direct advertised routes
  directRoutes = topology.tailscale.advertisedRoutes or [ ];

  # Combine all routes (direct routes first to preserve order)
  allRoutes = directRoutes ++ advertisedHostsRoutes ++ lanTailscaleRoutes;

  # Deduplicate while preserving order of first occurrence
  uniqueRoutes =
    let
      dedup =
        seen: routes:
        if routes == [ ] then
          [ ]
        else
          let
            h = builtins.head routes;
            t = builtins.tail routes;
          in
          if builtins.elem h seen then dedup seen t else [ h ] ++ dedup (seen ++ [ h ]) t;
    in
    dedup [ ] allRoutes;

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
  mkAdvertisedRoutes = topology: uniqueRoutes;

in
{
  inherit config mkAdvertisedRoutes;
}
