# systems/cortex-alpha.nix
# Transition file for new real-topology based router architecture.
# Eventually this may replace machines/cortex-alpha/default.nix
{ ... }:
{
  imports = [
    ../machines/cortex-alpha
    ../modules/core-router.nix
  ];
}
