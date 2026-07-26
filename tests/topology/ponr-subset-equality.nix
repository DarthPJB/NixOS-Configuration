# tests/topology/ponr-subset-equality.nix
# PONR-1.3: Subset equality harness
#
# Compares topology-derive output against /tmp/ponr-baseline/ dumps
# for 7 managed machines across managed key paths:
#   - services.prometheus.exporters
#   - services.nginx.enable
#   - services.nginx.virtualHosts
#
# This is an IMPURE evaluation (reads from /tmp/ponr-baseline/).
# Run with:
#   nix --option builders '' eval --impure --json --expr \
#     'import /tmp/nixos-planar-topology/tests/topology/ponr-subset-equality.nix'
#
# Design: topology-derive's output is a SUBSET of the baseline dump.
# The managed machines have competing sources that add more config,
# so we only verify that everything topology-derive produces matches
# the corresponding parts of the baseline.

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  types = lib.types;
  inherit (builtins)
    readFile fromJSON pathExists attrNames length;

  # ── Configuration ─────────────────────────────────────────────
  # Baselines captured at /tmp/ponr-baseline/ (impure path)
  baselineDir = "/tmp/ponr-baseline/";

  # Managed machines (have exporters or vhosts in topology JSON)
  managedMachines = [
    "cortex-alpha"
    "remote-worker"
    "gaming-host-1"
    "display-1"
    "display-2"
    "print-controller"
    "remote-builder"
  ];

  # ── Topology-derive module ───────────────────────────────────
  modulePath = /tmp/nixos-planar-topology/modules/topology-derive.nix;

  # Options required by topology-derive but not declared by it
  baseOptions = {
    options = {
      networking.hostName = lib.mkOption { type = types.str; default = "unknown"; };
      networking.interfaces = lib.mkOption { type = types.attrs; default = { }; };
      services.nginx = lib.mkOption {
        type = types.submodule {
          options = {
            enable = lib.mkOption { type = types.bool; default = false; };
            virtualHosts = lib.mkOption { type = types.attrs; default = { }; };
          };
        };
      };
      services.prometheus.exporters = lib.mkOption { type = types.attrs; default = { }; };
      users.users.nginx.extraGroups = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      assertions = lib.mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
      };
      warnings = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };

  # Evaluate topology-derive for a hostname
  evalHost = hostname:
    let
      evaled = lib.evalModules {
        modules = [
          baseOptions
          { config._module.check = false; }
          { networking.hostName = hostname; }
          (import modulePath)
        ];
      };
    in
    evaled.config;

  # Read baseline dump for a hostname
  readBaseline = hostname:
    let
      path = baselineDir + "/${hostname}.json";
    in
    if pathExists path then fromJSON (readFile path)
    else { };

  # ── Comparison helpers ──────────────────────────────────────

  # Compare two values for equality, recursing into attrsets/lists
  # Returns true if equal, false otherwise.
  # Handles special types: null, bool, int, string, list, attrset
  deepEqual = a: b:
    if a == null && b == null then true
    else if a == null || b == null then false
    else if builtins.isAttrs a && builtins.isAttrs b then
      let
        aNames = attrNames a;
        bNames = attrNames b;
        # All a's keys must exist in b and be equal
        allMatch = aNames == [ ] || lib.all (n: builtins.elem n bNames && deepEqual a.${n} b.${n}) aNames;
      in
      allMatch
    else if builtins.isList a && builtins.isList b then
      length a == length b && lib.all (i: deepEqual (builtins.elemAt a i) (builtins.elemAt b i)) (lib.genList (x: x) (length a))
    else
      a == b;

  # Extract baseline values for comparison.
  # The baseline dump has flattened keys like "services.prometheus";
  # sub-paths are accessed as dump["services.prometheus"].exporters.
  # We need to handle this carefully.
  baselineExporters = hostname:
    let
      dump = readBaseline hostname;
      servicesPrometheus = dump."services.prometheus" or { };
    in
      servicesPrometheus.exporters or { };

  baselineNginxEnable = hostname:
    let
      dump = readBaseline hostname;
      servicesNginx = dump."services.nginx" or { };
    in
      servicesNginx.enable or false;

  baselineVhosts = hostname:
    let
      dump = readBaseline hostname;
      servicesNginx = dump."services.nginx" or { };
    in
      servicesNginx.virtualHosts or { };

  # ── Run comparison for each machine ─────────────────────────

  # Build per-machine checks
  machineChecks = map
    (hostname:
      let
        # Get topology-derive output
        topoConfig = evalHost hostname;

        # Managed keys from topology-derive
        deriveExporters = topoConfig.services.prometheus.exporters or { };
        deriveNginxEnable = topoConfig.services.nginx.enable or false;
        deriveVhosts = topoConfig.services.nginx.virtualHosts or { };

        # Baseline values
        baseExporters = baselineExporters hostname;
        baseNginxEnable = baselineNginxEnable hostname;
        baseVhosts = baselineVhosts hostname;

        # Exporter names
        deriveExporterNames = attrNames deriveExporters;

        # Check exporters: for each exporter topology-derive produces,
        # verify the baseline has matching fields.
        exporterChecks = map
          (expName:
            let
              deriveVal = deriveExporters.${expName};
              baseVal = baseExporters.${expName} or null;
              expPresent = baseVal != null;
              deriveKeys = attrNames deriveVal;
              allEqual = lib.all (k: deepEqual (deriveVal.${k} or null) (baseVal.${k} or null)) deriveKeys;
            in
            {
              name = "${hostname}_exporter_${expName}";
              expected = true;
              actual = expPresent && allEqual;
              pass = expPresent && allEqual;
            }
          )
          deriveExporterNames;

        # Check nginx.enable — only when topology-derive explicitly sets it
        # (i.e., when it produces vhosts). Machines where topology-derive
        # does not manage nginx (e.g. print-controller with klipper nginx from
        # another module) should be skipped.
        nginxEnableCheck = {
          name = "${hostname}_nginx_enable";
          expected = baseNginxEnable;
          actual = deriveNginxEnable;
          pass =
            if deriveVhosts != { } then
              deriveNginxEnable == baseNginxEnable
            else
              true; # Skip: derive doesn't manage nginx for this machine
        };

        # Check vhosts: for each vhost topology-derive produces,
        # verify the baseline has it with matching fields.
        # Only compare KEY METADATA fields (forceSSL, default, addSSL,
        # enableACME, useACMEHost, serverName). Skip locations and root
        # because:
        #   - Path values (root) are serialized differently in baseline dumps
        #   - Location shapes vary depending on serialization context
        #   - Location correctness is verified by golden test comparison
        deriveVhostNames = attrNames deriveVhosts;
        vhostChecks = map
          (vhName:
            let
              deriveVal = deriveVhosts.${vhName};
              baseVal = baseVhosts.${vhName} or null;
              vhPresent = baseVal != null;

              # Compare only key vhost metadata fields
              keyFields = [
                "forceSSL"
                "default"
                "addSSL"
                "enableACME"
                "useACMEHost"
                "serverName"
              ];
              relevantFields = builtins.filter
                (f:
                  builtins.elem f (attrNames deriveVal)
                )
                keyFields;
              fieldChecks = map
                (f:
                  deepEqual (deriveVal.${f} or null) (baseVal.${f} or null)
                )
                relevantFields;
              allFieldsMatch = if relevantFields == [ ] then true else lib.all (x: x) fieldChecks;
            in
            {
              name = "${hostname}_vhost_${vhName}";
              expected = true;
              actual = vhPresent && allFieldsMatch;
              pass = vhPresent && allFieldsMatch;
            }
          )
          deriveVhostNames;

      in
      {
        name = hostname;
        checks = exporterChecks ++ [ nginxEnableCheck ] ++ vhostChecks;
      }
    )
    managedMachines;

  # ── Aggregate results ──────────────────────────────────────
  allChecks = lib.flatten (map (m: m.checks) machineChecks);
  total = length allChecks;
  passed = lib.all (c: c.pass) allChecks;
  failed = length (builtins.filter (c: !c.pass) allChecks);

  # Print per-machine summary
  machineSummaries = map
    (m:
      let
        mc = m.checks;
        fp = length (builtins.filter (c: !c.pass) mc);
        tp = length (builtins.filter (c: c.pass) mc);
      in
      {
        machine = m.name;
        total = length mc;
        passed = tp;
        failed = fp;
      }
    )
    machineChecks;

in
{
  inherit passed total failed;
  machines = machineSummaries;
  checks = allChecks;
}
