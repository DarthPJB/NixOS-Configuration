{ config, lib, ... }:
let
  inherit (lib) mkOption mkIf types mkMerge mapAttrs splitString last;
in
{
  options.environment.interfaces = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options.ipv4 = mkOption {
        type = types.submodule {
          options = {
            prefix = mkOption {
              type = types.str;
              example = "10.88.127";
              description = "IPv4 /24 prefix for ${name}";
            };
            postfix = mkOption {
              type = types.str;
              example = "1";
              description = "IPv4 host postfix for ${name} (combined with prefix for /32)";
            };
          };
        };
        description = "IPv4 configuration for ${name} (prefix/postfix → /32 auto)";
      };
    }));
    default = { };
    description = "Interface IPv4 definitions (prefix/postfix format)";
  };
  # Generate networking.interfaces from environment.interfaces
  config = mkIf (config.environment.interfaces != { }) (
    mapAttrs (name: iface: {
      ipv4.addresses = [ "${iface.ipv4.prefix}.${iface.ipv4.postfix}/32" ];
    })# config.environment.interfaces );
    }
