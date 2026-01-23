lib:
{
  mkNginxProxies = proxyConfigs:
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
            value =
              if config.type == "proxy" then
                {
                  useACMEHost = "johnbargman.net";
                  addSSL = true;
                  listenAddresses = config.listenAddresses or [ "10.88.128.1" "10.88.127.1" ];
                  locations = config.locations or {
                    "~/" = {
                      proxyPass = config.proxyPass;
                      extraConfig = config.extraHeaders or commonHeaders;
                      proxyWebsockets = config.proxyWebsockets or true;
                    };
                  };
                } // config.extraConfig or {}
              else if config.type == "static" then
                {
                  enableACME = if config.name == "johnbargman.net" then true else null;
                  acmeRoot = if config.name == "johnbargman.net" then null else null;
                  forceSSL = config.forceSSL or true;
                  listenAddresses = config.listenAddresses or [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ];
                  locations = config.locations or {
                    "/" = {
                      root = config.root;
                    };
                  };
                } // config.extraConfig or {}
              else if config.type == "catch-all" then
                {
                  default = true;
                  listenAddresses = [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ];
                  locations = {
                    "/" = {
                      return = "444";
                    };
                  };
                } // config.extraConfig or {}
              else throw "Unknown proxy type: ${config.type}";
          };
    in
      builtins.listToAttrs (map (p: mkProxyHost p.name p) proxyConfigs);
}