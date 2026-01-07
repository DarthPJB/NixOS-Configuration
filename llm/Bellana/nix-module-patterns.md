# Nix Module Patterns - Bellana Analysis

## Environment Modules (environments/)

### Package Collection Pattern
```nix
{ config, pkgs, unstable, ... }:

{
  environment.systemPackages = with pkgs; [
    package1
    package2
    unstable.experimental-package
  ];
}
```

**Characteristics:**
- Simple attribute sets with environment.systemPackages
- Mix stable (pkgs) and unstable (unstable) packages
- No options/config sections - pure configuration
- Focused on single logical environments (code, browsers, etc.)

### Service Integration Pattern
```nix
{ config, lib, ... }:

{
  services.someService = {
    enable = true;
    setting = "value";
  };
}
```

## Service Modules (services/)

### Parameterized Service Pattern
```nix
{ fqdn, listen-addr }: { pkgs, config, lib, self, ... }:
let
  inherit fqdn listen-addr;
in
{
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      # Cross-system references via self.nixosConfigurations
    ];
  };
}
```

**Characteristics:**
- Function parameters for configuration flexibility
- Cross-system references using self.nixosConfigurations
- Complex service interdependencies
- Network configuration integration

### Infrastructure Service Pattern
```nix
{ config, lib, ... }:

{
  services.nginx.virtualHosts = {
    "domain.com" = {
      enableACME = true;
      locations."/" = {
        proxyPass = "http://internal:port";
      };
    };
  };
}
```

## Library Modules (lib/)

### Option Definition Pattern
```nix
{ config, pkgs, lib, self, ... }:

{
  options.environment.vpn = {
    enable = lib.mkEnableOption "enable WireGuard";
    postfix = lib.mkOption { type = lib.types.int; };
  };

  config = lib.mkIf config.environment.vpn.enable {
    networking.wireguard.interfaces.wireg0 = {
      # Implementation using config.environment.vpn.postfix
    };
  };
}
```

**Characteristics:**
- Clear options/config separation
- lib.mkEnableOption for boolean toggles
- lib.mkIf for conditional configuration
- Type-safe option definitions

## Machine Configurations (machines/)

### Import Composition Pattern
```nix
{ config, lib, pkgs, self, ... }:

{
  imports = [
    ../../services/acme_server.nix
    ../../modifier_imports/zfs.nix
    ./hardware-configuration.nix
  ];

  # Machine-specific overrides
  services.specificService = { ... };
}
```

**Characteristics:**
- Relative path imports for modularity
- Hardware config separation
- Service and modifier composition
- Machine-specific customizations

### Complex Networking Pattern
```nix
networking = {
  wireguard.interfaces.wireg0 = {
    privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.${config.networking.hostName}.decrypted.path;
    peers = (import ../../lib/wg_peers.nix { inherit self; });
  };
  firewall.allowedTCPPorts = [ 443 ];
  nat.forwardPorts = [ { sourcePort = 80; destination = "internal:80"; } ];
};
```

## Modifier Imports (modifier_imports/)

### System Modifier Pattern
```nix
{ config, lib, ... }:

{
  # Enable virtualization
  virtualisation.libvirtd.enable = true;

  # Additional packages
  environment.systemPackages = [ pkgs.virt-manager ];
}
```

**Characteristics:**
- Focused on single system capabilities
- No options - direct configuration
- Composable with other modifiers

## Code Quality Patterns

### String Interpolation
- Use `${}` for variable interpolation
- `builtins.toString` for number conversion
- `config.secrix.<service>.<secret>.decrypted.path` for secrets

### List and Attribute Set Formatting
```nix
environment.systemPackages = with pkgs; [
  pkg1
  pkg2
];

services.myService = {
  enable = true;
  setting1 = "value";
};
```

### Conditional Configuration
- `lib.mkIf` for feature toggles
- `lib.mkDefault` for overridable defaults
- Avoid imperative conditionals

## Anti-Patterns Observed

### Direct Unstable Access
- Avoid: `self.inputs.nixpkgs_unstable.legacyPackages.<system>.<package>`
- Prefer: Propagate via `_module.args.unstable`

### Imperative Secrets
- Never commit plaintext secrets
- Always use secrix for encryption/decryption

### Monolithic Configurations
- Break down complex services into separate modules
- Use imports for composition rather than large files