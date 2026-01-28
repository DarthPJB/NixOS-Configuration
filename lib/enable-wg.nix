{ config, pkgs, lib, self, ... }:
{
  options.environment.vpn =
    {
      enable = lib.mkEnableOption "enable WireGaurd";
      postfix = lib.mkOption {
        type = lib.types.str;
        default = config.environment.interfaces.wg0.ipv4.postfix or 1;
        description = "WG postfix (auto from environment.interfaces if set)";
      };
      privateKeyFile = lib.mkOption { type = lib.types.str; };
    };
  config = lib.mkIf config.environment.vpn.enable
    {
      services.openssh = lib.mkIf config.services.openssh.enable
        {
          listenAddresses = [{
            addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
            port = 1108;
          }];
        };
      networking.wireguard = {
        enable = true;
        interfaces = {
          wireg0 =
            {
              # ensure routes exist to other clients.
              postSetup = ''
                ${pkgs.iproute2}/bin/ip route add 10.88.127.0/24 dev wireg0
              '';
              postShutdown = ''
                ${pkgs.iproute2}/bin/ip route del 10.88.127.0/24 dev wireg0
              '';
              ips = [ "10.88.127.${builtins.toString config.environment.vpn.postfix}/32" ];
              listenPort = 2108;
              privateKeyFile = config.environment.vpn.privateKeyFile;
              peers = [{
                publicKey = builtins.readFile "${self}/secrets/wiregaurd/wg_cortex-alpha_pub";
                allowedIPs = [ "10.88.127.1/32" "10.88.127.0/24" ];
                endpoint = "cortex-alpha.johnbargman.net:2108";
                dynamicEndpointRefreshSeconds = 300;
                persistentKeepalive = 60;
              }];
            };
        };
      };
    };
}
