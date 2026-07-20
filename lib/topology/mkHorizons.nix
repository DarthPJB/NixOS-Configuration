# lib/topology/mkHorizons.nix
# Phase A: Per-machine horizon transformer.
#
# Consumes the registry (from mkRegistry.nix) and a hostname,
# produces the host's horizon settings:
#
#   coordinate        — List of the host's coordinate entries
#   hub_of            — List of the host's hub_of entries
#   effective_icmp    — Resolved per-interface ICMP settings
#                       (icmp_override[iface] ?? icmp_defaults ?? {pmtud=true, ping=false})
#   applicable_routes — Routes where this host sits on both from_subnet and to_subnet
#   vhostPlanes       — Passthrough of the host's vhost_planes attrset
#   errors            — Validation errors
#   warnings          — Validation warnings
#
# Implementation: §4.2 of the planar topology plan (rev 8).
#
# Invocation:
#   mkHorizons = import ./lib/topology/mkHorizons.nix { inherit lib; };
#   result = mkHorizons { inherit registry; hostname = "cortex-alpha"; };

{ lib }:

let
  inherit (builtins)
    hasAttr isAttrs isList isString length head tail elemAt
    elem filter attrNames attrValues map listToAttrs foldl'
    toString toJSON genList match substring typeOf;

  inherit (lib)
    flatten unique optionals optional filterAttrs concatStringsSep
    sort;

  # ── Default ICMP settings per plan §4.5 ─────────────────────────
  # Every interface gets this default unless overridden by the host's
  # icmp_defaults or icmp_override.
  defaultIcmp = { pmtud = true; ping = false; };

  # ── Helpers ─────────────────────────────────────────────────────

  # Check whether a host "has" a given subnet — meaning the subnet
  # appears in either the host's coordinate entries OR its hub_of
  # entries.  (A host's hub_of subnets are subnets it anchors, so
  # it certainly "has" them for routing purposes.)
  hostHasSubnet = host: subnet:
    let
      coordSubnets = map (c: c.subnet) (host.coordinate or []);
      hubSubnets   = map (h: h.subnet) (host.hub_of or []);
    in
    elem subnet coordSubnets || elem subnet hubSubnets;

  # Compute the set of subnets a host "has" (both coordinate and hub_of)
  hostSubnetsList = host:
    unique (
      (map (c: c.subnet) (host.coordinate or []))
      ++ (map (h: h.subnet) (host.hub_of or []))
    );

  # ── requires_routes validation helpers ──────────────────────────

  # Find all hosts in the registry that have a given subnet
  hostsWithSubnet = registry: subnet:
    filter (h: hostHasSubnet h subnet) (attrValues registry.hosts);

  # Build adjacency for BFS: hosts are connected if they share a subnet.
  # Returns a function: hostname -> list of connected hostnames
  mkAdjacency = registry:
    let
      # For each host, compute its subnet set
      hostSubnetMap = listToAttrs (map (h: {
        name = h.hostname;
        value = hostSubnetsList h;
      }) (attrValues registry.hosts));
    in
    hostname:
      let
        mySubnets = hostSubnetMap.${hostname} or [];
        # Find all other hosts that share at least one subnet with me
        connected = filter (otherHost:
          let
            otherName = otherHost.hostname;
          in
          otherName != hostname
          && lib.any (s: elem s mySubnets) (hostSubnetMap.${otherName} or [])
        ) (attrValues registry.hosts);
      in
      map (h: h.hostname) connected;

  # BFS from start to goal hostnames.  Returns the path (list of hostnames)
  # or null if no path exists.
  bfs = adjacency: startNodes: goalNodes:
    let
      goalSet = listToAttrs (map (n: { name = n; value = true; }) goalNodes);

      search = queue: visited:
        if queue == [] then
          null  # No path found
        else
          let
            # Take the first element from the queue
            current = head queue;
            rest     = tail queue;
            path     = current.path;
            node     = current.node;
          in
          if hasAttr node goalSet then
            path  # Found the goal
          else
            let
              # Expand: get neighbors not yet visited
              allNeighbors = adjacency node;
              newNeighbors = filter (n: !(elem n visited)) allNeighbors;
              newQueue = rest ++ (map (n: { inherit n; path = path ++ [ n ]; }) newNeighbors);
              newVisited = visited ++ newNeighbors;
            in
            search newQueue newVisited;
    in
    search (map (n: { node = n; path = [ n ]; }) startNodes) startNodes;

  # ── Main function ─────────────────────────────────────────────────
  mkHorizons = { registry, hostname }:
  let
    host = registry.hosts.${hostname} or null;
    hostExists = host != null;

    # ── 1. Coordinate (passthrough) ─────────────────────────────────
    coordinate = if hostExists then (host.coordinate or []) else [];

    # ── 2. Hub_of (passthrough) ─────────────────────────────────────
    hub_of = if hostExists then (host.hub_of or []) else [];

    # ── 3. Effective ICMP (per interface) ───────────────────────────
    # Resolution order: icmp_override[iface] ?? icmp_defaults ?? {pmtud=true, ping=false}
    effective_icmp =
      if !hostExists then {}
      else
        let
          # Collect all unique interface names from coordinate entries
          ifaces = map (c: c.interface) coordinate;
          hostOverride  = host.icmp_override or {};
          hostDefaults  = host.icmp_defaults or defaultIcmp;
        in
        listToAttrs (map (iface: {
          name = iface;
          value = if hasAttr iface hostOverride then hostOverride.${iface} else hostDefaults;
        }) ifaces);

    # ── 4. Applicable routes ───────────────────────────────────────
    # A route applies to this host if the host sits on BOTH from_subnet
    # AND to_subnet (typically true for hubs, not for leaves).
    #
    # Routes are collected from every host in the registry, then filtered
    # by this host's subnet membership.
    hostSubnets = hostSubnetsList host;

    allRegistryRoutes = flatten (map (h: h.routes or []) (attrValues registry.hosts));

    routeApplies = route:
      let
        hasFrom = elem route.from_subnet hostSubnets;
        hasTo   = elem route.to_subnet hostSubnets;
      in
      hasFrom && hasTo;

    applicable_routes = filter routeApplies allRegistryRoutes;

    # ── 5. Vhost planes (passthrough) ───────────────────────────────
    vhostPlanes = if hostExists then (host.vhost_planes or {}) else {};

    # ── 6. Validation errors ────────────────────────────────────────
    errors =
      # E1: Host must exist in registry
      (if hostExists then [] else [
        ("ERROR: host '${hostname}' not found in registry; "
         + "available hosts: ${concatStringsSep ", " (attrNames registry.hosts)}")
      ])
      # E2: Host must have at least one coordinate entry
      ++ (if hostExists && (length coordinate) == 0 then [
        ("ERROR: host '${hostname}' has no coordinate entries"
         + " — host not connected to any plane")
      ] else [])
      # E3: requires_routes validation
      ++ (if hostExists then
        flatten (map (rr: validateRequiresRoute rr) (host.requires_routes or []))
      else []);

    # ── 7. Validation warnings ──────────────────────────────────────
    warnings =
      (if hostExists then
        let
          overrides = host.icmp_override or {};
          coordIfaces = map (c: c.interface) coordinate;
          unknownIfaces = filter (iface: !(elem iface coordIfaces)) (attrNames overrides);
        in
        map (iface:
          "WARNING: ${hostname}: icmp_override references interface '${iface}' "
          + "which does not appear in any coordinate entry"
        ) unknownIfaces
      else []);

    # ── Validator for a single requires_routes entry ────────────────
    validateRequiresRoute = rr:
      let
        toSubnet  = rr.to_subnet or null;
        viaSubnet = rr.via_subnet or null;
        reason    = rr.reason or "no reason given";
      in
      # R1: Required fields must be present
      if toSubnet == null || viaSubnet == null then [
        ("ERROR: ${hostname}: requires_routes entry missing required fields "
         + "(need 'via_subnet' and 'to_subnet'); "
         + "got: ${toString (builtins.attrNames rr)}")
      ]
      # R2: If the host is already on the target subnet, no route requirement needed
      else if elem toSubnet hostSubnets then
        []
      # R3: Find hubs that have both via_subnet and to_subnet
      else
        let
          qualifyingHosts = filter
            (h: hostHasSubnet h viaSubnet && hostHasSubnet h toSubnet)
            (attrValues registry.hosts);

          # Sort: trust ascending, then hostname alphabetically
          sortedHosts = sort (a: b:
            let
              aTrust = a.trust or 5;
              bTrust = b.trust or 5;
            in
            if aTrust != bTrust then aTrust < bTrust
            else (a.hostname or "") < (b.hostname or "")
          ) qualifyingHosts;
        in
        if sortedHosts != [] then
          let
            best = head sortedHosts;
          in
          [ ("ERROR: ${hostname}: requires_routes"
             + " '${viaSubnet}' → '${toSubnet}'"
             + " (${reason})"
             + ": suggested route via hub '${best.hostname}'"
             + " (trust ${toString (best.trust or 5)})")
          ]
        else
          # R4: Multi-hop BFS pathfinding
          let
            fromHosts   = hostsWithSubnet registry viaSubnet;
            toHosts     = hostsWithSubnet registry toSubnet;
            adjacencyFn = mkAdjacency registry;
          in
          if fromHosts == [] then
            [ ("ERROR: ${hostname}: requires_routes"
               + " '${viaSubnet}' → '${toSubnet}'"
               + " (${reason})"
               + ": no host in registry has '${viaSubnet}'")
            ]
          else if toHosts == [] then
            [ ("ERROR: ${hostname}: requires_routes"
               + " '${viaSubnet}' → '${toSubnet}'"
               + " (${reason})"
               + ": no host in registry has '${toSubnet}'")
            ]
          else
            let
              fromNames = map (h: h.hostname) fromHosts;
              toNames   = map (h: h.hostname) toHosts;
              path = bfs adjacencyFn fromNames toNames;
            in
            if path != null then
              [ ("ERROR: ${hostname}: requires_routes"
                 + " '${viaSubnet}' → '${toSubnet}'"
                 + " (${reason})"
                 + ": multi-hop path: ${concatStringsSep " → " path}")
              ]
            else
              [ ("ERROR: ${hostname}: requires_routes"
                 + " '${viaSubnet}' → '${toSubnet}'"
                 + " (${reason})"
                 + ": no route path exists through the declared hub network")
              ];

  in
  {
    inherit coordinate hub_of effective_icmp applicable_routes vhostPlanes errors warnings;
  };

in
{
  inherit mkHorizons;
}
