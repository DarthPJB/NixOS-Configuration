{ config, pkgs, lib, self, ... }:
{
  options.environment.vpn =
    {
      enable = lib.mkEnableOption "enable WireGaurd";
      postfix = lib.mkOption {
        type = lib.types.int;
        default = config.environment.interfaces.wg0.ipv4.postfix or 1;
        description = "WG postfix (auto from environment.interfaces if set)";
      };
      privateKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to WireGuard private key file (mutually exclusive with hostname)";
      };
      hostname = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.str;
        description = "hostname for prekeyed hosts (mutually exclusive with privateKeyFile)";
      };
    };
  config = lib.mkIf config.environment.vpn.enable
    {
      # Default to system hostname if not found
      environment.vpn.hostname = lib.mkIf (config.environment.vpn.privateKeyFile == null) (lib.mkDefault config.networking.hostName);
      secrix = lib.mkIf (config.environment.vpn.hostname != null)
        {
          services.wireguard-wireg0.secrets."${config.environment.vpn.hostname}".encrypted.file = "${self}/secrets/private_keys/wiregaurd/wg_${config.environment.vpn.hostname}";
        };
      services.openssh = lib.mkIf config.services.openssh.enable
        {
          listenAddresses = [{
            addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
            port = 1108;
          }];
        };
      networking.firewall.allowedTCPPorts = [ 2108 ];
      networking.firewall.allowedUDPPorts = [ 2108 ];
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
              # Conditional privateKeyFile
              privateKeyFile = lib.mkIf (config.environment.vpn.hostname != null)
                config.secrix.services.wireguard-wireg0.secrets."${config.environment.vpn.hostname}".decrypted.path
              // lib.mkIf (config.environment.vpn.privateKeyFile != null)
                config.environment.vpn.privateKeyFile;
              peers = [{
                publicKey = builtins.readFile "${self}/secrets/public_keys/wireguard/wg_cortex-alpha_pub";
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
