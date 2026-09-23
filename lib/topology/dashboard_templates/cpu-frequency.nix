# lib/topology/dashboard_templates/cpu-frequency.nix
#
# CPU Frequency (per machine) — one heatmap panel per monitored host.
# This template is fully inventory-driven: the panel fan-out, grid layout and
# per-host PromQL are generated from lib/topology/inventory.nix. Adding or
# removing a machine updates this dashboard automatically.
{ dash }:
let
  inherit (dash) lib inventory;

  # Hosts shown in the workstation section (full-width, roomier panel).
  workstationHosts = [ "LINDA" ];
  x86 = builtins.filter (h: !(builtins.elem h.hostname workstationHosts)) inventory.node;
  workstations = builtins.filter (h: builtins.elem h.hostname workstationHosts) inventory.node;

  # Friendly panel titles for hosts whose metrics label differs from hostname.
  labelOverrides = { cluster-box = "cluster-box (Malayalam)"; };
  labelOf = h: labelOverrides.${h.hostname} or h.hostname;

  heatmap = { h, x, y, w, height }:
    dash.panel {
      type = "heatmap";
      title = "CPU Frequency — ${labelOf h}";
      inherit x y w;
      h = height;
      extra = { transparent = true; };
      fieldConfig = {
        custom = {
          hideFrom = { legend = false; tooltip = false; viz = false; };
          scaleDistribution = { type = "linear"; };
        };
      };
      options = {
        calculate = false;
        cellGap = 1;
        cellValues = { unit = "rothz"; };
        color = {
          exponent = 0.5;
          fill = "dark-red";
          mode = "scheme";
          reverse = false;
          scale = "exponential";
          scheme = "Spectral";
          steps = 64;
        };
        filterValues = { le = 1.0e-9; };
        legend = { show = false; };
        rowsFrame = { layout = "auto"; };
        tooltip = { mode = "single"; showColorScale = false; yHistogram = false; };
        yAxis = { axisPlacement = "hidden"; reverse = false; };
      };
      targets = [
        {
          expr = "node_cpu_scaling_frequency_hertz{instance=\"${h.ip}:${toString h.port}\", job=\"${h.job}\"}";
          legendFormat = "Core: {{cpu}}";
        }
      ];
    };

  # Two-column grid for x86 servers.
  x86Panels = lib.imap0
    (i: h: heatmap {
      inherit h;
      x = (lib.mod i 2) * 12;
      y = 1 + (lib.div i 2) * 8;
      w = 12;
      height = 8;
    })
    x86;

  x86Rows = lib.div (builtins.length x86 + 1) 2;
  workstationRowY = 1 + x86Rows * 8;

  workstationPanels = lib.imap0
    (i: h: heatmap {
      inherit h;
      x = 0;
      y = workstationRowY + 1 + i * 12;
      w = 24;
      height = 12;
    })
    workstations;
in
{
  uid = "cpu-frequency-per-machine";
  title = "CPU Frequency (per machine)";
  description = "Per-machine CPU core frequency heatmaps. Panel fan-out generated from the monitoring inventory.";
  tags = [ "fleet" "cpu" "frequency" "nix-provisioned" ];
  time = { from = "now-1h"; to = "now"; };
  panels = [
    (dash.row { title = "x86 Servers"; y = 0; })
  ] ++ x86Panels ++ [
    (dash.row { title = "Workstation"; y = workstationRowY; })
  ] ++ workstationPanels;
}
