{ config, pkgs, ... }:

{
  fonts.enableGhostscriptFonts = true;
  fonts.packages = with pkgs; [
    #    noto-fonts
    #noto-fonts-cjk
    #noto-fonts-emoji
    liberation_ttf
    #    fira-code
    #fira-code-symbols
    #mplus-outline-fonts
    #dina-font
    #proggyfonts
  ];
}
