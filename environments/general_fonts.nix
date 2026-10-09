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

      # Emoji is already in enableDefaultPackages; listed for policy clarity
      noto-fonts-color-emoji
    ];

    # The Noto set (single vendor): sans/serif Latin-first with CJK as
    # per-glyph fallback; monospace is Noto Sans Mono CJK SC outright — one
    # fixed-width family covering Latin + CJK in terminals and on the console.
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
        serif = [ "Noto Serif" "Noto Serif CJK SC" ];
        monospace = [ "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
