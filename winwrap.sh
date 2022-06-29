#!/run/current-system/sw/bin/env nix-shell
#!nix-shell -i bash -p xwinwrap mplayer
sleep 5;
if [ `DISPLAY=:0 xrandr -q | grep ' connected' | wc -l` = "2" ]
then
	xwinwrap -ov -b -nf -o 1.0 -g 1920x1080+1920+0 -debug -- mplayer -wid WID -loop 0 ~/ascetics_bin/video/gobi_stars.mp4 &
fi
if [ `DISPLAY=:0 xrandr -q | grep ' connected' | wc -l` = "3" ]
then
	xwinwrap -ov -b -nf -o 1.0 -g 900x1600 -debug -- mplayer -wid WID -loop 0  ~/ascetics_bin/video/gobi_stars.mp4 &
	xwinwrap -ov -b -nf -o 1.0 -g 1920x1080+1080+0 -debug -- mplayer -wid WID -loop 0  ~/ascetics_bin/video/gobi_stars.mp4 && fg
else
	xwinwrap -ov -b -nf -o 1.0 -g 1366x768 -debug -- mplayer -wid WID -loop 0  ~/ascetics_bin/video/gobi_stars.mp4 && fg
fi
