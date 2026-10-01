# lib/topology/dashboard_templates/fleet-cpu-disk.nix
#
# Fleet Admin (heavy) — full fleet CPU/memory/disk/network/energy dashboard.
# Ported from services/graphana_dashboards/fleet-cpu-disk.json.
# Host membership (rename transforms) and the node job union are generated
# from the monitoring inventory at evaluation time.
{ dash }:
{
  uid = "fleet-cpu-disk";
  title = "Fleet Admin (heavy)";
  description = "Full fleet admin view — CPU, memory, disk, network, energy, storage, services. Host membership generated from topology.";
  tags = [ "fleet" "admin" "cpu" "memory" "disk" "network" "zfs" "nix-provisioned" ];
  time = { from = "now-3h"; to = "now"; };
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
    (dash.panel {
      type = "heatmap";
      title = "CPU Frequency (all cores, all nodes)";
      x = 0;
      y = 15;
      w = 24;
      h = 8;
      fieldConfig = {
        unit = "rothz";
        custom = {
          hideFrom = { legend = false; tooltip = false; viz = false; };
          scaleDistribution = { type = "linear"; };
        };
      };
      options = {
        calculate = false;
        cellGap = 3;
        cellValues = { unit = "rothz"; };
        color = {
          exponent = 0.5;
          fill = "dark-orange";
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
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_cpu_scaling_frequency_hertz{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} cpu{{cpu}}"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Load Average (all nodes)";
      x = 0;
      y = 23;
      w = 24;
      h = 8;
      fieldConfig = {
        unit = "short";
        custom = { fillOpacity = 10; };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_load1{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} load1"; refId = "A"; }
        { expr = "node_load5{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} load5"; refId = "B"; }
        { expr = "node_load15{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} load15"; refId = "C"; }
      ];
    })
    (dash.row { title = "Memory & Disk"; y = 31; })
    (dash.panel {
      type = "timeseries";
      title = "Memory Usage % (all nodes)";
      x = 0;
      y = 32;
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
      title = "Disk I/O Bandwidth (all nodes + ZFS)";
      x = 12;
      y = 32;
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
        { expr = "rate(node_zfs_zpool_dataset_nread{job=~\"__NODE_JOBS__\"}[5m])"; legendFormat = "{{instance}} {{dataset}} zfs-read"; refId = "C"; }
        { expr = "-rate(node_zfs_zpool_dataset_nwritten{job=~\"__NODE_JOBS__\"}[5m])"; legendFormat = "{{instance}} {{dataset}} zfs-write"; refId = "D"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Network Throughput (ethtool, all nodes)";
      x = 0;
      y = 40;
      w = 24;
      h = 7;
      fieldConfig = {
        unit = "Bps";
        custom = {
          axisBorderShow = true;
          axisCenteredZero = true;
          axisColorMode = "series";
          axisGridShow = true;
          drawStyle = "line";
          fillOpacity = 73;
          lineInterpolation = "stepBefore";
          lineWidth = 1;
          showPoints = "never";
          spanNulls = false;
          stacking = { group = "A"; mode = "normal"; };
        };
      };
      options = {
        legend = { calcs = [ ]; displayMode = "table"; placement = "right"; showLegend = false; };
        tooltip = { hideZeros = false; mode = "single"; sort = "none"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "rate(node_ethtool_received_bytes_total{job=~\"__NODE_JOBS__\"}[5m])"; legendFormat = "{{instance}} RX"; refId = "A"; }
        { expr = "0 - rate(node_ethtool_transmitted_bytes_total{job=~\"__NODE_JOBS__\"}[5m])"; legendFormat = "{{instance}} TX"; refId = "B"; }
      ];
    })
    (dash.row { title = "Energy"; y = 47; })
    (dash.panel {
      type = "timeseries";
      title = "Energy Usage (hwmon + nvidia)";
      x = 0;
      y = 48;
      w = 12;
      h = 7;
      fieldConfig = {
        unit = "watt";
        custom = {
          fillOpacity = 73;
          lineInterpolation = "stepBefore";
          lineWidth = 1;
          showPoints = "never";
          spanNulls = false;
        };
      };
      overrides = [
        {
          matcher = {
            id = "byValue";
            options = { op = "gte"; reducer = "allIsZero"; value = 0; };
          };
          properties = [
            {
              id = "custom.hideFrom";
              value = { legend = true; tooltip = true; viz = true; };
            }
          ];
        }
      ];
      options = {
        legend = { calcs = [ ]; displayMode = "list"; placement = "bottom"; showLegend = true; };
        tooltip = { hideZeros = false; mode = "multi"; sort = "none"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_hwmon_power_watt{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} hwmon"; refId = "A"; }
        { expr = "node_power_supply_energy_watthour{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} supply"; refId = "B"; }
        { expr = "nvidia_smi_power_draw_watts{job=\"nvidia\"}"; legendFormat = "{{instance}} GPU"; refId = "C"; }
      ];
    })
    (dash.panel {
      type = "barchart";
      title = "GPU Utilization (nvidia)";
      x = 12;
      y = 48;
      w = 12;
      h = 7;
      fieldConfig = {
        unit = "percent";
        min = 0;
        max = 100;
        custom = { fillOpacity = 80; gradientMode = "opacity"; };
      };
      options = {
        legend = { calcs = [ ]; displayMode = "list"; placement = "bottom"; showLegend = true; };
        tooltip = { hideZeros = false; mode = "single"; sort = "none"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [
        { expr = "nvidia_smi_utilization_gpu_ratio{job=\"nvidia\"} * 100"; legendFormat = "{{instance}} GPU"; refId = "A"; }
        { expr = "nvidia_smi_utilization_memory_ratio{job=\"nvidia\"} * 100"; legendFormat = "{{instance}} VRAM"; refId = "B"; }
      ];
    })
    (dash.row { title = "Storage"; y = 55; })
    (dash.panel {
      type = "bargauge";
      title = "Filesystem Usage (all nodes)";
      x = 0;
      y = 56;
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
    (dash.panel {
      type = "gauge";
      title = "ZFS Pool Usage";
      x = 0;
      y = 66;
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
    (dash.row { title = "Services"; y = 74; })
    (dash.panel {
      type = "stat";
      title = "Failed Services (all nodes)";
      x = 0;
      y = 75;
      w = 24;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          {
            options = {
              "0" = { color = "green"; text = "OK"; };
              "1" = { color = "red"; text = "FAILED"; };
            };
            type = "value";
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "green"; value = null; }
            { color = "red"; value = 1; }
          ];
        };
        noValue = "none";
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "(node_systemd_unit_state{state=\"failed\", job=\"node\"}) > 0"; legendFormat = "{{instance}} {{name}}"; }
      ];
    })
    # ── Node Detail ──────────────────────────────────────────
    # Folded from remote-builder.json (unique panels not covered above),
    # re-scoped to all nodes. Memory breakdown, swap, IOPS, latency, PSI,
    # process counts.
    (dash.row { title = "Node Detail"; y = 83; })
    (dash.panel {
      type = "timeseries";
      title = "Memory Breakdown (all nodes)";
      x = 0;
      y = 84;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "bytes";
        custom = {
          fillOpacity = 30;
          lineWidth = 2;
          spanNulls = false;
          stacking = { group = "A"; mode = "normal"; };
        };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "lastNotNull" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_memory_MemTotal_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Total"; refId = "A"; }
        { expr = "node_memory_Active_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Active"; refId = "B"; }
        { expr = "node_memory_Cached_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Cached"; refId = "C"; }
        { expr = "node_memory_Buffers_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Buffers"; refId = "D"; }
        { expr = "node_memory_MemFree_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Free"; refId = "E"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Swap Usage (all nodes)";
      x = 12;
      y = 84;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "bytes";
        custom = {
          fillOpacity = 30;
          lineWidth = 2;
          spanNulls = false;
          stacking = { group = "A"; mode = "normal"; };
        };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "lastNotNull" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_memory_SwapTotal_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Total"; refId = "A"; }
        { expr = "node_memory_SwapTotal_bytes{job=~\"__NODE_JOBS__\"} - node_memory_SwapFree_bytes{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Used"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Disk IOPS (all nodes)";
      x = 0;
      y = 92;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "iops";
        custom = { fillOpacity = 30; lineWidth = 2; spanNulls = false; };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "rate(node_disk_reads_completed_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m])"; legendFormat = "{{instance}} {{device}} read"; refId = "A"; }
        { expr = "-rate(node_disk_writes_completed_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m])"; legendFormat = "{{instance}} {{device}} write"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Disk Latency (all nodes)";
      x = 12;
      y = 92;
      w = 12;
      h = 8;
      fieldConfig = {
        unit = "ms";
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "rate(node_disk_read_time_seconds_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m]) / rate(node_disk_reads_completed_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m]) * 1000"; legendFormat = "{{instance}} {{device}} read"; refId = "A"; }
        { expr = "rate(node_disk_write_time_seconds_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m]) / rate(node_disk_writes_completed_total{job=~\"__NODE_JOBS__\",device!~\"^(loop|ram|sr).*\"}[5m]) * 1000"; legendFormat = "{{instance}} {{device}} write"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Pressure Stall Information (all nodes)";
      x = 0;
      y = 100;
      w = 12;
      h = 6;
      fieldConfig = {
        unit = "s";
        custom = { fillOpacity = 10; lineWidth = 2; };
      };
      options = {
        legend = { displayMode = "list"; placement = "bottom"; showLegend = false; };
        tooltip = { mode = "single"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_pressure_cpu_waiting_seconds_total{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} CPU pressure"; refId = "A"; }
        { expr = "node_pressure_io_waiting_seconds_total{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} IO pressure"; refId = "B"; }
        { expr = "node_pressure_memory_waiting_seconds_total{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Memory pressure"; refId = "C"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Processes (running / blocked, all nodes)";
      x = 12;
      y = 100;
      w = 12;
      h = 6;
      fieldConfig = {
        unit = "short";
        custom = { fillOpacity = 10; };
      };
      options = {
        legend = { displayMode = "list"; placement = "bottom"; showLegend = false; };
        tooltip = { mode = "single"; };
      };
      transformations = dash.renames.nodeBare;
      targets = [
        { expr = "node_procs_running{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Running"; refId = "A"; }
        { expr = "node_procs_blocked{job=~\"__NODE_JOBS__\"}"; legendFormat = "{{instance}} Blocked"; refId = "B"; }
      ];
    })
  ];
}
