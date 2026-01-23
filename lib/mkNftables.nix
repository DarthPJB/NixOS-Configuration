lib:
{
  mkNftables = config:
    let
      tcpPorts = config.enp2s0.tcp or [];
      udpPorts = config.enp2s0.udp or [];
      tcpRules = lib.concatStringsSep "\n" (map (port:
        if port == 2208 then
          "              iifname \"enp2s0\" tcp dport 2208 dnat to 10.88.127.3:22"
        else
          "              iifname \"enp2s0\" tcp dport ${toString port} dnat to 10.88.128.88:${toString port}"
      ) tcpPorts);
      udpRules = lib.concatStringsSep "\n" (map (port:
        "              iifname \"enp2s0\" udp dport ${toString port} dnat to 10.88.128.88:${toString port}"
      ) udpPorts);
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