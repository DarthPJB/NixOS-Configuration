{ config, pkgs, ... }:

{
  # Use librsvg's gdk-pixbuf loader cache file as it enables gdk-pixbuf to load SVG files (important for icons)
  environment.sessionVariables = {
    GDK_PIXBUF_MODULE_FILE = "$(echo ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/*/loaders.cache)";
  };
  environment.systemPackages = [
    pkgs.arc-theme
    pkgs.betterlockscreen
    pkgs.brightnessctl
    pkgs.pavucontrol
    pkgs.volumeicon
    pkgs.enlightenment.terminology
    pkgs.conky
    pkgs.lxappearance
    pkgs.arandr
  ];
  services.displayManager.sddm =
    {
      enable = true;
      autoNumlock = true;
    };
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
  programs.dconf.enable = true;
  services.xserver =
    let
      xConfig = pkgs.writeText "i3.config" ''
        gaps inner 5
        gaps outer 8
        # You can also use any non-zero value if you'd like to have a border
        for_window [class=".*"] border pixel 0

        # Only enable gaps on a workspace when there is at least one container
        smart_gaps on

        # Only enable outer gaps when there is exactly one container
        smart_gaps inverse_outer

        set $mod Mod4

        # Font for window titles. Will also be used by the bar unless a different font
        # is used in the bar {} block below.
        #font pango:monospace 10
        font pango:DejaVu Sans Mono 10

        # fire up blumane-applet
        exec --no-startup-id blueman-applet
        #set background wallpaper
        exec --no-startup-id xsetroot -solid "#000000"
        # set display settings from arandr
        exec --no-startup-id "sleep 2; ~/.screenlayout/layout.sh"

        # Use pactl to adjust volume in PulseAudio.
        set $refresh_i3status killall -SIGUSR1 i3status
        bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ +10% && $refresh_i3status
        bindsym XF86AudioLowerVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ -10% && $refresh_i3status
        bindsym XF86AudioMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && $refresh_i3status

        # Use Mouse+$mod to drag floating windows to their wanted position
        floating_modifier $mod

        # start a terminal
        bindsym $mod+Return exec terminology

        # kill focused window
        bindsym $mod+Shift+q kill

        # start rofi (a program launcher)
        bindsym $mod+d exec rofi -show run

        # Lock screen
        bindsym $mod+l exec betterlockscreen --lock blur


        # alternatively, you can use the cursor keys:
        bindsym $mod+Left focus left
        bindsym $mod+Down focus down
        bindsym $mod+Up focus up
        bindsym $mod+Right focus right

        # alternatively, you can use the cursor keys:
        bindsym $mod+Shift+Left move left
        bindsym $mod+Shift+Down move down
        bindsym $mod+Shift+Up move up
        bindsym $mod+Shift+Right move right

        # split in horizontal orientation
        bindsym $mod+h split h

        # split in vertical orientation
        bindsym $mod+v split v

        # enter fullscreen mode for the focused container
        bindsym $mod+f fullscreen toggle

        # change container layout (stacked, tabbed, toggle split)
        #bindsym $mod+s layout stacking
        #bindsym $mod+w layout tabbed
        #bindsym $mod+e layout toggle split

        # toggle tiling / floating
        bindsym $mod+space floating toggle

        # change focus between tiling / floating windows
        #bindsym $mod+space focus mode_toggle

        # focus the parent container
        bindsym $mod+a focus parent

        # focus the child container
        #bindsym $mod+d focus child

        # Define names for default workspaces for which we configure key bindings later on.
        # We use variables to avoid repeating the names in multiple places.
        set $ws1 "1"
        set $ws2 "2"
        set $ws3 "3"
        set $ws4 "4"
        set $ws5 "5"
        set $ws6 "6"
        set $ws7 "7"
        set $ws8 "8"
        set $ws9 "9"
        set $ws10 "10"

        # switch to workspace
        bindsym $mod+1 workspace number $ws1
        bindsym $mod+2 workspace number $ws2
        bindsym $mod+3 workspace number $ws3
        bindsym $mod+4 workspace number $ws4
        bindsym $mod+5 workspace number $ws5
        bindsym $mod+6 workspace number $ws6
        bindsym $mod+7 workspace number $ws7
        bindsym $mod+8 workspace number $ws8
        bindsym $mod+9 workspace number $ws9
        bindsym $mod+0 workspace number $ws10

        # move focused container to workspace
        bindsym $mod+Shift+1 move container to workspace number $ws1
        bindsym $mod+Shift+2 move container to workspace number $ws2
        bindsym $mod+Shift+3 move container to workspace number $ws3
        bindsym $mod+Shift+4 move container to workspace number $ws4
        bindsym $mod+Shift+5 move container to workspace number $ws5
        bindsym $mod+Shift+6 move container to workspace number $ws6
        bindsym $mod+Shift+7 move container to workspace number $ws7
        bindsym $mod+Shift+8 move container to workspace number $ws8
        bindsym $mod+Shift+9 move container to workspace number $ws9
        bindsym $mod+Shift+0 move container to workspace number $ws10

        # restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
        bindsym $mod+Shift+r restart
        # exit i3 (logs you out of your X session)
        bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'"

        # resize window (you can also use the mouse for that)
        mode "resize" {
                # These bindings trigger as soon as you enter the resize mode

                # same bindings, but for the arrow keys
                bindsym Left resize shrink width 10 px or 10 ppt
                bindsym Down resize grow height 10 px or 10 ppt
                bindsym Up resize shrink height 10 px or 10 ppt
                bindsym Right resize grow width 10 px or 10 ppt

                # back to normal: Enter or Escape or $mod+r
                bindsym Return mode "default"
                bindsym Escape mode "default"
                bindsym $mod+r mode "default"
        }

        bindsym $mod+r mode "resize"

        # Star to display a workspace bar (plus the system information i3status
        # finds out, if available)
        bar {
                status_command i3status
        }

        	'';
    in
    {
      enable = true;
      desktopManager.gnome.extraGSettingsOverrides = ''
        [org.gnome.desktop.interface]
        gtk-theme='Arc-Dark'
      '';
      windowManager.i3 =
        {
          enable = true;
          configFile = "${xConfig}";
          extraPackages = [
            pkgs.betterlockscreen
            pkgs.rofi
            pkgs.i3status
            pkgs.i3lock
          ];
        };
    };
}
