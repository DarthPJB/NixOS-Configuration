# lib/topology/mkRegistry.nix
# Phase 0a: Cross-machine topology registry.
#
# Reads every topology/<machine>.json file via builtins.readDir + builtins.readFile +
# builtins.fromJSON. Produces a validated attrset with:
#
#   hosts    = { hostname = <parsed JSON>; ... }  # 36 entries (all per-host files)
#   shared   = <contents of shared.json>
#   planes   = { "<plane_name>|<subnet>" = { plane_name, subnet, hub, peers, trust }; ... }
#   errors   = [ ... ]  # Non-empty → build fails
#   warnings = [ ... ]
#
# Implementation: §4.1 of the planar topology plan (rev 8).
# All 10 validators from §4.7 are implemented.

{ lib }:

let
  inherit (builtins)
    readDir readFile fromJSON filter attrNames hasAttr isAttrs
    isList isString pathExists length head tail elemAt foldl' all any
    elem toString substring genList match;

  inherit (lib)
    removeSuffix hasSuffix attrValues toInt flatten unique
    concatStringsSep optionals optional filterAttrs mapAttrs
    hasInfix hasPrefix;

  # ── Paths ────────────────────────────────────────────────────
  # The topology directory is ../topology relative to this file
  # (lib/topology/mkRegistry.nix → topology/)
  topologyDir = ../../topology;

  # ── File enumeration ─────────────────────────────────────────
  dirEntries = readDir topologyDir;
  allFileNames = attrNames dirEntries;
  jsonFileNames = filter (n: hasSuffix ".json" n) allFileNames;

  # Special files excluded from per-host parsing
  specialFiles = [ "shared.json" ];
  # Exclude files starting with "_" (template, test fixtures)
  hostFileNames = filter (n: !(builtins.elem n specialFiles) && !(hasPrefix "_" n)) jsonFileNames;

  # ── JSON parsing ─────────────────────────────────────────────
  parseJSON = name: fromJSON (readFile (topologyDir + "/${name}"));

  # Parse all per-host files
  parsedHosts = map parseJSON hostFileNames;

  # Build hosts map keyed by hostname (from the JSON content)
  # If hostname is missing, use fallback key (validator will catch it)
  hosts = builtins.listToAttrs (map
    (h: {
      name = h.hostname or "__MISSING_HOSTNAME__";
      value = h;
    })
    parsedHosts);

  # Parse shared.json separately
  shared = parseJSON "shared.json";

  # ── Plane index construction ─────────────────────────────────
  # Collect all hub_of entries across all hosts
  # Each entry: { plane_name, subnet, hub = hostname }
  allHubOfEntries = flatten (map
    (h:
      map
        (entry: {
          plane_name = entry.plane_name;
          subnet = entry.subnet;
          hub = h.hostname;
        })
        (h.hub_of or [ ])
    )
    (attrValues hosts));

  # Serialize (plane_name, subnet) pair as an attrset key
  # Uses NUL-character separation to avoid collisions with
  # any valid plane_name or subnet characters.
  planeKey = p: s: "${p}\x00${s}";

  # Build planes from hub_of entries, then populate peers from coordinates
  #
  # Internal fields (prefixed with _) are cleaned from the output.
  planes =
    let
      # Step 1: Seed from hub_of entries
      base = foldl'
        (acc: e:
          let k = planeKey e.plane_name e.subnet; in
          if hasAttr k acc then
          # Duplicate hub declaration — mark for validator
            acc // { ${k} = acc.${k} // { _dupHub = true; }; }
          else
            acc // {
              ${k} = {
                plane_name = e.plane_name;
                subnet = e.subnet;
                hub = e.hub;
                peers = [ ];
                trust = null; # filled from coordinates below
              };
            }
        )
        { }
        allHubOfEntries;

      # Step 2: Add peers from each host's coordinate entries
      withPeers = foldl'
        (acc: host:
          foldl'
            (acc2: coord:
              let k = planeKey coord.plane_name coord.subnet; in
              if !(hasAttr k acc2) then
                acc2  # Dangling coordinate — validator catches this
              else
                acc2 // {
                  ${k} = acc2.${k} // {
                    peers = acc2.${k}.peers ++ [ host.hostname ];
                    trust = if acc2.${k}.trust == null then coord.trust else acc2.${k}.trust;
                  };
                }
            )
            acc
            (host.coordinate or [ ])
        )
        base
        (attrValues hosts);
    in
    # Strip internal _-prefixed fields for output
    mapAttrs (k: v: removeAttrs v [ "_dupHub" ]) withPeers;

  # ── Validator 1: Filename/hostname binding ───────────────────
  # topology/<X>.json MUST have "hostname": "<X>".
  vFilenameBinding =
    let
      results = map
        (n:
          let
            baseName = removeSuffix ".json" n;
            content = parseJSON n;
            hn = content.hostname or null;
          in
          if hn == null then
            "ERROR: ${n}: missing 'hostname' field"
          else if hn != baseName then
            "ERROR: ${n}: filename base '${baseName}' ≠ hostname '${hn}'"
          else
            null
        )
        hostFileNames;
    in
    filter (x: x != null) results;

  # ── Validator 2: Plane identifier completeness ───────────────
  # Every hub_of entry must have both plane_name and subnet.
  vPlaneCompleteness =
    let
      results = flatten (map
        (host:
          map
            (entry:
              let
                required = [ "plane_name" "subnet" ];
                missing = filter (f: !hasAttr f entry) required;
              in
              if missing != [ ] then
                "ERROR: ${host.hostname}: hub_of entry missing fields [${concatStringsSep ", " missing}]"
              else
                null
            )
            (host.hub_of or [ ])
        )
        (attrValues hosts));
    in
    filter (x: x != null) results;

  # ── Validator 3 & 4: Plane uniqueness + Hub uniqueness ───────
  # No two distinct (plane_name, subnet) pairs may be identical.
  # Exactly one host per (plane_name, subnet) may declare hub_of.
  vPlaneUniqueness =
    let
      # Group hosts by (plane_name, subnet)
      grouped = foldl'
        (acc: e:
          let k = planeKey e.plane_name e.subnet; in
          acc // { ${k} = (acc.${k} or [ ]) ++ [ e.hub ]; }
        )
        { }
        allHubOfEntries;
      dups = filter (k: length (grouped.${k}) > 1) (attrNames grouped);
    in
    map
      (k:
        "ERROR: plane collision: (${k}) declared as hub_of by multiple hosts: ${concatStringsSep ", " grouped.${k}}"
      )
      dups;

  # ── Validator 5: Sub-hub parent resolution ───────────────────
  # Every parent = { host, subnet } reference resolves to a known hub.
  vParentResolution =
    let
      # Index: (plane_name, subnet) → hub hostname
      hubIndex = foldl'
        (acc: e:
          acc // { ${planeKey e.plane_name e.subnet} = e.hub; }
        )
        { }
        allHubOfEntries;
    in
    filter (x: x != null) (flatten (map
      (host:
        map
          (coord:
            if hasAttr "parent" coord && coord.parent != null then
              let p = coord.parent; in
              if p.host or null == null then
                "ERROR: ${host.hostname}: coordinate '${coord.plane_name}/${coord.subnet}' has parent without 'host' field"
              else if p.subnet or null == null then
                "ERROR: ${host.hostname}: coordinate '${coord.plane_name}/${coord.subnet}' has parent without 'subnet' field"
              else if !(hasAttr p.host hosts) then
                "ERROR: ${host.hostname}: parent host '${p.host}' not found in hosts"
              else
                let pk = planeKey coord.plane_name coord.subnet; in
                if !(hasAttr pk hubIndex) then
                  "ERROR: ${host.hostname}: parent plane '${coord.plane_name}/${coord.subnet}' has no declared hub"
                else if hubIndex.${pk} != p.host then
                  "ERROR: ${host.hostname}: parent host '${p.host}' is not the hub of '${coord.plane_name}/${coord.subnet}' (hub is '${hubIndex.${pk}}')"
                else
                  null
            else null
          )
          (host.coordinate or [ ])
      )
      (attrValues hosts)));

  # ── Validator 6: Cycle detection in parent graph ─────────────
  # DFS on the directed parent graph. A cycle is a node that appears
  # in its own ancestor stack.
  vNoCycles =
    let
      # Build parent map: hostname → parent hostname
      # A host may have multiple coordinates with parents; use the first.
      parentMap = foldl'
        (acc: host:
          let
            parentCoords = filter (c: c.parent or null != null) (host.coordinate or [ ]);
          in
          if parentCoords == [ ] then acc
          else acc // { ${host.hostname} = (head parentCoords).parent.host; }
        )
        { }
        (attrValues hosts);

      # DFS cycle detection
      detectCycle = h: visited: stack:
        if elem h stack then true
        else if elem h visited then false
        else
          let p = parentMap.${h} or null; in
          if p == null then false
          else detectCycle p (visited ++ [ h ]) (stack ++ [ h ]);

      allHostnames = attrNames hosts;
      cyclers = filter (h: detectCycle h [ ] [ ]) allHostnames;
    in
    map
      (h:
        "ERROR: cycle detected in parent graph at host '${h}'"
      )
      cyclers;

  # ── Validator 7: Route requirements ──────────────────────────
  # Every route must have from_subnet, to_subnet, proto, reason.
  vRouteRequirements =
    let
      results = flatten (map
        (host:
          map
            (route:
              let
                required = [ "from_subnet" "to_subnet" "proto" "reason" ];
                missing = filter (f: !hasAttr f route) required;
              in
              if missing != [ ] then
                "ERROR: ${host.hostname}: route missing fields [${concatStringsSep ", " missing}]"
              else
                null
            )
            (host.routes or [ ])
        )
        (attrValues hosts));
    in
    filter (x: x != null) results;

  # ── Validator 8: Coordinate requirements ─────────────────────
  # Every coordinate must have plane_name, subnet, peer_id, trust, interface.
  # interface is REQUIRED and must be non-null.
  vCoordinateRequirements =
    let
      results = flatten (map
        (host:
          map
            (coord:
              let
                required = [ "plane_name" "subnet" "peer_id" "trust" "interface" ];
                missing = filter (f: !hasAttr f coord) required;
                # Specifically check for null interface field
                interfaceMissingOrNull =
                  !(hasAttr "interface" coord) || coord.interface == null;
              in
              if missing != [ ] then
                "ERROR: ${host.hostname}: coordinate missing fields [${concatStringsSep ", " missing}]"
              else if interfaceMissingOrNull then
                "ERROR: ${host.hostname}: coordinate '${coord.plane_name}/${coord.subnet}' missing required 'interface' field"
              else
                null
            )
            (host.coordinate or [ ])
        )
        (attrValues hosts));
    in
    filter (x: x != null) results;

  # ── Validator 9: Public key file existence ───────────────────
  # If public_key_file is non-null, the file must exist on disk.
  vPublicKeyFiles =
    let
      results = map
        (host:
          let
            pkf = host.public_key_file or null;
          in
          if pkf != null then
          # Resolve relative to repo root (../../ from lib/topology/)
            let fullPath = ../../${pkf}; in
            if pathExists fullPath then null
            else "ERROR: ${host.hostname}: public_key_file '${pkf}' not found at '${toString fullPath}'"
          else null
        )
        (attrValues hosts);
    in
    filter (x: x != null) results;

  # ── Validator 10: Dangling coordinate detection ──────────────
  # Every coordinate's (plane_name, subnet) pair must appear in
  # exactly one host's hub_of.
  vDanglingCoordinates =
    let
      hubPlaneKeys = map (e: planeKey e.plane_name e.subnet) allHubOfEntries;
    in
    filter (x: x != null) (flatten (map
      (host:
        map
          (coord:
            let k = planeKey coord.plane_name coord.subnet; in
            if !(builtins.elem k hubPlaneKeys) then
              "ERROR: ${host.hostname}: coordinate '${coord.plane_name}/${coord.subnet}' has no matching hub_of on any host"
            else
              null
          )
          (host.coordinate or [ ])
      )
      (attrValues hosts)));

  # ── Extra: Peer ID uniqueness ────────────────────────────────
  # No two coordinates in the entire registry share the same
  # (plane_name, subnet, peer_id) triple.
  vPeerIdUniqueness =
    let
      groups = foldl'
        (acc: host:
          foldl'
            (innerAcc: coord:
              let
                k = "${planeKey coord.plane_name coord.subnet}\x00${toString coord.peer_id}";
                entry = "${host.hostname}:peer_id=${toString coord.peer_id}";
              in
              innerAcc // { ${k} = (innerAcc.${k} or [ ]) ++ [ entry ]; }
            )
            acc
            (host.coordinate or [ ])
        )
        { }
        (attrValues hosts);

      dups = filter (k: length (groups.${k}) > 1) (attrNames groups);
    in
    map
      (k:
        "ERROR: peer_id collision (${k}): ${concatStringsSep ", " groups.${k}}"
      )
      dups;

  # ── Extra: ICMP override interface validation ────────────────
  # Every key in icmp_override must match a coordinate's interface.
  vIcmpOverrideInterfaces =
    let
      allCoordInterfaces = unique (flatten (map
        (host:
          map (c: c.interface or null) (host.coordinate or [ ])
        )
        (attrValues hosts)));
    in
    filter (x: x != null) (flatten (map
      (host:
        let overrides = host.icmp_override or { }; in
        map
          (iface:
            if !(elem iface allCoordInterfaces) then
              "WARNING: ${host.hostname}: icmp_override interface '${iface}' not found in any coordinate entry"
            else null
          )
          (attrNames overrides)
      )
      (attrValues hosts)));

  # ── Extra: Subnet size validation ────────────────────────────
  # /N for N ≤ 24 is accepted. N > 24 is rejected.
  # (The tailscale /10 exception is handled separately in
  #  consumer code; the registry enforces the baseline rule.)
  vSubnetSizes =
    filter (x: x != null) (flatten (map
      (host:
        map
          (coord:
            let
              # Use match with capture group to extract mask
              m = builtins.match "(.*)/([0-9]+)" coord.subnet;
            in
            if m == null then
              "ERROR: ${host.hostname}: subnet '${coord.subnet}' is not valid CIDR (expected format: <prefix>/<mask>)"
            else
              let
                maskStr = elemAt m 1;
                mask = fromJSON maskStr;
              in
              if mask > 24 then
                "ERROR: ${host.hostname}: subnet '${coord.subnet}' has mask /${toString mask} which exceeds maximum /24"
              else
                null
          )
          (host.coordinate or [ ])
      )
      (attrValues hosts)));

  # ── Extra: Orphan wg_peer warning ────────────────────────────
  # A shared.json wg_peers entry without a corresponding
  # topology/<name>.json produces a warning.
  vOrphanWgPeers =
    let
      wgPeers = shared.wg_peers or { };
      hostnames = attrNames hosts;
    in
    filter (x: x != null) (map
      (peer:
        if !(elem peer hostnames) then
          "WARNING: shared.json wg_peers entry '${peer}' has no corresponding topology/<name>.json file"
        else null
      )
      (attrNames wgPeers));

  # ── Validator: exporters shape ───────────────────────────────
  vExportersShape =
    flatten (map
      (host:
        let
          exp = host.exporters or null;
        in
        if exp == null then
          [ ]  # absent is fine
        else if !isAttrs exp then
          [ "ERROR: ${host.hostname}: exporters must be an attrset, got ${builtins.typeOf exp}" ]
        else
          [ ])
      (attrValues hosts));

  # ── Aggregate results ────────────────────────────────────────
  allErrors = flatten [
    vFilenameBinding
    vPlaneCompleteness
    vPlaneUniqueness
    vParentResolution
    vNoCycles
    vRouteRequirements
    vCoordinateRequirements
    vPublicKeyFiles
    vDanglingCoordinates
    vPeerIdUniqueness
    vSubnetSizes
    vExportersShape
  ];

  allWarnings = flatten [
    vOrphanWgPeers
    vIcmpOverrideInterfaces
  ];

in
{
  hosts = hosts;
  shared = shared;
  planes = planes;
  errors = allErrors;
  warnings = allWarnings;
}
