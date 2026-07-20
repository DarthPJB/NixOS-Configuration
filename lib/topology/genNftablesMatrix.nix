{ lib }:

# genNftablesMatrix: horizon -> nftables ruleset string
#
# Phase B: Dead code stub. No callers.
#
# Takes horizon settings (output of mkHorizons) and produces an
# nftables ruleset string for the host.
#
# The ruleset includes:
#   - table inet filter:
#     - INPUT chain:   PMTUD ICMP (always), per-interface ICMP echo,
#                      per-subnet allow rules for services
#     - FORWARD chain: composed routes (from applicable_routes)
#   - table ip nat:
#     - PREROUTING chain:  DNAT for port forwarding
#     - POSTROUTING chain: masquerade for private subnets on WAN interfaces
#
# Per the plan (§3.4), this replaces the legacy dual-implementation
# (iptables firewall module + nftables forwarding module from mkForwarding.nix).
#
# Phase B limitations:
#   - FORWARD chain rules are empty (no "routes" in per-host JSON yet)
#   - Allow rules (per-subnet service ACLs) are empty (no "services" in
#     per-host JSON yet)
#   - DNAT rules are empty (will come from routes.port_forward in Phase 5)
#
# Phase 5 (C) wires this into a generator entry point and then into
# core-router-topology.nix.

let
  inherit (builtins)
    elemAt toString hasAttr filter listToAttrs concatLists elem fromJSON match;
  inherit (lib) splitString concatStringsSep;

  # ── Private subnet check ──────────────────────────────────────────
  # Returns true if the subnet is in a private/reserved range
  # (RFC1918: 10/8, 172.16/12, 192.168/16;
  #  CGNAT:  100.64/10;
  #  Loopback: 127/8;
  #  Link-local: 169.254/16;
  #  IPv6 ULA: fc00::/7;
  #  IPv6 link-local: fe80::/10;
  #  IPv6 documentation: 2001:db8::/32).
  isPrivateSubnet = subnet:
    let
      ip = elemAt (splitString "/" subnet) 0;
      isIpv6 = match ".*:.*" ip != null;
    in
    if isIpv6 then
      let
        hextets = splitString ":" ip;
        firstHexet = elemAt hextets 0;
        secondHexet = elemAt hextets 1;
      in
      # ULA: fc00::/7 -> first hextet starts with fc or fd
      (match "f[cd].*" firstHexet != null)
      # Link-local: fe80::/10
      || firstHexet == "fe80"
      # Documentation: 2001:db8::/32
      || (firstHexet == "2001"
        && (secondHexet == "db8" || secondHexet == "0db8"))
    else
      let
        oct1 = elemAt (splitString "." ip) 0;
        oct2 = elemAt (splitString "." ip) 1;
      in
      # RFC1918: 10.0.0.0/8
      oct1 == "10"
      # Loopback: 127.0.0.0/8
      || oct1 == "127"
      # CGNAT: 100.64.0.0/10
      || (oct1 == "100" && fromJSON oct2 >= 64 && fromJSON oct2 <= 127)
      # RFC1918: 172.16.0.0/12
      || (oct1 == "172"
      && elem oct2 [
        "16" "17" "18" "19" "20"
        "21" "22" "23" "24" "25"
        "26" "27" "28" "29" "30" "31"
      ])
      # RFC1918: 192.168.0.0/16
      || oct1 == "192"
      # Link-local: 169.254.0.0/16
      || (oct1 == "169" && oct2 == "254");

  # ── Ruleset generator ────────────────────────────────────────────
  genRuleset = horizon:
    let
      # ── Inputs from horizon ─────────────────────────────────────────

      coordinate = horizon.coordinate or [ ];
      hub_of = horizon.hub_of or [ ];
      effectiveIcmp = horizon.effective_icmp or { };
      applicableRoutes = horizon.applicable_routes or [ ];

      # All interface names from coordinate entries
      interfaceList = map (c: c.interface) coordinate;

      # Build interface  → subnet  lookup (for ping rules, etc.)
      ifaceSubnetMap = listToAttrs (map
        (c: {
          name = c.interface;
          value = c.subnet;
        })
        coordinate);

      # Build subnet → interface lookup (for route composition)
      subnetIfaceMap = listToAttrs (map
        (c: {
          name = c.subnet;
          value = c.interface;
        })
        coordinate);

      # Determine WAN interfaces: coordinate entries whose subnet is NOT private
      wanIfaces = map (c: c.interface) (
        filter (c: !isPrivateSubnet c.subnet) coordinate
      );

      # Private subnets to masquerade (from hub_of entries that are private).
      # These are the subnets this host anchors on private address space.
      privateHubSubnets = map (h: h.subnet) (
        filter (h: isPrivateSubnet h.subnet) hub_of
      );

      # ── 1. INPUT chain rules ────────────────────────────────────────

      # PMTUD ICMP (types 3, 11, 12) — always allowed on all interfaces.
      # Required for Path MTU Discovery to function correctly.
      pmtudRule =
        "ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept";

      # Per-interface ICMP echo — only if effective_icmp[iface].ping is true.
      pingRules = concatLists (map
        (iface:
          if effectiveIcmp.${iface}.ping or false then
            [ "iifname \"${iface}\" ip protocol icmp icmp type { echo-request, echo-reply } accept" ]
          else
            [ ]
        )
        interfaceList);

      # Per-subnet allow rules for services (ssh, http, https, etc.).
      # Phase B: empty.  No per-host JSON files have "services" yet.
      allowRules = [ ];

      # ── 2. FORWARD chain rules ──────────────────────────────────────
      # Composed from applicable_routes.  A route from subnet A to subnet B
      # becomes:  iifname "<iface-A>" oifname "<iface-B>" accept
      #
      # Phase B: applicable_routes is empty (no "routes" in per-host JSON yet).
      forwardRules = concatLists (map
        (route:
          let
            fromIface = subnetIfaceMap.${route.from_subnet} or null;
            toIface = subnetIfaceMap.${route.to_subnet} or null;
          in
          if fromIface != null && toIface != null then
            [ "iifname \"${fromIface}\" oifname \"${toIface}\" accept" ]
          else
            [ ]
        )
        applicableRoutes);

      # ── 3. nat table rules ──────────────────────────────────────────

      # DNAT rules — Phase B: empty.
      # Will be populated from route.port_forward entries in Phase 5.
      dnRules = [ ];

      # Masquerade rules: for each WAN interface, masquerade each private
      # hub subnet going out.
      masqueradeRules = concatLists (map
        (wanIface:
          map
            (subnet:
              "oifname \"${wanIface}\" ip saddr ${subnet} masquerade"
            )
            privateHubSubnets
        )
        wanIfaces);

      # ── Output assembly ─────────────────────────────────────────────

      inputChainRules = concatStringsSep "\n      " (
        [
          "ct state established,related accept"
          "iif \"lo\" accept"
          pmtudRule
        ]
        ++ pingRules
        ++ allowRules
      );

      forwardChainRules =
        if forwardRules == [ ] then
          "ct state established,related accept\n      # Phase B: no routes composed yet"
        else
          "ct state established,related accept\n      ${concatStringsSep "\n      " forwardRules}";

      natPreroutingRules =
        if dnRules == [ ] then
          "# Phase B: no DNAT rules yet"
        else
          concatStringsSep "\n      " dnRules;

      natPostroutingRules =
        if masqueradeRules == [ ] then
          "# No masquerade: no WAN interface detected"
        else
          concatStringsSep "\n      " masqueradeRules;

    in
    ''
      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;
          ${inputChainRules}
        }

        chain forward {
          type filter hook forward priority 0; policy drop;
          ${forwardChainRules}
        }
      }

      table ip nat {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          ${natPreroutingRules}
        }

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          ${natPostroutingRules}
        }
      }
    '';

in
{
  inherit isPrivateSubnet genRuleset;
}
