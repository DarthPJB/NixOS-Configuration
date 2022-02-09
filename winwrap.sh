#!/run/current-system/sw/bin/env nix-shell
#!nix-shell -i bash -p xwinwrap mplayer

xwinwrap -ov -b -nf -o 1.0 -g 1920x1080+1920+0 -debug -- mplayer -wid WID -loop 0 ~/ascetics_bin/video/gobi_stars.mp4 &
xwinwrap -ov -b -nf -o 1.0 -g 1920x1080 -debug -- mplayer -wid WID -loop 0  ~/ascetics_bin/video/gobi_stars.mp4 && fg
