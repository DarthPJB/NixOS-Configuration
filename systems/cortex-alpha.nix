# systems/cortex-alpha.nix
# Example of topology-driven machine configuration
# This file demonstrates how to use the core-router module
{ ... }:
{
  imports = [
    ../machines/cortex-alpha # Keep existing machine config
    ../modules/core-router.nix
  ];

  # Optional: Override topology settings
  # coreRouter.enable = true;  # Default

  # Machine-specific overrides that work alongside topology
  # (e.g., additional packages, users, etc.)
}
