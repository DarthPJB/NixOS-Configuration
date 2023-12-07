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
          networks =
            {
              "Imperial_Mobile".pskRaw = "f9e57e756a9c8d3866f38211dbf3be05fb090097793cd46253e69c8cc7055e09";
            };
        };
    };
}
