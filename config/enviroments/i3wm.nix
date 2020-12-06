{ config, pkgs, ... }: 

{
    services.compton.enable = true;
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
            package = pkgs.i3-gaps;
            extraPackages = [ pkgs.dmenu pkgs.i3status pkgs.i3lock ];
        };
    };
}
