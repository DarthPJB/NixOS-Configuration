# lib/topology/genDashboard.nix
#
# genDashboard: monitoring inventory -> Grafana dashboard attrsets
#
# Pure data transformation. NO module system, NO user Nix. Dashboards are
# composed from templates (lib/topology/dashboard_templates/*.nix) using the
# small builder API exposed here. Host-derived PromQL — the node job union and
# the IP -> hostname rename transforms — is generated from the inventory, so
# fleet membership is never hand-maintained inside dashboard JSON.
#
# Callable in isolation:
#   inventory = (import ./lib/topology/inventory.nix { inherit lib; }) { inherit registry; };
#   gen = (import ./lib/topology/genDashboard.nix { inherit lib; }) { inherit inventory; };
#   dashboard = gen.mkDashboard (import ./lib/topology/dashboard_templates/fleet-cpu-disk-light.nix { dash = gen; });
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Read filesystem paths or user config
{ lib }:
{ inventory }:
let
  inherit (builtins) replaceStrings isString isList isAttrs map removeAttrs;
  inherit (lib) concatStringsSep concatMap foldl' mapAttrs;

  # The datasource provisioned by services/prometheus.nix.
  datasource = { type = "prometheus"; uid = "prometheus01"; };

  # PromQL job union, e.g. "node|hyperhyper-node|malayalam-node".
  nodeJobs = concatStringsSep "|" inventory.nodeJobs;

  # Recursively substitute the __NODE_JOBS__ placeholder with the job union.
  subst = value:
    if isString value then replaceStrings [ "__NODE_JOBS__" ] [ nodeJobs ] value
    else if isList value then map subst value
    else if isAttrs value then mapAttrs (_: subst) value
    else value;

  # Escape dotted IP for use in a Grafana renameByRegex pattern.
  escapeIp = ip: replaceStrings [ "." ] [ "\\." ] ip;

  # One renameByRegex transform: "<ip>:<port>" (or "<ip>") -> hostname.
  mkRename = withPort: host: {
    id = "renameByRegex";
    options = {
      regex = "/${escapeIp host.ip}:(.*)/";
      renamePattern = if withPort then "${host.hostname}:$1" else host.hostname;
    };
  };

  mkRenameTransforms = { hosts, withPort ? true }:
    map (mkRename withPort) hosts;

  # Named, inventory-derived rename sets templates can reference directly.
  renames = {
    nodeBare = mkRenameTransforms { hosts = inventory.node; withPort = false; };
    nodePort = mkRenameTransforms { hosts = inventory.node; withPort = true; };
    zfsPort = mkRenameTransforms { hosts = inventory.zfs; withPort = true; };
    nvidiaPort = mkRenameTransforms { hosts = inventory.nvidia; withPort = true; };
  };

  # Normalize a compact target spec into a full Grafana target.
  # `isRange` selects range-query targets (timeseries-like panels); stat/gauge
  # panels use instant queries and must not set range/editorMode.
  mkTarget = isRange: t:
    let
      refId = t.refId or "A";
    in
    { inherit datasource refId; editorMode = "code"; }
    // (if isRange then { range = true; } else { })
    // (if t ? legendFormat then { inherit (t) legendFormat; } else { })
    // (removeAttrs t [ "refId" "legendFormat" ]);

  # Panel types that issue range queries.
  rangePanelTypes = [ "timeseries" "heatmap" "state-timeline" "barchart" ];

  # Build a full panel from a compact spec.
  # Required: type, title, y. Optional: x, w, h, fieldConfig (the defaults
  # object), overrides, options, targets, transformations, extra.
  panel = spec:
    let
      isRange = builtins.elem spec.type rangePanelTypes;
    in
    {
      inherit datasource;
      inherit (spec) type title;
      gridPos = {
        x = spec.x or 0;
        y = spec.y;
        w = spec.w or 12;
        h = spec.h or 8;
      };
      targets = map (mkTarget isRange) (spec.targets or [ ]);
    }
    // (if spec ? fieldConfig then {
      fieldConfig = {
        defaults = spec.fieldConfig;
        overrides = spec.overrides or [ ];
      };
    } else { })
    // (if spec ? options then { inherit (spec) options; } else { })
    // (if spec ? transformations then { inherit (spec) transformations; } else { })
    // (if spec ? extra then spec.extra else { });

  # Row header panel.
  row = { title, y, collapsed ? false }:
    {
      type = "row";
      inherit title collapsed;
      gridPos = { h = 1; w = 24; x = 0; y = y; };
      panels = [ ];
    };

  # Assign sequential panel ids (Grafana requires unique ids).
  assignIds = panels:
    (foldl'
      (acc: p: {
        panels = acc.panels ++ [ (p // { id = acc.next; }) ];
        next = acc.next + 1;
      })
      { panels = [ ]; next = 1; }
      panels).panels;

  # Shared dashboard root defaults.
  rootDefaults = {
    annotations = { list = [ ]; };
    editable = false;
    fiscalYearStartMonth = 0;
    graphTooltip = 1;
    id = null;
    links = [ ];
    schemaVersion = 42;
    templating = { list = [ ]; };
    timepicker = { };
    version = 1;
    timezone = "utc";
    refresh = "30s";
    time = { from = "now-1h"; to = "now"; };
  };

  # Turn a template attrset into a complete dashboard attrset.
  mkDashboard = tpl:
    rootDefaults
    // {
      uid = tpl.uid;
      title = tpl.title;
      description = tpl.description or "";
      tags = tpl.tags or [ "fleet" "nix-provisioned" ];
      refresh = tpl.refresh or rootDefaults.refresh;
      time = tpl.time or rootDefaults.time;
      timezone = tpl.timezone or rootDefaults.timezone;
      graphTooltip = tpl.graphTooltip or rootDefaults.graphTooltip;
      panels = assignIds (map subst tpl.panels);
    };
in
{
  inherit
    datasource
    nodeJobs
    renames
    mkRenameTransforms
    panel
    row
    mkDashboard
    subst
    lib
    inventory;
}
