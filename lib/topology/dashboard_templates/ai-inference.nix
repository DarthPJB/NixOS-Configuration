# lib/topology/dashboard_templates/ai-inference.nix
#
# AI Inference — vLLM / LiteLLM request rate, latency, KV cache, errors.
# Ported from services/graphana_dashboards/ai-inference.json.
# Queries are model-scoped (sum by (model)), so no host membership generation.
{ dash }:
{
  uid = "ai-inference";
  title = "AI Inference";
  description = "vLLM / LiteLLM inference metrics — request rate, token throughput, latency percentiles, KV cache, errors.";
  tags = [ "ai" "inference" "vllm" "litellm" "nix-provisioned" ];
  panels = [
    (dash.row { title = "Request Rate & Token Throughput"; y = 0; })
    (dash.panel {
      type = "timeseries";
      title = "Request Rate by Model";
      x = 0;
      y = 1;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "reqps";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [{ expr = "sum by (model) (rate(litellm_proxy_total_requests_metric[5m]))"; legendFormat = "{{model}}"; }];
    })
    (dash.panel {
      type = "timeseries";
      title = "Token Throughput (Input / Output) by Model";
      x = 12;
      y = 1;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "tok/s";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "sum by (model) (rate(vllm:prompt_tokens_total[5m]))"; legendFormat = "{{model}} input"; refId = "A"; }
        { expr = "sum by (model) (rate(vllm:generation_tokens_total[5m]))"; legendFormat = "{{model}} output"; refId = "B"; }
      ];
    })
    (dash.row { title = "Latency"; y = 9; })
    (dash.panel {
      type = "timeseries";
      title = "E2E Request Latency p50/p95/p99 by Model";
      x = 0;
      y = 10;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 15; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "s";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "histogram_quantile(0.50, sum by (le, model) (rate(vllm:e2e_request_latency_seconds_bucket[5m])))"; legendFormat = "{{model}} p50"; refId = "A"; }
        { expr = "histogram_quantile(0.95, sum by (le, model) (rate(vllm:e2e_request_latency_seconds_bucket[5m])))"; legendFormat = "{{model}} p95"; refId = "B"; }
        { expr = "histogram_quantile(0.99, sum by (le, model) (rate(vllm:e2e_request_latency_seconds_bucket[5m])))"; legendFormat = "{{model}} p99"; refId = "C"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "Time to First Token p50/p95/p99 by Model";
      x = 12;
      y = 10;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 15; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "s";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "histogram_quantile(0.50, sum by (le, model) (rate(vllm:time_to_first_token_seconds_bucket[5m])))"; legendFormat = "{{model}} p50"; refId = "A"; }
        { expr = "histogram_quantile(0.95, sum by (le, model) (rate(vllm:time_to_first_token_seconds_bucket[5m])))"; legendFormat = "{{model}} p95"; refId = "B"; }
        { expr = "histogram_quantile(0.99, sum by (le, model) (rate(vllm:time_to_first_token_seconds_bucket[5m])))"; legendFormat = "{{model}} p99"; refId = "C"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "LiteLLM Gateway Request Latency p50/p95/p99 by Model";
      x = 0;
      y = 18;
      w = 24;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 15; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "s";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "histogram_quantile(0.50, sum by (le, model) (rate(litellm_request_total_latency_metric_bucket[5m])))"; legendFormat = "{{model}} p50"; refId = "A"; }
        { expr = "histogram_quantile(0.95, sum by (le, model) (rate(litellm_request_total_latency_metric_bucket[5m])))"; legendFormat = "{{model}} p95"; refId = "B"; }
        { expr = "histogram_quantile(0.99, sum by (le, model) (rate(litellm_request_total_latency_metric_bucket[5m])))"; legendFormat = "{{model}} p99"; refId = "C"; }
      ];
    })
    (dash.row { title = "Queue & KV Cache"; y = 26; })
    (dash.panel {
      type = "timeseries";
      title = "Queue Depth (Waiting / Running) by Model";
      x = 0;
      y = 27;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "short";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "sum by (model) (vllm:num_requests_waiting)"; legendFormat = "{{model}} waiting"; refId = "A"; }
        { expr = "sum by (model) (vllm:num_requests_running)"; legendFormat = "{{model}} running"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "timeseries";
      title = "KV Cache Usage % by Model";
      x = 12;
      y = 27;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        max = 100;
        min = 0;
        thresholds = {
          mode = "absolute";
          steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }];
        };
        unit = "percent";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [{ expr = "100 * sum by (model) (vllm:kv_cache_usage_perc)"; legendFormat = "{{model}}"; }];
    })
    (dash.panel {
      type = "gauge";
      title = "KV Cache Usage % per Model";
      x = 0;
      y = 35;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        max = 100;
        min = 0;
        thresholds = {
          mode = "absolute";
          steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }];
        };
        unit = "percent";
      };
      options = {
        orientation = "auto";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        showThresholdLabels = true;
        showThresholdMarkers = true;
      };
      targets = [{ expr = "100 * sum by (model) (vllm:kv_cache_usage_perc)"; legendFormat = "{{model}}"; }];
    })
    (dash.panel {
      type = "stat";
      title = "Requests Running / Waiting";
      x = 12;
      y = 35;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [ ];
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
        unit = "short";
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
        textMode = "auto";
      };
      targets = [
        { expr = "sum by (model) (vllm:num_requests_running)"; legendFormat = "{{model}} running"; refId = "A"; }
        { expr = "sum by (model) (vllm:num_requests_waiting)"; legendFormat = "{{model}} waiting"; refId = "B"; }
      ];
    })
    (dash.row { title = "Errors & Gateway Health"; y = 43; })
    (dash.panel {
      type = "timeseries";
      title = "Error Rate by Model";
      x = 0;
      y = 44;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "palette-classic"; };
        custom = { fillOpacity = 25; lineWidth = 2; spanNulls = true; };
        mappings = [ ];
        thresholds = {
          mode = "absolute";
          steps = [{ color = "green"; value = null; } { color = "yellow"; value = 0.1; } { color = "red"; value = 1; }];
        };
        unit = "reqps";
      };
      options = {
        legend = { displayMode = "table"; placement = "bottom"; showLegend = true; calcs = [ "mean" "max" ]; };
        tooltip = { mode = "multi"; sort = "desc"; };
      };
      targets = [
        { expr = "sum by (model) (rate(litellm_proxy_failed_requests_metric[5m]))"; legendFormat = "{{model}} failed"; refId = "A"; }
        { expr = "sum by (model) (rate(vllm:request_success_total{finished_reason=\"abort\"}[5m]))"; legendFormat = "{{model}} aborted"; refId = "B"; }
      ];
    })
    (dash.panel {
      type = "stat";
      title = "LiteLLM Deployment State";
      x = 12;
      y = 44;
      w = 12;
      h = 8;
      fieldConfig = {
        color = { mode = "thresholds"; };
        mappings = [
          {
            options = {
              "0" = { color = "green"; text = "healthy"; };
              "1" = { color = "yellow"; text = "partial"; };
              "2" = { color = "red"; text = "outage"; };
            };
            type = "value";
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [{ color = "green"; value = null; } { color = "yellow"; value = 1; } { color = "red"; value = 2; }];
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
      targets = [{ expr = "litellm_deployment_state"; legendFormat = "{{model_name}} {{api_base}}"; }];
    })
  ];
}
