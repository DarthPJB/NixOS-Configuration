{ config, pkgs, lib, ... }:

{
  options.networking.tailscale.advertisedRoutes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Routes to advertise via Tailscale.";
  };

  config = {
    # make the tailscale command usable to users
    environment.systemPackages = [ pkgs.tailscale ];

    #networking.firewall.checkReversePath = "loose";

    # enable the tailscale service
    services.tailscale = lib.mkMerge [
      { enable = true; }
      (lib.mkIf (config.networking.tailscale.advertisedRoutes != []) {
        useRoutingFeatures = "server";
        extraSetFlags = [ "--advertise-routes=${lib.concatStringsSep "," config.networking.tailscale.advertisedRoutes}" ];
      })
    ];
  };
}