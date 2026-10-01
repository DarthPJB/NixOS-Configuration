# lib/topology/dashboard_templates/fleet-cpu-disk-light.nix
#
# Fleet Overview (display) — wall-display dashboard.
# Ported from services/graphana_dashboards/fleet-cpu-disk-light.json.
# Host membership (rename transforms) and the node job union are generated
# from the monitoring inventory at evaluation time.
{ dash }:
{
  uid = "fleet-cpu-disk-light";
  title = "Fleet Overview (display)";
  description = "Fleet overview for wall display — CPU, memory, disk, filesystem. Host membership generated from topology.";
  tags = [ "fleet" "display" "cpu" "memory" "disk" "filesystem" "zfs" "nix-provisioned" ];
  time = { from = "now-30m"; to = "now"; };
  panels = [
    (dash.row { title = "Fleet Status"; y = 0; })
    (dash.panel {
      type = "state-timeline";
      title = "System Status (all nodes)";
      x = 0;
      y = 1;
      w = 24;
      h = 5;
      fieldConfig = {
        color = { mode = "continuous-YlBl"; };
        custom = {
          axisPlacement = "auto";
          fillOpacity = 100;
          hideFrom = { legend = false; tooltip = false; viz = false; };
          insertNulls = false;
          lineWidth = 1;
          spanNulls = false;
        };
        fieldMinMax = false;
        mappings = [ ];
        min = 0;
        noValue = "0";
        thresholds = {
          mode = "absolute";
          steps = [{ color = "green"; value = 0; }];
        };
        unit = "bool_on_off";
      };
      options = {
        alignValue = "center";
        legend = { displayMode = "list"; placement = "right"; showLegend = false; };
        mergeValues = true;
        rowHeight = 0.9;
        showValue = "auto";
        tooltip = { hideZeros = false; mode = "single"; sort = "none"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_systemd_system_running{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}}"; }
      ];
    })
    (dash.row { title = "CPU"; y = 6; })
    (dash.panel {
      type = "timeseries";
      title = "CPU Usage % (all nodes)";
      x = 0;
      y = 7;
      w = 24;
      h = 8;
      fieldConfig = {
        unit = "percent";
        min = 0;
        max = 100;
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = true; };
      };
      options = {
        legend = { displayMode = "table"; placement = "right"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\",job=\"node\"}[5m])))"; legendFormat = "{{instance}}"; }
      ];
    })
    (dash.row { title = "Memory & Disk"; y = 15; })
    (dash.panel {
      type = "timeseries";
      title = "Memory Usage % (all nodes)";
      x = 0;
      y = 16;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "percent";
        min = 0;
        max = 100;
        custom = { fillOpacity = 15; lineWidth = 2; spanNulls = true; };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "lastNotNull" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "(1 - node_memory_MemAvailable_bytes{job=~\"__NODE_JOBS__\"} / node_memory_MemTotal_bytes{job=~\"__NODE_JOBS__\"}) * 100"; legendFormat = "{{instance}}"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Disk I/O Bandwidth (all nodes)";
      x = 12;
      y = 16;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "Bps";
        custom = { fillOpacity = 30; lineWidth = 2; spanNulls = false; };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "rate(node_disk_read_bytes_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m])"; legendFormat = "{{instance}} {{device}} read"; refId = "A"; }
        { expr = "-rate(node_disk_written_bytes_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m])"; legendFormat = "{{instance}} {{device}} write"; refId = "B"; }
      ];
    })
    (dash.row { title = "Filesystem"; y = 24; })
    (dash.panel {
      type = "bargauge";
      title = "Filesystem Usage (all nodes)";
      x = 0;
      y = 25;
      w = 24;
      h = 10;
      fieldConfig = {
        unit = "percent";
        min = 0;
        max = 100;
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "green"; value = null; }
            { color = "yellow"; value = 70; }
            { color = "red"; value = 85; }
          ];
        };
        decimals = 1;
      };
      options = {
        orientation = "vertical";
        displayMode = "gradient";
        showUnfilled = true;
        minVizWidth = 0;
        minVizHeight = 16;
        namePlacement = "auto";
        sizing = "auto";
        valueMode = "color";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "(1 - node_filesystem_avail_bytes{job=~\"__NODE_JOBS__\",fstype!~\"tmpfs|devtmpfs|overlay|ramfs\",mountpoint!~\"/nix/store|/speed-storage/.*\"} / node_filesystem_size_bytes{job=~\"__NODE_JOBS__\",fstype!~\"tmpfs|devtmpfs|overlay|ramfs\",mountpoint!~\"/nix/store|/speed-storage/.*\"}) * 100"; legendFormat = "{{instance}} {{mountpoint}}"; }
      ];
    })
    (dash.row { title = "ZFS"; y = 35; })
    (dash.panel {
      type = "gauge";
      title = "ZFS Pool Usage";
      x = 0;
      y = 36;
      w = 24;
      h = 8;
      fieldConfig = {
        unit = "percent";
        min = 0;
        max = 100;
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "green"; value = null; }
            { color = "yellow"; value = 70; }
            { color = "red"; value = 85; }
          ];
        };
      };
      options = {
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        showThresholdLabels = true;
        showThresholdMarkers = true;
      };
      transformations = dash.renames.zfsPort;
      targets = [
        { expr = "(1 - zfs_pool_free_bytes / zfs_pool_size_bytes) * 100"; legendFormat = "{{instance}} {{pool}}"; }
      ];
    })
  ];
}
