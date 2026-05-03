{ lib }:

topology:

let
  wanInterface = topology.lan.wanInterface or "wan";
  subnet = topology.lan.subnet or "10.0.0.0/8";

  # Map "wan" to the actual wanInterface from topology
  resolveInterface = iface:
    if iface == "wan" then wanInterface else iface;

  # Generate nftables DNAT rule for a forwarding entry
  mkDnatRule = protocol: rule:
    let
      iface = resolveInterface rule.from;
      port = toString rule.port;
      dest = rule.to;
    in
    "      iifname \"${iface}\" ${protocol} dport ${port} dnat to ${dest}";

  # Generate all DNAT rules
  tcpRules = map (mkDnatRule "tcp") (topology.forwarding.tcp or [ ]);
  udpRules = map (mkDnatRule "udp") (topology.forwarding.udp or [ ]);
  allRules = lib.concatStringsSep "\n" (tcpRules ++ udpRules);
in
{
  # Generate complete nftables ruleset with DNAT and masquerade
  nftablesRuleset = ''
    table ip nat {
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
    ${allRules}
      };
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "${wanInterface}" ip saddr ${subnet} masquerade
      };
    }
  '';
}
