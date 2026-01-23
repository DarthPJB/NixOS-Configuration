lib:
{
  mkNftables = config:
    let
      tcpRules = lib.concatStringsSep "\n" (map (rule:
        "              iifname \"enp2s0\" tcp dport ${toString rule.port} dnat to ${rule.dest}"
      ) config.enp2s0.tcp or []);
      udpRules = lib.concatStringsSep "\n" (map (rule:
        "              iifname \"enp2s0\" udp dport ${toString rule.port} dnat to ${rule.dest}"
      ) config.enp2s0.udp or []);
    in
      ''
        table ip nat {
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
        
            # Gitolite SSH and LINDACORE forwards
${tcpRules}
${udpRules}
          };
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname "enp2s0" ip saddr 10.88.128.0/24 masquerade
          };
      
          # Internal NAT for LAN/VPN
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
         #   iifname "enp3s0" tcp dport 22 dnat to 10.88.127.3:22
         #   iifname "wireg0" tcp dport 22 dnat to 10.88.127.3:22
          };
        }
      '';
}