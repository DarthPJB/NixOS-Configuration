# lib/topology/dashboard_templates/fleet-network.nix
#
# Fleet Network — interface bandwidth, status, errors, drops.
# Ported from services/graphana_dashboards/fleet-network.json.
# Host membership (rename transforms) is generated from the monitoring inventory.
{ dash }:
{
  uid = "fleet-network";
  title = "Fleet Network";
  description = "Fleet-wide interface bandwidth, link status, errors and drops. Host membership generated from topology.";
  tags = [ "fleet" "network" "bandwidth" "errors" "nix-provisioned" ];
  panels = [
    (dash.row { title = "Network Bandwidth"; y = 0; })
    (dash.panel {
      type = "timeseries";
      title = "Interface Bandwidth";
      x = 0;
      y = 1;
      w = 24;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 30; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "Bps";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*|br.*|wireg0|tailscale.*|tun.*\"}[5m])"; legendFormat = "{{instance}} {{device}} RX"; refId = "A"; }
        { expr = "-rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*|br.*|wireg0|tailscale.*|tun.*\"}[5m])"; legendFormat = "{{instance}} {{device}} TX"; refId = "B"; }
      ];
    })
    (dash.row { title = "Interfaces UP (expected-down hidden)"; y = 9; })
    (dash.panel {
      type = "stat";
      title = "Interface Status";
      x = 0;
      y = 10;
      w = 24;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          {
            options = {
              "0" = { color = "red"; text = "DOWN"; };
              "1" = { color = "green"; text = "UP"; };
            };
            type = "value";
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "red"; value = null; }
            { color = "green"; value = 1; }
          ];
        };
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "node_network_up{device!~\"lo|veth.*|docker.*|br.*|wireg0\"} == 1"; legendFormat = "{{instance}} {{device}}"; }
      ];
    })
    (dash.row { title = "Network Errors & Drops"; y = 16; })
    (dash.panel {
      type = "timeseries";
      title = "Network Errors";
      x = 0;
      y = 17;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "green"; value = null; }
            { color = "yellow"; value = 1; }
            { color = "red"; value = 10; }
          ];
        };
        unit = "pps";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_network_receive_errs_total{device!~\"lo|veth.*|docker.*|br.*\"}[5m])"; legendFormat = "{{instance}} {{device}} RX errors"; refId = "A"; }
        { expr = "rate(node_network_transmit_errs_total{device!~\"lo|veth.*|docker.*|br.*\"}[5m])"; legendFormat = "{{instance}} {{device}} TX errors"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Network Drops";
      x = 12;
      y = 17;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "green"; value = null; }
            { color = "yellow"; value = 1; }
            { color = "red"; value = 10; }
          ];
        };
        unit = "pps";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_network_receive_drop_total{device!~\"lo|veth.*|docker.*|br.*\"}[5m])"; legendFormat = "{{instance}} {{device}} RX drops"; refId = "A"; }
        { expr = "rate(node_network_transmit_drop_total{device!~\"lo|veth.*|docker.*|br.*\"}[5m])"; legendFormat = "{{instance}} {{device}} TX drops"; refId = "B"; }
      ];
    })
  ];
}
