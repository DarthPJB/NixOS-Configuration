{ lib }:

topology:

let
  # Generate iptables DNAT rules for port forwarding
  mkForwardRule = protocol: rule:
    let
      interface = rule.from;
      port = toString rule.port;
      dest = rule.to;
    in
    "-A nixos-fw -i ${interface} -p ${protocol} --dport ${port} -j DNAT --to-destination ${dest}";
in
{
  # Generate extraCommands string
  extraCommands = lib.concatStringsSep "\n" (
    lib.concatLists [
      (map (mkForwardRule "tcp") (topology.forwarding.tcp or []))
      (map (mkForwardRule "udp") (topology.forwarding.udp or []))
    ]
  );
}