{ config, pkgs, ... }: 

{
    xsession = 
    {
        enable = true;
        numlock.enable = true;

        windowManager.i3 = 
        {
            enable = true;
            package = pkgs.i3-gaps;
            config = rec 
            {
                gaps = 
                {
                    inner = 20;
                    outer = 10;
                };
            };
        };
    };
}
