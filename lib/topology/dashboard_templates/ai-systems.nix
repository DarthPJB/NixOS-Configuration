# lib/topology/dashboard_templates/ai-systems.nix
#
# AI Systems — GPU hardware across all GPU machines.
# Ported from services/graphana_dashboards/ai-systems.json, re-scoped
# generatively: the hardcoded instance IP regexes are replaced by the GPU job
# union + generated rename transforms, so GPU hosts come and go automatically.
# CPU/memory/disk panels are omitted — they are covered by fleet-cpu-disk and
# storage-health.
{ dash }:
let
  inherit (dash) lib inventory;
  # PromQL union of every job that exposes nvidia_smi_* metrics.
  nvidiaJobs = lib.concatStringsSep "|" (lib.unique (map (e: e.job) inventory.nvidia));
in
{
  uid = "ai-systems";
  title = "AI Systems";
  description = "GPU hardware across all GPU machines — utilization, VRAM, temperature, power, clocks. GPU host membership generated from the monitoring inventory.";
  tags = [ "ai" "gpu" "nvidia" "hardware" "nix-provisioned" ];
  panels = [
    (dash.row { title = "Machine Status"; y = 0; })
    (dash.panel {
      type = "stat";
      title = "NVIDIA Exporter Status";
      x = 0;
      y = 1;
      w = 12;
      h = 4;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [{ options = { "0" = { color = "red"; text = "DOWN"; }; "1" = { color = "green"; text = "UP"; }; }; type = "value"; }];
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
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "up{job=~\"${nvidiaJobs}\"}"; legendFormat = "{{instance}} GPU"; }];
    })
    (dash.panel {
      type = "stat";
      title = "GPU Hardware Info";
      x = 12;
      y = 1;
      w = 12;
      h = 4;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "nvidia_smi_gpu_info"; legendFormat = "{{instance}} — {{name}} ({{driver_version}})"; }];
    })
    (dash.row { title = "GPU — Utilization & Memory"; y = 5; })
    (dash.panel {
      type = "timeseries";
      title = "GPU Utilization %";
      x = 0;
      y = 6;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        max = 100;
        min = 0;
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }]; };
        unit = "percent";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [
        { expr = "nvidia_smi_utilization_gpu_ratio * 100"; legendFormat = "{{instance}} GPU Compute"; refId = "A"; }
        { expr = "nvidia_smi_utilization_memory_ratio * 100"; legendFormat = "{{instance}} GPU Memory Controller"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "GPU VRAM (Used / Free)";
      x = 12;
      y = 6;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 30; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "bytes";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "lastNotNull" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
        stacking = { group = "A"; mode = "normal"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [
        { expr = "nvidia_smi_memory_used_bytes"; legendFormat = "{{instance}} used"; refId = "A"; }
        { expr = "nvidia_smi_memory_free_bytes"; legendFormat = "{{instance}} free"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "gauge";
      title = "GPU VRAM Used %";
      x = 0;
      y = 14;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        max = 100;
        min = 0;
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }]; };
        unit = "percent";
      };
      options = {
        orientation = "auto";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        showThresholdLabels = true;
        showThresholdMarkers = true;
      };
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "100 * nvidia_smi_memory_used_bytes / nvidia_smi_memory_total_bytes"; legendFormat = "{{instance}}"; }];
    })
    (dash.panel {
      type = "stat";
      title = "GPU VRAM Total";
      x = 12;
      y = 14;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "bytes";
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "nvidia_smi_memory_total_bytes"; legendFormat = "{{instance}} total VRAM"; }];
    })
    (dash.row { title = "GPU — Temperature & Power"; y = 22; })
    (dash.panel {
      type = "timeseries";
      title = "GPU Temperature";
      x = 0;
      y = 23;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 15; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; } { color = "yellow"; value = 75; } { color = "red"; value = 90; }]; };
        unit = "celsius";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "nvidia_smi_temperature_gpu"; legendFormat = "{{instance}} GPU Temp"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "GPU Power Draw vs Limit";
      x = 12;
      y = 23;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "watt";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [
        { expr = "nvidia_smi_power_draw_watts"; legendFormat = "{{instance}} draw"; refId = "A"; }
        { expr = "nvidia_smi_power_limit_watts"; legendFormat = "{{instance}} limit"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "GPU Fan Speed %";
      x = 0;
      y = 31;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 10; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "percent";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [{ expr = "nvidia_smi_fan_speed_ratio * 100"; legendFormat = "{{instance}} Fan Speed"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "GPU Clock Speeds";
      x = 12;
      y = 31;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 10; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "hertz";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "lastNotNull" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nvidiaPort;
      targets = [
        { expr = "nvidia_smi_clocks_current_graphics_clock_hz"; legendFormat = "{{instance}} Graphics Clock"; refId = "A"; }
        { expr = "nvidia_smi_clocks_current_memory_clock_hz"; legendFormat = "{{instance}} Memory Clock"; refId = "B"; }
      ];
    })
  ];
}
