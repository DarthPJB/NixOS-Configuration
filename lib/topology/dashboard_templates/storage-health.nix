# lib/topology/dashboard_templates/storage-health.nix
#
# Storage Health — consolidated from zfs-health.json + storage-io.json +
# disk-health.json. SMART, temperature, sectors, lifetime, disk I/O, queue,
# filesystem, and ZFS pool health. Overlapping ZFS panels deduplicated.
# Host legibility via generated rename transforms (topology IPs -> hostnames).
{ dash }:
let
  ts = { fillOpacity ? 20, lineWidth ? 2, spanNulls ? false, extra ? { } }: {
    color = { mode = "palette-classic"; };
    custom = { inherit fillOpacity lineWidth spanNulls; } // extra;
    mappings = [ ];
    thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
  };
  legend = { calcs ? [ "mean" ], placement ? "bottom" }: {
    legend = { displayMode = "table"; inherit placement; showLegend = true; inherit calcs; };
    tooltip = { mode = "multi"; sort = "desc"; };
  };
  gauge = { steps }: {
    color = { mode = "thresholds"; };
    mappings = [ ];
    thresholds = { mode = "absolute"; inherit steps; };
    unit = "percent";
    max = 100;
    min = 0;
  };
  gaugeOpts = { labels ? false }: {
    orientation = "auto";
    reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
    showThresholdLabels = labels;
    showThresholdMarkers = true;
  };
  steps3 = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 85; }];
in
{
  uid = "storage-health";
  title = "Storage Health";
  description = "Consolidated storage view — SMART disk health, I/O, latency, queue, filesystem, and ZFS pools. Host legibility generated from topology.";
  tags = [ "storage" "disk" "smart" "zfs" "io" "nix-provisioned" ];
  panels = [
    (dash.row { title = "Disk Health (SMART)"; y = 0; })
    (dash.panel {
      type = "stat";
      title = "SMART Health Status";
      x = 0;
      y = 1;
      w = 24;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          { options = { "0" = { color = "red"; text = "FAILED"; }; "1" = { color = "green"; text = "PASSED"; }; }; type = "value"; }
        ];
        thresholds = { mode = "absolute"; steps = [{ color = "red"; value = null; } { color = "green"; value = 1; }]; };
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
      targets = [{ expr = "smartctl_device_smart_status"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.row { title = "Temperature"; y = 7; })
    (dash.panel {
      type = "timeseries";
      title = "Disk Temperature";
      x = 0;
      y = 8;
      w = 24;
      h = 8;
      fieldConfig = {
        color = { mode = "continuous-BlYlRd"; };
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        max = 60;
        min = 20;
        thresholds = {
          mode = "absolute";
          steps = [{ color = "blue"; value = null; } { color = "green"; value = 30; } { color = "yellow"; value = 45; } { color = "red"; value = 55; }];
        };
        unit = "celsius";
      };
      options = {
        legend = { displayMode = "table"; placement = "right"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_temperature"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.row { title = "Sector Health"; y = 16; })
    (dash.panel {
      type = "timeseries";
      title = "Reallocated Sectors";
      x = 0;
      y = 17;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "red"; value = 1; }]; }; unit = "none"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_attribute{attribute_name=\"Reallocated_Sector_Ct\", attribute_value_type=\"raw\"}"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Pending Sectors";
      x = 8;
      y = 17;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 1; } { color = "red"; value = 10; }]; }; unit = "none"; noValue = "0"; decimals = 0; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_attribute{attribute_name=~\"Current_Pending_Sector(_Ct)?\", attribute_value_type=\"raw\"}"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Offline Uncorrectable Sectors";
      x = 16;
      y = 17;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "red"; value = 1; }]; }; unit = "none"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_attribute{attribute_name=\"Offline_Uncorrectable\", attribute_value_type=\"raw\"}"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.row { title = "Disk Lifetime"; y = 25; })
    (dash.panel {
      type = "timeseries";
      title = "Power-On Hours";
      x = 0;
      y = 26;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { unit = "h"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_power_on_seconds / 3600"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Load Cycle Count";
      x = 8;
      y = 26;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { unit = "none"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_attribute{attribute_name=\"Load_Cycle_Count\", attribute_value_type=\"raw\"}"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Start/Stop Count";
      x = 16;
      y = 26;
      w = 8;
      h = 8;
      fieldConfig = (ts { }) // { unit = "none"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "smartctl_device_attribute{attribute_name=\"Start_Stop_Count\", attribute_value_type=\"raw\"}"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.row { title = "Disk I/O"; y = 34; })
    (dash.panel {
      type = "timeseries";
      title = "Disk Read/Write Bandwidth";
      x = 0;
      y = 35;
      w = 12;
      h = 8;
      fieldConfig = (ts { fillOpacity = 30; }) // { unit = "Bps"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_disk_read_bytes_total[5m])"; legendFormat = "{{instance}} {{device}} read"; refId = "A"; }
        { expr = "-rate(node_disk_written_bytes_total[5m])"; legendFormat = "{{instance}} {{device}} write"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Disk IOPS";
      x = 12;
      y = 35;
      w = 12;
      h = 8;
      fieldConfig = (ts { fillOpacity = 30; }) // { unit = "iops"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_disk_reads_completed_total[5m])"; legendFormat = "{{instance}} {{device}} read"; refId = "A"; }
        { expr = "-rate(node_disk_writes_completed_total[5m])"; legendFormat = "{{instance}} {{device}} write"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Read Latency";
      x = 0;
      y = 43;
      w = 12;
      h = 8;
      fieldConfig = (ts { }) // {
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 10; } { color = "red"; value = 50; }]; };
        unit = "ms";
      };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "rate(node_disk_read_time_seconds_total[5m]) / rate(node_disk_reads_completed_total[5m]) * 1000"; legendFormat = "{{instance}} {{device}} read"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Write Latency";
      x = 12;
      y = 43;
      w = 12;
      h = 8;
      fieldConfig = (ts { }) // {
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 10; } { color = "red"; value = 50; }]; };
        unit = "ms";
      };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "rate(node_disk_write_time_seconds_total[5m]) / rate(node_disk_writes_completed_total[5m]) * 1000"; legendFormat = "{{instance}} {{device}} write"; }];
    })
    (dash.row { title = "Disk Queue"; y = 51; })
    (dash.panel {
      type = "timeseries";
      title = "Weighted I/O Time";
      x = 0;
      y = 52;
      w = 12;
      h = 8;
      fieldConfig = (ts { }) // {
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 10; } { color = "red"; value = 50; }]; };
        unit = "none";
      };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "node_disk_io_time_weighted_seconds_total"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.panel {
      type = "gauge";
      title = "Disk Utilization";
      x = 12;
      y = 52;
      w = 12;
      h = 8;
      fieldConfig = gauge { steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }]; };
      options = gaugeOpts { };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "rate(node_disk_io_time_seconds_total[5m]) * 100"; legendFormat = "{{instance}} {{device}}"; }];
    })
    (dash.row { title = "Filesystem"; y = 60; })
    (dash.panel {
      type = "bargauge";
      title = "Filesystem Usage";
      x = 0;
      y = 61;
      w = 24;
      h = 8;
      fieldConfig = (gauge { steps = steps3; }) // { decimals = 1; };
      options = {
        orientation = "horizontal";
        displayMode = "gradient";
        showUnfilled = true;
        minVizWidth = 0;
        minVizHeight = 16;
        namePlacement = "auto";
        sizing = "auto";
        valueMode = "color";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
      };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "(1 - node_filesystem_avail_bytes{fstype!~\"tmpfs|devtmpfs|overlay|ramfs\", mountpoint!~\"/nix/store|/speed-storage/.*\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|devtmpfs|overlay|ramfs\", mountpoint!~\"/nix/store|/speed-storage/.*\"}) * 100"; legendFormat = "{{instance}} {{mountpoint}}"; }];
    })
    (dash.row { title = "ZFS Pool"; y = 69; })
    (dash.panel {
      type = "gauge";
      title = "Pool Capacity Used";
      x = 0;
      y = 70;
      w = 12;
      h = 8;
      fieldConfig = gauge { steps = steps3; };
      options = gaugeOpts { };
      transformations = dash.renames.zfsPort;
      targets = [{ expr = "(1 - zfs_pool_free_bytes / zfs_pool_size_bytes) * 100"; legendFormat = "{{instance}} {{pool}}"; }];
    })
    (dash.panel {
      type = "gauge";
      title = "Pool Fragmentation";
      x = 12;
      y = 70;
      w = 12;
      h = 8;
      fieldConfig = gauge { steps = [{ color = "green"; value = null; } { color = "yellow"; value = 10; } { color = "red"; value = 20; }]; };
      options = gaugeOpts { };
      transformations = dash.renames.zfsPort;
      targets = [{ expr = "zfs_pool_fragmentation_ratio * 100"; legendFormat = "{{instance}} {{pool}}"; }];
    })
    (dash.panel {
      type = "stat";
      title = "Pool State (Online)";
      x = 0;
      y = 78;
      w = 12;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          {
            options = {
              "0" = { color = "green"; text = "ONLINE"; };
              "1" = { color = "yellow"; text = "DEGRADED"; };
              "2" = { color = "red"; text = "FAULTED"; };
            };
            type = "value";
          }
        ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 1; } { color = "red"; value = 2; }]; };
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      transformations = dash.renames.zfsPort;
      targets = [{ expr = "node_zfs_zpool_state{state=\"online\"}"; legendFormat = "{{instance}} {{zpool}}"; }];
    })
    (dash.panel {
      type = "gauge";
      title = "Deduplication Ratio (1.0 = none)";
      x = 12;
      y = 78;
      w = 12;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        min = 0;
        thresholds = {
          mode = "absolute";
          steps = [{ color = "blue"; value = null; } { color = "green"; value = 1.0; } { color = "yellow"; value = 1.5; } { color = "orange"; value = 2.0; }];
        };
        unit = "none";
        decimals = 3;
      };
      options = gaugeOpts { };
      transformations = dash.renames.zfsPort;
      targets = [{ expr = "zfs_pool_deduplication_ratio"; legendFormat = "{{instance}} {{pool}}"; }];
    })
    (dash.row { title = "ZFS I/O"; y = 84; })
    (dash.panel {
      type = "timeseries";
      title = "Dataset Read/Write Ops";
      x = 0;
      y = 85;
      w = 12;
      h = 8;
      fieldConfig = (ts { fillOpacity = 30; }) // { unit = "ops"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_zfs_zpool_dataset_reads[5m])"; legendFormat = "{{instance}} {{dataset}} reads"; refId = "A"; }
        { expr = "-rate(node_zfs_zpool_dataset_writes[5m])"; legendFormat = "{{instance}} {{dataset}} writes"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Dataset Read/Write Bandwidth";
      x = 12;
      y = 85;
      w = 12;
      h = 8;
      fieldConfig = (ts { fillOpacity = 30; }) // { unit = "Bps"; };
      options = legend { };
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "rate(node_zfs_zpool_dataset_nread[5m])"; legendFormat = "{{instance}} {{dataset}} read"; refId = "A"; }
        { expr = "-rate(node_zfs_zpool_dataset_nwritten[5m])"; legendFormat = "{{instance}} {{dataset}} write"; refId = "B"; }
      ];
    })
    (dash.row { title = "ZFS Size"; y = 93; })
    (dash.panel {
      type = "timeseries";
      title = "Pool Size Breakdown";
      x = 0;
      y = 94;
      w = 24;
      h = 8;
      fieldConfig = (ts { }) // { unit = "bytes"; };
      options = legend { };
      transformations = dash.renames.zfsPort;
      targets = [
        { expr = "zfs_pool_size_bytes"; legendFormat = "{{instance}} {{pool}} total"; refId = "A"; }
        { expr = "zfs_pool_allocated_bytes"; legendFormat = "{{instance}} {{pool}} allocated"; refId = "B"; }
        { expr = "zfs_pool_free_bytes"; legendFormat = "{{instance}} {{pool}} free"; refId = "C"; }
      ];
    })
  ];
}
