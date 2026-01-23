lib:
{
  mkProxyPass = proxyConfigs:
    let
      mkProxyHost = name: config:
        let
          commonHeaders = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
        in
          {
            inherit name;
            value = {
              useACMEHost = "johnbargman.net";
              addSSL = true;
              listenAddresses = config.listenAddresses or [ "10.88.128.1" "10.88.127.1" ];
              locations = {
                "~/" = {
                  proxyPass = config.proxyPass;
                  extraConfig = config.extraHeaders or commonHeaders;
                  proxyWebsockets = config.proxyWebsockets or true;
                };
              };
            } // config.extraConfig or {};
          };
    in
      builtins.listToAttrs (map (p: mkProxyHost p.name p) proxyConfigs);
}