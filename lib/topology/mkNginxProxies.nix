rec {

  mkProxyHost = { topology, config ? {}, hostname, backendUrl }:
    let
      acmeHost = config.acmeHost or topology.domain;
      listenAddrs = config.listenAddresses or [ "10.88.128.1" "10.88.127.1" ];
    in
    {
      useACMEHost = acmeHost;
      addSSL = true;
      listenAddresses = listenAddrs;
      locations."~/" = {
        proxyPass = backendUrl;
        extraConfig = ''
          proxy_set_header host $host;
          proxy_set_header x-real-ip $remote_addr;
          proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
          proxy_set_header x-forwarded-proto $scheme;
        '';
        proxyWebsockets = true;
      };
    };

  mkAllProxies = { topology, config ? {} }:
    builtins.mapAttrs (hostname: backendUrl: mkProxyHost { inherit topology config hostname backendUrl; }) topology.nginx.proxies;

}