{ config, lib, pkgs, modulesPath, ... }:

# Some of you out there might see this as a security risk
# let me explain how wrong you are.
# if you can FIND MY HOUSE, you can sniff packets and get in
# if you can FIND MY HOUSE, you can pick the lock and plug-in
# if you can get into my network, you have nothing.
# don't put secure systems on wifi
# don't put secure systems in your house.
# don't think a WPA key will do anything.
# plz, drive by my house, get free WIFI.
# plz - internet is a human right, I'm happy to share.

{
  networking =
    {
      wireless =
        {
          scanOnLowSignal = false;
          networks =
            {
              "MI5-Monitoring-System" =
                {
                  priority = 1;
                  authProtocols = [ "WPA-PSK" "WPA-PSK-SHA256" ];
                  pskRaw = "0e4974085e4edb6fe8318604d0c8ca6e371c697c59577721b7473bbba302f85f";
                };
              "MI5-CCTV-NODE" = {
                priority = 0;
                authProtocols = [ "WPA-PSK-SHA256" "SAE" ];
                pskRaw = "aaa174f84b1ae6a1ec92df26aa509dfc4949d9285520465c5eefe388060238bd";
              };
            };
        };
    };
}
