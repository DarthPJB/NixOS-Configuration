# machines/x86-bootstrap/default.nix
# Generic x86_64 bootstrap image — reusable for ALL x86_64 devices
# Purpose: boot on x86_64 hardware, get on network, be discoverable, accept deployment
# This is NOT a machine config — it's a one-shot deployment vehicle.
#
# Consumes assimilator-probe module for SSH, networking, discovery, diagnostics.
# No encrypted assets — secrets are provisioned post-assimilation.
#
# Build: nix build .#nixosConfigurations.x86-bootstrap.config.system.build.images.iso
# Docs: documentation/x86-bootstrap-deployment-workflow.md
#
# NOTE: Module imports (assimilator-probe.nixosModules.default, user modules)
# are in flake.nix — not here. Flake inputs cannot be referenced in imports
# because _module.args are resolved after imports, causing infinite recursion.
{ pkgs
, config
, lib
, ...
}:
{
  # Assimilator-probe options — bootstrap defaults
  # No host key (generated on first boot), no WireGuard, no WiFi
  assimilator = {
    hostname = "x86-bootstrap";
  };
}
