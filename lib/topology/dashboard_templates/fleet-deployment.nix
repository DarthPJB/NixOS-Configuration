# lib/topology/dashboard_templates/fleet-deployment.nix
#
# Fleet Deployment Status — NixOS generation, version, uptime, kernel.
# Ported from services/graphana_dashboards/fleet-deployment.json.
# Host legibility via generated rename transforms (topology IPs -> hostnames).
{ dash }:
let
  # Table panels render instance/value columns; hide Value, narrow instance.
  tableDefaults = {
    color = { mode = "fixed"; fixedColor = "text"; };
    mappings = [ ];
    thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
  };
  tableOverrides = [
    { matcher = { id = "byName"; options = "instance"; }; properties = [{ id = "custom.width"; value = 150; }]; }
    { matcher = { id = "byName"; options = "Value"; }; properties = [{ id = "hidden"; value = true; }]; }
  ];
  tableOptions = { showHeader = true; cellHeight = "sm"; footer = { show = false; }; };
in
{
  uid = "fleet-deployment";
  title = "Fleet Deployment Status";
  description = "NixOS deployment status across the fleet — generation match, versions, uptime. Host legibility generated from topology.";
  tags = [ "fleet" "deployment" "nixos" "nix-provisioned" ];
  panels = [
    (dash.row { title = "Deployment Status"; y = 0; })
    (dash.panel {
      type = "stat";
      title = "Generation Match (Booted = Current?)";
      x = 0;
      y = 1;
      w = 24;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          {
            options = {
              "0" = { color = "red"; text = "MISMATCH"; };
              "1" = { color = "green"; text = "CURRENT"; };
            };
            type = "value";
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [{ color = "red"; value = null; } { color = "green"; value = 1; }];
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
      targets = [{ expr = "nixos_generation_match"; legendFormat = "{{instance}}"; }];
    })
    (dash.row { title = "Version Information"; y = 7; })
    (dash.panel {
      type = "table";
      title = "NixOS Version";
      x = 0;
      y = 8;
      w = 12;
      h = 8;
      fieldConfig = tableDefaults;
      overrides = tableOverrides;
      options = tableOptions;
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_version_info"; legendFormat = ""; format = "table"; }];
    })
    (dash.panel {
      type = "table";
      title = "Flake Info";
      x = 12;
      y = 8;
      w = 12;
      h = 8;
      fieldConfig = tableDefaults;
      overrides = tableOverrides;
      options = tableOptions;
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_flake_info"; legendFormat = ""; format = "table"; }];
    })
    (dash.panel {
      type = "table";
      title = "Configuration Derivation / System Path";
      x = 0;
      y = 16;
      w = 24;
      h = 6;
      fieldConfig = tableDefaults;
      overrides = tableOverrides;
      options = tableOptions;
      transformations = dash.renames.nodePort;
      targets = [
        { expr = "nixos_flake_info"; format = "table"; refId = "A"; }
        { expr = "nixos_system_info"; format = "table"; refId = "B"; }
      ];
    })
    (dash.row { title = "Generation & Uptime"; y = 22; })
    (dash.panel {
      type = "timeseries";
      title = "Current Generation Number";
      x = 0;
      y = 23;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "none";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_generation_number{type=\"current\"}"; legendFormat = "{{instance}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "System Uptime";
      x = 12;
      y = 23;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 20; lineWidth = 2; spanNulls = false; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "s";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_uptime_seconds"; legendFormat = "{{instance}}"; }];
    })
    (dash.panel {
      type = "stat";
      title = "Last Activation";
      x = 0;
      y = 31;
      w = 24;
      h = 8;
      fieldConfig = {
        unit = "dateTimeAsIso";
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        mappings = [ ];
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "value_and_name";
      };
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_activation_timestamp_seconds"; legendFormat = "{{instance}}"; }];
    })
    (dash.row { title = "Kernel"; y = 39; })
    (dash.panel {
      type = "table";
      title = "Kernel Version";
      x = 0;
      y = 40;
      w = 24;
      h = 6;
      fieldConfig = tableDefaults;
      overrides = [
        { matcher = { id = "byName"; options = "Value"; }; properties = [{ id = "hidden"; value = true; }]; }
      ];
      options = tableOptions;
      transformations = dash.renames.nodePort;
      targets = [{ expr = "nixos_kernel_version_info"; legendFormat = ""; format = "table"; }];
    })
  ];
}
