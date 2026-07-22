{ lib }:
# Registry-derived compat shim for shared.nix consumers.
# Phase M-0: Data sourced from JSON topology via mkRegistry.nix.
# To be deleted in Phase M-3 when all consumers are migrated.
let
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };

  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      ip = builtins.head parts;
      octets = lib.splitString "." ip;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in "${prefix}.${toString coord.peer_id}";

  # Find hub hostname for a machine by checking which plane's hub is
  # not this machine (i.e., find coordinates on planes where another
  # host is the hub).
  findHub = name: host:
    let
      coords = host.coordinate or [];
      planeKeys = builtins.attrNames registry.planes;
      matchingPlanes = builtins.filter
        (k:
          let
            plane = registry.planes.${k};
            # Machine is a peer on this plane
            isPeer = builtins.elem name plane.peers;
            # Hub is a different machine
            hubIsOther = plane.hub != name;
          in
          isPeer && hubIsOther
        )
        planeKeys;
    in
    if matchingPlanes != [] then
      registry.planes.${builtins.head matchingPlanes}.hub
    else
      null;

  # Build machine entry matching old shared.nix format
  buildEntry = name: host:
    let
      coords = host.coordinate or [];
      wgCoords = builtins.filter (c: c.plane_name == "wg") coords;
      wgCoord = if wgCoords != [] then builtins.head wgCoords else null;
      # Collect non-wg, non-tailscale coordinates as lan/uplink
      # Skip MAC-based aliases (peer_id with "mac:" interface names)
      otherCoords = builtins.filter
        (c: c.plane_name != "wg" && c.plane_name != "tailscale-platonic"
          && !lib.hasPrefix "mac:" c.interface)
        coords;
      lan = lib.listToAttrs (map (c: {
        name = coordToIp c;
        value = c.interface;
      }) otherCoords);
      hub = findHub name host;
    in
    (if wgCoord != null then { wireguard = coordToIp wgCoord; } else {})
    // (if lan != {} then { inherit lan; } else {})
    // (if hub != null then { inherit hub; } else {});

  # Build full attrset then filter to only entries with wireguard (matching old shared.nix behavior)
  allEntries = lib.mapAttrs buildEntry registry.hosts;
  result = lib.filterAttrs (_name: v: v ? wireguard) allEntries;
in
  result
