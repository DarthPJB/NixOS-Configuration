{ config, pkgs, ... }: 

{
    services.xserver = 
    {
        enable = true;
        displayManager.sddm =
        {
            enable = true;
            autoNumlock.enable = true;
        };
        windowManager.i3 = 
        {
            enable = true;
            package = "pkgs.i3-gaps";
            extraPackages = with pkgs; [ dmenu i3status i3lock ];
        };
    };
}
