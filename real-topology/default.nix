# real-topology/default.nix
# Central hub for network reality, golden generation, and filtering
{ lib, self ? null, ... }:
let
  # Specific option paths that are safe to evaluate (avoiding deprecated options)
  # These are the actual options we care about for network topology
  safeOptions = {
    "networking.hostName" = config: config.networking.hostName;
    "networking.nftables.enable" = config: config.networking.nftables.enable;
    "networking.wireguard.enable" = config: config.networking.wireguard.enable;
    "services.tailscale.enable" = config: config.services.tailscale.enable;
    "services.tailscale.useRoutingFeatures" = config: config.services.tailscale.useRoutingFeatures;
    "services.tailscale.extraSetFlags" = config: config.services.tailscale.extraSetFlags;
    "services.dnsmasq.enable" = config: config.services.dnsmasq.enable;
    "services.nginx.enable" = config: config.services.nginx.enable;
    "boot.kernel.sysctl" = config: config.boot.kernel.sysctl;
    "time.timeZone" = config: config.time.timeZone;
  };
in
{
  inherit safeOptions;

  # Generate filtered JSON for a machine's networking configuration
  generateGolden = machineName:
    let
      config = self.nixosConfigurations.${machineName}.config;
      # Safely evaluate each option, catching any errors
      safeEval = name: getter:
        let result = builtins.tryEval (getter config);
        in if result.success then { inherit name; value = result.value; }
        else null;
      # Get all safe options
      evaluated = lib.filterAttrs (n: v: v != null)
        (lib.listToAttrs (map
          (name:
            let result = safeEval name safeOptions.${name};
            in if result != null then { inherit (result) name; value = result.value; }
            else { inherit name; value = null; }
          )
          (builtins.attrNames safeOptions)));
    in
    evaluated // { machine = machineName; };
}
