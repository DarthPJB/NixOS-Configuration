# Topology Schema Documentation

## Overview

The topology schema serves as the single source of truth for network configuration in the NixOS Configuration repository. It defines the physical network reality for a router/gateway machine (currently `cortex-alpha`), encompassing all aspects of routing, addressing, firewall rules, DNS, port forwarding, and service exposure.

The topology data is stored in `real-topology/<hostname>.nix` files and consumed by various transformation functions to generate configuration for services like WireGuard, nftables, nginx, DHCP, and Tailscale.

## Schema Structure

The topology is a Nix attribute set with the following top-level sections:

### `domain`
- **Type**: String
- **Description**: The primary domain for the network (e.g., `"johnbargman.net"`)

### `lan`
- **Type**: Attribute set
- **Fields**:
  - `subnet`: String (CIDR notation, e.g., `"10.88.128.0/24"`)
  - `gateway`: String (IP address of the gateway)
  - `interface`: String (LAN interface name, e.g., `"enp3s0"`)
  - `wanInterface`: String (WAN interface name, e.g., `"enp2s0"`)
  - `hosts`: Attribute set of host definitions
    - Each host has:
      - `ip`: String (IP address)
      - `mac`: String (optional, MAC address)
      - `hostname`: String (optional, hostname)
      - `routing`: Attribute set
        - `tailscale`: Boolean (whether accessible via Tailscale)
        - `wireguard`: Boolean (whether accessible via WireGuard)
      - `services`: List of strings (optional, service tags like `"gaming"`, `"storage"`)

### `forwarding`
- **Type**: Attribute set
- **Fields**:
  - `tcp`: List of forwarding rules
    - Each rule: `{ from: "wan"; port: number; to: "ip:port"; }`
  - `udp`: List of forwarding rules
    - Each rule: `{ from: "wan"; port: number; to: "ip:port"; }`

### `dns`
- **Type**: Attribute set
- **Fields**:
  - `interface`: String (DNS interface)
  - `static`: List of attribute sets `{ domain: string; ip: string; }`
  - `dhcp`: Attribute set
    - `range`: String (DHCP range, e.g., `"10.88.128.128,10.88.128.254,24h"`)
    - `interface`: String
  - `servers`: List of strings (upstream DNS servers)

### `nginx`
- **Type**: Attribute set
- **Fields**:
  - `proxies`: Attribute set mapping hostname to backend URL
    - Example: `"service.domain.com" = "http://10.88.128.10:80";`

### `wireguard`
- **Type**: Attribute set
- **Fields**:
  - `interface`: String (interface name, e.g., `"wireg0"`)
  - `ips`: List of strings (IP addresses/CIDRs for the interface)
  - `listenPort`: Number (listen port)
  - `peers`: List of strings (peer hostnames)

### `firewall`
- **Type**: Attribute set
- **Fields**:
  - `allowedTCPPorts`: List of numbers (globally allowed TCP ports)
  - `allowedUDPPorts`: List of numbers (globally allowed UDP ports)
  - `interfaces`: Attribute set mapping interface names to port allowances
    - Each interface: `{ allowedTCPPorts: [numbers]; allowedUDPPorts: [numbers]; }`

### `tailscale`
- **Type**: Attribute set
- **Fields**:
  - `subnetRouter`: Boolean (enable subnet routing)
  - `advertisedHosts`: List of strings (hostnames to advertise)
  - `advertisedRoutes`: List of strings (CIDR routes to advertise)

## Validation Rules

The topology is validated using `lib/topology/validate.nix`, which checks:

- **Domain**: Must be a non-empty string
- **LAN**:
  - Must be an attribute set with `subnet`, `gateway`, `hosts`
  - `subnet` must be valid CIDR notation
  - `gateway` must be a valid IP address
  - Each host must have a valid IP address within the subnet
  - No duplicate IP addresses or MAC addresses across hosts
- **Forwarding**:
  - `tcp` and `udp` must be lists
  - Each rule must have `port` and `dest` fields
- **DNS**:
  - `static` must be a list of strings in `/domain/ip` format
- **WireGuard**:
  - `listenPort` must be a number if present
- **Firewall**:
  - `allowedTCPPorts` and `allowedUDPPorts` must be lists

Validation returns `{ valid: boolean; errors: list; warnings: list; }`

## Transformation Functions

The following `lib/mk*.nix` functions consume topology data to generate configurations:

- **`lib/mkNftables.nix`**: Generates NAT rules for port forwarding from topology `forwarding` section
- **`lib/mkProxyPass.nix`**: Creates nginx reverse proxy configurations from topology `nginx.proxies`
- **`lib/mkDhcpReservations.nix`**: Generates DHCP host reservations from topology `lan.hosts`
- **`lib/mkKnownHosts.nix`**: Creates SSH known_hosts entries (consumes host data)

Note: `lib/topology/default.nix` contains placeholder functions for future topology-specific transformations.

## Example

A minimal topology file:

```nix
{
  domain = "example.com";

  lan = {
    subnet = "192.168.1.0/24";
    gateway = "192.168.1.1";
    interface = "eth0";
    wanInterface = "eth1";

    hosts = {
      server = {
        ip = "192.168.1.10";
        mac = "aa:bb:cc:dd:ee:ff";
        hostname = "myserver";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ "web" ];
      };
    };
  };

  forwarding = {
    tcp = [
      { from = "wan"; port = 80; to = "192.168.1.10:80"; }
    ];
    udp = [];
  };

  dns = {
    interface = "eth0";
    static = [
      { domain = "web.example.com"; ip = "192.168.1.10"; }
    ];
    dhcp = {
      range = "192.168.1.100,192.168.1.200,12h";
      interface = "eth0";
    };
    servers = [ "8.8.8.8" ];
  };

  nginx = {
    proxies = {
      "web.example.com" = "http://192.168.1.10:80";
    };
  };

  wireguard = {
    interface = "wg0";
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    peers = [ "server" ];
  };

  firewall = {
    allowedTCPPorts = [ 22 ];
    interfaces = {
      wg0 = {
        allowedTCPPorts = [ 80 443 ];
      };
    };
  };

  tailscale = {
    subnetRouter = false;
    advertisedHosts = [];
    advertisedRoutes = [];
  };
}
```

## Adding New Machines

To add a new machine to the topology system:

1. **Update Topology File**: Add the new host to `real-topology/<router>.nix` under `lan.hosts`
   - Assign a unique IP within the subnet
   - Set MAC address if known
   - Configure routing flags (`tailscale`, `wireguard`)
   - Add service tags if applicable

2. **Add to WireGuard Peers**: If `wireguard = true`, add hostname to `wireguard.peers` list

3. **Configure Firewall**: Add interface-specific rules in `firewall.interfaces` if needed

4. **Update DNS**: Add static DNS entries in `dns.static` for services on the new machine

5. **Add Nginx Proxies**: If exposing services, add entries to `nginx.proxies`

6. **Validate**: Run `nix flake check` to ensure no syntax errors and validation passes

7. **Generate Golden**: Update the golden file: `nix run .#generate-golden -- <router> > real-topology/golden/<router>.json`

8. **Deploy**: Test and deploy the router configuration</content>
</xai:function_call name="bash">
<parameter name="command">nix flake check 2>&1 | head -20