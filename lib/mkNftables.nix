{ lib, nftableAttrs ? { } }:
let
  interfaces = lib.attrNames nftableAttrs;
  generateRules = iface: protocol: rules: lib.concatStringsSep "\n"
    (lib.map (rule: "              iifname \"${iface}\" ${protocol} dport ${builtins.toString rule.port} dnat to ${rule.dest}") rules);
  tcpRules = lib.concatStringsSep "\n" (lib.map (iface: generateRules iface "tcp" (nftableAttrs.${iface}.tcp or [ ])) interfaces);
  udpRules = lib.concatStringsSep "\n" (lib.map (iface: generateRules iface "udp" (nftableAttrs.${iface}.udp or [ ])) interfaces);
in
''
  table ip nat {
    chain prerouting {
      type nat hook prerouting priority dstnat; policy accept;
      ${tcpRules}
      ${udpRules}
    };
    chain postrouting {
      type nat hook postrouting priority srcnat; policy accept;
      oifname "enp2s0" ip saddr 10.88.128.0/24 masquerade
    };
  }
''
