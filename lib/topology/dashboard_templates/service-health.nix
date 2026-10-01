# lib/topology/dashboard_templates/service-health.nix
#
# Service Health — systemd unit failures across the fleet.
# Ported from services/graphana_dashboards/service-health.json.
{ dash }:
let
  # Shared shape for the "Key Services (Failed)" stat cells.
  serviceStat = { title, x, y, expr }:
    dash.panel {
      type = "stat";
      inherit title x y;
      w = 8;
      h = 6;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "red"; value = null; }
            { color = "green"; value = 1; }
          ];
        };
        noValue = "none";
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        justifyMode = "center";
        orientation = "vertical";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      targets = [{ expr = expr; legendFormat = "{{instance}}"; }];
    };
in
{
  uid = "service-health";
  title = "Service Health";
  description = "Fleet systemd service health — failed units and key service status.";
  tags = [ "fleet" "services" "systemd" "nix-provisioned" ];
  time = { from = "now-1h"; to = "now"; };
  panels = [
    (dash.row { title = "Systemd Service Status"; y = 0; })
    (dash.row { title = "Failed Services"; y = 1; })
    (dash.panel {
      type = "stat";
      title = "Failed Units";
      x = 0;
      y = 2;
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
      targets = [
        { expr = "(node_systemd_unit_state{state=\"failed\"}) > 0"; legendFormat = "{{instance}} {{name}}"; }
      ];
    })
    (dash.row { title = "Key Services (Failed)"; y = 10; })
    # SSH uses an "active" query (UP when present), so it is spelled out.
    (dash.panel {
      type = "stat";
      title = "SSH (socket/service)";
      x = 0;
      y = 11;
      w = 8;
      h = 6;
      fieldConfig = {
        mappings = [
          {
            type = "value";
            options = {
              "0" = { color = "red"; text = "DOWN"; };
              "1" = { color = "green"; text = "UP"; };
            };
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [
            { color = "red"; value = null; }
            { color = "green"; value = 1; }
          ];
        };
        noValue = "DOWN";
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        justifyMode = "center";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "value_and_name";
      };
      targets = [
        { expr = "max by (instance) (node_systemd_unit_state{name=~\"sshd.service|sshd.socket\", state=\"active\"})"; legendFormat = "{{instance}}"; }
      ];
    })
    (serviceStat {
      title = "Web Server (Failed)";
      x = 8;
      y = 11;
      expr = "(node_systemd_unit_state{name=~\"nginx.service|httpd.service\", state=\"failed\"}) > 0";
    })
    (serviceStat {
      title = "Nix Daemon (Failed)";
      x = 16;
      y = 11;
      expr = "(node_systemd_unit_state{name=\"nix-daemon.service\", state=\"failed\"}) > 0";
    })
    (serviceStat {
      title = "WireGuard (Failed)";
      x = 0;
      y = 17;
      expr = "(node_systemd_unit_state{name=\"wireguard-wireg0.service\", state=\"failed\"}) > 0";
    })
    (serviceStat {
      title = "PostgreSQL (Failed)";
      x = 8;
      y = 17;
      expr = "(node_systemd_unit_state{name=~\"postgresql.service\", state=\"failed\"}) > 0";
    })
    (serviceStat {
      title = "Prometheus (Failed)";
      x = 16;
      y = 17;
      expr = "(node_systemd_unit_state{name=~\"prometheus.service\", state=\"failed\"}) > 0";
    })
    (dash.row { title = "Rclone Backup Services"; y = 23; })
    (dash.panel {
      type = "stat";
      title = "Rclone Backup Status (Failed)";
      x = 0;
      y = 24;
      w = 24;
      h = 6;
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
      targets = [
        { expr = "(node_systemd_unit_state{name=~\"rclone-sync-.*\", state=\"failed\"}) > 0"; legendFormat = "{{instance}} {{name}}"; }
      ];
    })
  ];
}
