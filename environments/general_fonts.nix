{ config, pkgs, ... }:

{
  fonts = {
    # URW / Base-14 Postscript fonts for X11 applications
    enableGhostscriptFonts = true;

    # Baseline set: dejavu_fonts, freefont_ttf, gyre-fonts, liberation_ttf,
    # unifont, noto-fonts-color-emoji (also pulled by services.graphical-desktop;
    # declared here as explicit font policy).
    enableDefaultPackages = true;

    packages = with pkgs; [
      # Latin Noto families — required so the defaultFonts names below resolve
      noto-fonts

      # CJK coverage (provides Noto Sans/Serif/Mono CJK SC)
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      # kmscon console font (services.kmscon.config.font-name = "Source Code Pro")
      source-code-pro
    ];

    # Latin first, CJK as per-glyph fallback. fontconfig <prefer> order picks
    # the first family covering the glyph, so CJK-first would force CJK font
    # Latin metrics onto every application.
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
        serif = [ "Noto Serif" "Noto Serif CJK SC" ];
        monospace = [ "Noto Sans Mono" "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
