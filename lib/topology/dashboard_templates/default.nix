# lib/topology/dashboard_templates/default.nix
#
# The template set. Each template is a function of the generator API (`dash`)
# and returns a dashboard template attrset; `mkDashboard` turns it into a full
# Grafana dashboard. Add a template here and it is provisioned automatically.
{ dash }:
{
  fleet-cpu-disk = dash.mkDashboard (import ./fleet-cpu-disk.nix { inherit dash; });
  fleet-cpu-disk-light = dash.mkDashboard (import ./fleet-cpu-disk-light.nix { inherit dash; });
  fleet-network = dash.mkDashboard (import ./fleet-network.nix { inherit dash; });
  cpu-frequency-per-machine = dash.mkDashboard (import ./cpu-frequency.nix { inherit dash; });
  service-health = dash.mkDashboard (import ./service-health.nix { inherit dash; });

  # Folded from the legacy static domain dashboards.
  storage-health = dash.mkDashboard (import ./storage-health.nix { inherit dash; });
  ai-systems = dash.mkDashboard (import ./ai-systems.nix { inherit dash; });
  ai-inference = dash.mkDashboard (import ./ai-inference.nix { inherit dash; });
  fleet-deployment = dash.mkDashboard (import ./fleet-deployment.nix { inherit dash; });
}
