{ pkgs, config, ... }:
{
  services.prometheus = {
    enable = true;
    exporters.lmsensors.enable = true;  # Auto-adds lm_sensors; remove manual package.
    scrapeConfigs = [{
      job_name = "host";
      static_configs = [{ targets = [ "localhost:9165" ]; }];  # Correct port for lm_sensors.
    }];
  };

  services.grafana = {
    enable = true;
    settings = {
      server.http_port = 3000;  # Default; explicit for clarity.
      auth.anonymous.enable = false;  # Disable for security.
      auth.basic.enabled = true;     # Enable basic auth.
    };
    provision.datasources = [{
      name = "Prometheus";
      type = "prometheus";
      url = "http://localhost:9090";  # Prometheus default.
    }];
  };
}
