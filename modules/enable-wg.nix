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
        default = config.networking.hostName;
        type = lib.types.nullOr lib.types.str;
        description = "hostname for prekeyed hosts (mutually exclusive with privateKeyFile)";
      };
      port = lib.mkOption { type = lib.types.int; default = 2108; };
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
      networking.firewall.allowedTCPPorts = [ config.environment.vpn.port ];
      networking.firewall.allowedUDPPorts = [ config.environment.vpn.port ];
      secrix.services.wireguard-wireg0.secrets."${config.environment.vpn.hostname}".encrypted.file = lib.mkIf (config.environment.vpn.privateKeyFile == null) "${self}/secrets/private_keys/wireguard/wg_${config.environment.vpn.hostname}";
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
              listenPort = config.environment.vpn.port;
              # Conditional privateKeyFile
              privateKeyFile = lib.mkMerge [
                (lib.mkIf (config.environment.vpn.privateKeyFile == null)
                  config.secrix.services.wireguard-wireg0.secrets."${config.environment.vpn.hostname}".decrypted.path)
                (lib.mkIf (config.environment.vpn.privateKeyFile != null)
                  config.environment.vpn.privateKeyFile)
              ];
              peers = [{
                publicKey = builtins.readFile "${self}/secrets/public_keys/wireguard/wg_cortex-alpha_pub";
                allowedIPs = [ "10.88.127.1/32" "10.88.127.0/24" ];
                endpoint = "cortex-alpha.johnbargman.net:${builtins.toString self.nixosConfigurations.cortex-alpha.config.networking.wireguard.interfaces.wireg0.listenPort}";
                dynamicEndpointRefreshSeconds = 300;
                persistentKeepalive = 60;
              }];
            };
        };
      };
    };
}
