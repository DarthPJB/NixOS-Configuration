#!/run/current-system/sw/bin/env nix-shell
#!nix-shell -i bash -p xwinwrap mplayer
if `DISPLAY=:0 xrandr -q | grep ' connected' | wc -l` = 2
then
  xwinwrap -ov -b -nf -o 1.0 -g 1920x1080+1920+0 -debug -- mplayer -wid WID -loop 0 ~/ascetics_bin/video/gobi_stars.mp4 &
fi
xwinwrap -ov -b -nf -o 1.0 -g 1920x1080 -debug -- mplayer -wid WID -loop 0  ~/ascetics_bin/video/gobi_stars.mp4 && fg
