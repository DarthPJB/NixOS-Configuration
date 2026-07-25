# Unit tests for the topology-derive NixOS module
# Run with: nix --option builders '' eval --impure --json --expr \
#   'import /tmp/nixos-planar-topology/tests/topology/topology-derive.nix'
#
# These tests verify that topology-derive.nix correctly transforms
# topology/<hostname>.json files into NixOS config for:
#   - networking.interfaces.*.ipv4.addresses (from coordinate entries)
#   - services.prometheus.exporters.*        (from exporters map)
#   - services.nginx.virtualHosts.*          (from vhosts map + default_response)
#
# Test fixtures: topology/__test_f1.json, topology/__test_f2.json,
# topology/__test_f3.json. These are valid topology entries on the
# cortex-alpha.lan plane with unique peer_ids (240-242) to avoid
# registry validation errors.
#
# Architecture: Phase 5-1.3.2 of the planar topology plan.

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  types = lib.types;
  inherit (builtins) length elem;

  # ── Module under test ─────────────────────────────────────────
  modulePath = /tmp/nixos-planar-topology/modules/topology-derive.nix;

  # ── Options required by the module but not declared by it ──
  # The module itself declares options.topology.enable.
  # All other config paths it reads/sets must be declared here.
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

  # ── Helper: evaluate module for a given hostname ──────────────
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

  # ═══════════════════════════════════════════════════════════════
  # Fixture 1: __test_f1  — Simple leaf with 2 coordinates
  #   - cortex-alpha.lan/10.88.128.0/24  peer_id=240  → 10.88.128.240/24
  #   - wg/10.88.127.0/24               peer_id=240  → 10.88.127.240/24
  #   - No vhosts, no exporters, no default_response
  # NOTE: interface derivation from coordinates is DISABLED for PONR.
  # Interfaces will be managed in a later phase. The computation
  # remains in topology-derive but is not wired into config.
  # ═══════════════════════════════════════════════════════════════
  f1 = evalHost "__test_f1";
  f1Ifaces = f1.networking.interfaces or { };

  f1NginxEnabled = f1.services.nginx.enable or false;
  f1Vhosts = f1.services.nginx.virtualHosts or { };
  f1Exporters = f1.services.prometheus.exporters or { };

  # ── Test 1 & 8: Simple leaf — interfaces are DISABLED ─────────
  testF1InterfacesEmpty = {
    name = "f1_interfaces_empty_interfaces_disabled";
    expected = true;
    actual = f1Ifaces == { };
    pass = f1Ifaces == { };
  };

  testF1NoNginx = {
    name = "f1_nginx_not_enabled_no_vhosts";
    expected = false;
    actual = f1NginxEnabled;
    pass = !f1NginxEnabled;
  };

  testF1NoVhosts = {
    name = "f1_no_vhosts";
    expected = true;
    actual = f1Vhosts == { };
    pass = f1Vhosts == { };
  };

  testF1NoExporters = {
    name = "f1_no_exporters";
    expected = true;
    actual = f1Exporters == { };
    pass = f1Exporters == { };
  };

  # ═══════════════════════════════════════════════════════════════
  # Fixture 2: __test_f2  — Host with exporters + vhosts
  #   - cortex-alpha.lan/10.88.128.0/24  peer_id=241  → 10.88.128.241/24
  #   - exporters: { node: {}, disk: {} }
  #   - default_response: "444"
  #   - vhosts: static (johnbargman.net), proxy (code.johnbargman.net)
  # ═══════════════════════════════════════════════════════════════
  f2 = evalHost "__test_f2";
  f2Exporters = f2.services.prometheus.exporters or { };
  f2Vhosts = f2.services.nginx.virtualHosts or { };
  f2NginxOn = f2.services.nginx.enable or false;
  f2AcmeGroup = f2.users.users.nginx.extraGroups or [ ];

  # ── Test 2: Default exporter ports ──────────────────────────
  testF2NodeExporterEnabled = {
    name = "f2_node_exporter_enabled";
    expected = true;
    actual = f2Exporters.node.enable or false;
    pass = f2Exporters.node.enable or false;
  };

  testF2NodeExporterDefaultPort = {
    name = "f2_node_exporter_default_port_9100";
    expected = 9100;
    actual = f2Exporters.node.port or null;
    pass = (f2Exporters.node.port or null) == 9100;
  };

  testF2DiskExporterEnabled = {
    name = "f2_disk_exporter_enabled";
    expected = true;
    actual = f2Exporters.disk.enable or false;
    pass = f2Exporters.disk.enable or false;
  };

  testF2DiskExporterDefaultPort = {
    name = "f2_disk_exporter_default_port_9102";
    expected = 9102;
    actual = f2Exporters.disk.port or null;
    pass = (f2Exporters.disk.port or null) == 9102;
  };

  # ── Test 7: Exporter listenAddress = firstIP ────────────────
  testF2ExporterListenAddress = {
    name = "f2_exporter_listen_address_equals_first_ip";
    expected = "10.88.128.241";
    actual = f2Exporters.node.listenAddress or null;
    pass = (f2Exporters.node.listenAddress or null) == "10.88.128.241";
  };

  # ── Test 4: Proxy vhost ────────────────────────────────────
  testF2NginxEnabled = {
    name = "f2_nginx_enabled_with_vhosts";
    expected = true;
    actual = f2NginxOn;
    pass = f2NginxOn;
  };

  testF2HasProxyVhost = {
    name = "f2_has_proxy_vhost";
    expected = true;
    actual = f2Vhosts ? "code.johnbargman.net";
    pass = f2Vhosts ? "code.johnbargman.net";
  };

  testF2ProxyPass = {
    name = "f2_proxy_vhost_proxyPass";
    expected = "http://10.88.127.3:80";
    actual = f2Vhosts."code.johnbargman.net".locations."~/".proxyPass or null;
    pass = (f2Vhosts."code.johnbargman.net".locations."~/".proxyPass or null) == "http://10.88.127.3:80";
  };

  testF2ProxyNoReturn = {
    name = "f2_proxy_vhost_no_return";
    expected = true;
    actual = !(f2Vhosts."code.johnbargman.net".locations."~/" ? return);
    pass = !(f2Vhosts."code.johnbargman.net".locations."~/" ? return);
  };

  # ── New tests for proxy vhost enhancements ────────────────
  testF2ProxyWebsockets = {
    name = "f2_proxy_vhost_proxyWebsockets";
    expected = true;
    actual = f2Vhosts."code.johnbargman.net".locations."~/".proxyWebsockets or false;
    pass = f2Vhosts."code.johnbargman.net".locations."~/".proxyWebsockets or false;
  };

  testF2ProxyNoExtraConfig = {
    name = "f2_proxy_vhost_no_extra_config";
    expected = true;
    actual = !(f2Vhosts."code.johnbargman.net".locations."~/" ? extraConfig);
    pass = !(f2Vhosts."code.johnbargman.net".locations."~/" ? extraConfig);
  };

  # ── Test 5: Static vhost ──────────────────────────────────
  testF2HasStaticVhost = {
    name = "f2_has_static_vhost";
    expected = true;
    actual = f2Vhosts ? "johnbargman.net";
    pass = f2Vhosts ? "johnbargman.net";
  };

  testF2StaticRoot = {
    name = "f2_static_vhost_root";
    expected = true;
    actual = builtins.isPath (f2Vhosts."johnbargman.net".locations."/".root or "");
    pass = builtins.isPath (f2Vhosts."johnbargman.net".locations."/".root or "");
  };

  testF2StaticNoProxy = {
    name = "f2_static_vhost_no_proxy";
    expected = true;
    actual = !(f2Vhosts."johnbargman.net".locations."/" ? proxyPass);
    pass = !(f2Vhosts."johnbargman.net".locations."/" ? proxyPass);
  };

  # ── Test 6: default_response "444" ─────────────────────────
  testF2HasDefaultVhost = {
    name = "f2_has_default_vhost_from_444_response";
    expected = true;
    actual = f2Vhosts ? "_";
    pass = f2Vhosts ? "_";
  };

  testF2DefaultVhostReturn = {
    name = "f2_default_vhost_return_444";
    expected = "444";
    actual = f2Vhosts."_".locations."/".return or null;
    pass = (f2Vhosts."_".locations."/".return or null) == "444";
  };

  testF2DefaultVhostIsDefault = {
    name = "f2_default_vhost_is_default";
    expected = true;
    actual = f2Vhosts."_".default or false;
    pass = f2Vhosts."_".default or false;
  };

  # ── ForceSSL pass-through ──────────────────────────────────
  testF2StaticVhostForceSSL = {
    name = "f2_static_vhost_forceSSL";
    expected = true;
    actual = f2Vhosts."johnbargman.net".forceSSL or false;
    pass = f2Vhosts."johnbargman.net".forceSSL or false;
  };

  # ── ACME group on nginx user ───────────────────────────────
  testF2NginxAcmeGroup = {
    name = "f2_nginx_acme_group_added";
    expected = true;
    actual = elem "acme" f2AcmeGroup;
    pass = elem "acme" f2AcmeGroup;
  };

  # ═══════════════════════════════════════════════════════════════
  # Fixture 3: __test_f3  — Port override + ACME
  #   - cortex-alpha.lan/10.88.128.0/24  peer_id=242  → 10.88.128.242/24
  #   - exporters: { node: { port: 9101 } }
  #   - vhosts: static + acme enable
  # ═══════════════════════════════════════════════════════════════
  f3 = evalHost "__test_f3";
  f3Exporters = f3.services.prometheus.exporters or { };
  f3Vhosts = f3.services.nginx.virtualHosts or { };

  # ── Test 3: Port override ──────────────────────────────────
  testF3NodeExporterPortOverride = {
    name = "f3_node_exporter_port_override_9101";
    expected = 9101;
    actual = f3Exporters.node.port or null;
    pass = (f3Exporters.node.port or null) == 9101;
  };

  testF3NodeExporterEnabled = {
    name = "f3_node_exporter_enabled_with_override";
    expected = true;
    actual = f3Exporters.node.enable or false;
    pass = f3Exporters.node.enable or false;
  };

  # ── Test 10: ACME configuration — self-managed cert ────────
  # secure.johnbargman.net has acme.enable=true + acme.host="johnbargman.net"
  # (different from vhost name) → should set enableACME=true + useACMEHost
  testF3SelfManagedVhost = {
    name = "f3_has_self_managed_vhost";
    expected = true;
    actual = f3Vhosts ? "secure.johnbargman.net";
    pass = f3Vhosts ? "secure.johnbargman.net";
  };

  testF3SelfManagedAcmeEnable = {
    name = "f3_self_managed_enableACME";
    expected = true;
    actual = f3Vhosts."secure.johnbargman.net".enableACME or false;
    pass = f3Vhosts."secure.johnbargman.net".enableACME or false;
  };

  testF3SelfManagedUseACMEHost = {
    name = "f3_self_managed_useACMEHost";
    expected = "johnbargman.net";
    actual = f3Vhosts."secure.johnbargman.net".useACMEHost or null;
    pass = (f3Vhosts."secure.johnbargman.net".useACMEHost or null) == "johnbargman.net";
  };

  testF3SelfManagedForceSSL = {
    name = "f3_self_managed_forceSSL";
    expected = true;
    actual = f3Vhosts."secure.johnbargman.net".forceSSL or false;
    pass = f3Vhosts."secure.johnbargman.net".forceSSL or false;
  };

  # ── Test 11: ACME configuration — shared cert (no enableACME, just useACMEHost) ──
  testF3SharedVhost = {
    name = "f3_has_shared_cert_vhost";
    expected = true;
    actual = f3Vhosts ? "apps.johnbargman.net";
    pass = f3Vhosts ? "apps.johnbargman.net";
  };

  testF3SharedNoEnableACME = {
    name = "f3_shared_cert_no_enableACME";
    expected = false;
    actual = f3Vhosts."apps.johnbargman.net".enableACME or false;
    pass = !(f3Vhosts."apps.johnbargman.net".enableACME or false);
  };

  testF3SharedUseACMEHost = {
    name = "f3_shared_cert_useACMEHost";
    expected = "johnbargman.net";
    actual = f3Vhosts."apps.johnbargman.net".useACMEHost or null;
    pass = (f3Vhosts."apps.johnbargman.net".useACMEHost or null) == "johnbargman.net";
  };

  testF3SharedForceSSL = {
    name = "f3_shared_cert_forceSSL";
    expected = true;
    actual = f3Vhosts."apps.johnbargman.net".forceSSL or false;
    pass = f3Vhosts."apps.johnbargman.net".forceSSL or false;
  };

  testF3ExporterListenAddress = {
    name = "f3_exporter_listen_address_first_ip";
    expected = "10.88.128.242";
    actual = f3Exporters.node.listenAddress or null;
    pass = (f3Exporters.node.listenAddress or null) == "10.88.128.242";
  };

  # ═══════════════════════════════════════════════════════════════
  # Test 9: Host with no topology JSON file
  #   - nonexistent hostname → hasTopology = false → empty config
  # ═══════════════════════════════════════════════════════════════
  fnone = evalHost "nonexistent-host";

  testNoTopoInterfacesEmpty = {
    name = "no_topo_interfaces_empty";
    expected = true;
    actual = (fnone.networking.interfaces or { }) == { };
    pass = (fnone.networking.interfaces or { }) == { };
  };

  testNoTopoNginxNotEnabled = {
    name = "no_topo_nginx_not_enabled";
    expected = false;
    actual = fnone.services.nginx.enable or false;
    pass = !(fnone.services.nginx.enable or false);
  };

  testNoTopoExportersEmpty = {
    name = "no_topo_exporters_empty";
    expected = true;
    actual = (fnone.services.prometheus.exporters or { }) == { };
    pass = (fnone.services.prometheus.exporters or { }) == { };
  };

  testNoTopoVhostsEmpty = {
    name = "no_topo_vhosts_empty";
    expected = true;
    actual = (fnone.services.nginx.virtualHosts or { }) == { };
    pass = (fnone.services.nginx.virtualHosts or { }) == { };
  };

  # ═══════════════════════════════════════════════════════════════
  # All checks
  # ═══════════════════════════════════════════════════════════════
  checks = [
    # ── Test 1 & 8: Simple leaf — interfaces disabled ──
    testF1InterfacesEmpty
    testF1NoNginx
    testF1NoVhosts
    testF1NoExporters

    # ── Test 2: Default exporter ports ──────────────────
    testF2NodeExporterEnabled
    testF2NodeExporterDefaultPort
    testF2DiskExporterEnabled
    testF2DiskExporterDefaultPort

    # ── Test 4: Proxy vhost ────────────────────────────
    testF2NginxEnabled
    testF2HasProxyVhost
    testF2ProxyPass
    testF2ProxyNoReturn
    testF2ProxyWebsockets
    testF2ProxyNoExtraConfig

    # ── Test 5: Static vhost ───────────────────────────
    testF2HasStaticVhost
    testF2StaticRoot
    testF2StaticNoProxy

    # ── Test 6: default_response "444" ─────────────────
    testF2HasDefaultVhost
    testF2DefaultVhostReturn
    testF2DefaultVhostIsDefault

    # Extra: forceSSL + acme group
    testF2StaticVhostForceSSL
    testF2NginxAcmeGroup

    # ── Test 7: firstIP / plane IPs ────────────────────
    testF2ExporterListenAddress

    # ── Test 3: Port override ─────────────────────────
    testF3NodeExporterPortOverride
    testF3NodeExporterEnabled

    # ── Test 10: ACME configuration — self-managed ────
    testF3SelfManagedVhost
    testF3SelfManagedAcmeEnable
    testF3SelfManagedUseACMEHost
    testF3SelfManagedForceSSL

    # ── Test 11: ACME configuration — shared cert ─────
    testF3SharedVhost
    testF3SharedNoEnableACME
    testF3SharedUseACMEHost
    testF3SharedForceSSL

    testF3ExporterListenAddress

    # ── Test 9: No topology JSON ───────────────────────
    testNoTopoInterfacesEmpty
    testNoTopoNginxNotEnabled
    testNoTopoExportersEmpty
    testNoTopoVhostsEmpty
  ];

  passed = lib.all (c: c.pass) checks;
  failed = length (builtins.filter (c: !c.pass) checks);

in
{
  inherit passed;
  total = length checks;
  inherit failed;
  checks = checks;
}
