{ config, pkgs, ... }: 

{
    # https://nixos.wiki/wiki/I3
    services.compton.enable = true;
    services.xserver = 
    {
        enable = true;
        displayManager.sddm =
        {
            enable = true;
            autoNumlock = true;
        };
        windowManager.i3 = 
        {
            enable = true;
            package = pkgs.i3-gaps;
            extraPackages = [ 
		pkgs.rofi 
		pkgs.i3status 
		pkgs.i3lock
		];
        };
    };
}
