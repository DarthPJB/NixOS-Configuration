{  proxyConfigs  ? {} }:
let
    mkProxyHost = name: proxyPass:
    {
        useACMEHost = "johnbargman.net";
        addSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" ]; # Internal interfaces only
        locations."~/" = 
        {
            proxyPass = proxyPass;
            extraConfig = ''
                proxy_set_header host $host;
                proxy_set_header x-real-ip $remote_addr;
                proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
                proxy_set_header x-forwarded-proto $scheme;
            '';
            proxyWebsockets = true;
        };
    };
in
builtins.mapAttrs mkProxyHost proxyConfigs
