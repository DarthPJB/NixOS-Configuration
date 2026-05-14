# tests/topology-validation.nix
# Test suite for topology validation functions

{ lib }:

let
  inherit (builtins) filter map;
  validate = import ../lib/topology/validate.nix { inherit lib; };
  inherit (validate) validateTopology validateCrossReferences;

  # Valid topology example
  validTopology = {
    domain = "example.com";
    lan = {
      subnet = "192.168.1.0/24";
      gateway = "192.168.1.1";
      hosts = {
        host1 = {
          ip = "192.168.1.10";
          mac = "00:11:22:33:44:55";
          hostname = "host1";
        };
        host2 = {
          ip = "192.168.1.11";
          mac = "00:11:22:33:44:56";
          hostname = "host2";
          wireguard = "10.0.0.1";
        };
      };
    };
    forwarding = {
      tcp = [
        { port = 80; dest = "192.168.1.10"; }
        { port = 443; to = "host2"; }
      ];
      udp = [
        { port = 53; dest = "host1"; }
      ];
    };
    dns = {
      static = [
        { domain = "test.example.com"; ip = "192.168.1.10"; }
        { domain = "wg.example.com"; ip = "host2"; }
        "/other.example.com/192.168.1.11"
      ];
    };
    wireguard = {
      listenPort = 51820;
      peers = [ "host1" "host2" ];
      ips = [ "10.0.0.0/24" ];
    };
    nginx = {
      proxies = {
        "app.example.com" = "host1:8080";
        "api.example.com" = "192.168.1.11:3000";
      };
    };
    firewall = {
      allowedTCPPorts = [ 22 80 ];
      allowedUDPPorts = [ 53 ];
    };
  };

  # Invalid topologies with expected errors
  invalidNginxTopology = validTopology // {
    nginx.proxies = validTopology.nginx.proxies // {
      "bad.example.com" = "nonexistent:8080";
    };
  };

  invalidForwardingTopology = validTopology // {
    forwarding.tcp = validTopology.forwarding.tcp ++ [
      { port = 9999; dest = "badhost"; }
    ];
  };

  invalidDnsTopology = validTopology // {
    dns.static = validTopology.dns.static ++ [
      { domain = "bad.example.com"; ip = "192.168.1.99"; }  # Invalid IP
      { domain = "missing.example.com"; ip = "ghost"; }     # Invalid hostname
    ];
  };

  # Test cases
  testValidTopology = {
    name = "valid topology";
    topology = validTopology;
    expectedValid = true;
    expectedErrors = [];
  };

  testInvalidNginx = {
    name = "invalid nginx backend";
    topology = invalidNginxTopology;
    expectedValid = false;
    expectedErrors = [ "nginx proxy 'bad.example.com' backend 'nonexistent' not found in lan.hosts" ];
  };

  testInvalidForwarding = {
    name = "invalid forwarding target";
    topology = invalidForwardingTopology;
    expectedValid = false;
    expectedErrors = [ "forwarding rule dest 'badhost' not found in lan.hosts" ];
  };

  testInvalidDns = {
    name = "invalid DNS entries";
    topology = invalidDnsTopology;
    expectedValid = false;
    expectedErrors = [
      "dns entry ip '192.168.1.99' not a valid IP in topology"
      "dns entry hostname 'ghost' not found in lan.hosts"
    ];
  };

  # Run all tests
  runTest = test:
    let
      result = validateCrossReferences test.topology;
    in
    {
      inherit (test) name;
      passed = (result.valid == test.expectedValid) && (result.errors == test.expectedErrors);
      actualValid = result.valid;
      actualErrors = result.errors;
      expectedValid = test.expectedValid;
      expectedErrors = test.expectedErrors;
    };

  allTests = [
    testValidTopology
    testInvalidNginx
    testInvalidForwarding
    testInvalidDns
  ];

  testResults = map runTest allTests;
  passedTests = filter (t: t.passed) testResults;
  failedTests = filter (t: !t.passed) testResults;

in
{
  inherit testResults passedTests failedTests;
  allPassed = failedTests == [];
}