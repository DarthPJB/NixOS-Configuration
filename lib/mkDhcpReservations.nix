{ dhcpHosts ? { } }:
let

  mkDhcpEntry = mac: attrs:
    let
      ip = attrs.ip or (throw "Missing ip for ${mac}");
      hostname = attrs.hostname or "";
      lease = attrs.lease or "infinite";
    in
    "${mac},${ip}${if hostname != "" then ",${hostname}" else ""},${lease}";

in
builtins.attrValues (builtins.mapAttrs mkDhcpEntry dhcpHosts)
