#!/run/current-system/sw/bin/env nix-shell
#!nix-shell -i bash -p xwinwrap mpv

xwinwrap -ov -fs -b -nf -o 1.0 -g 1920x1080-960 -debug -- mpv -wid WID --loop --no-config --no-input-default-bindings --no-audio ~/ascetics_bin/video/gobi_stars.mp4 &
xwinwrap -ov -fs -b -nf -o 1.0 -g 1920x1080+960 -debug -- mpv -wid WID --loop --no-config --no-input-default-bindings --no-audio ~/ascetics_bin/video/gobi_stars.mp4 && fg
