# environments/denton-glasses.nix
#
# Machine perception augmentation — eye tracking (OpenFace) + speech-to-text (Voxtype)
#
# "My vision is fully augmented." — JC Denton
#
# Hardware requirements:
#   - Webcam(s) for eye tracking (USB, via V4L2)
#   - Microphone for speech-to-text (USB, via PipeWire/PulseAudio)
#   - NVIDIA GPU recommended for voxtype-vulkan (whisper acceleration)
#
# Device discovery commands (run on target machine):
#   Webcams:    v4l2-ctl --list-devices
#   Microphones: pactl list sources short
#   By-id paths: ls /dev/v4l/by-id/

{ config, pkgs, lib, llm, ... }:

{
  # ── Eye Tracking (OpenFace) ──────────────────────────────────────
  #
  # Uses V4L2 by-id path for stable camera identification.
  # Index "0" can shift across reboots/USB reconnects.
  #
  # To find your webcam's by-id path:
  #   ls /dev/v4l/by-id/
  #   # Example output: usb-Logitech_Webcam_C920e_XXXXXXXX-video-index0
  #
  # Then set camera = "/dev/v4l/by-id/<your-camera>-video-index0";

  denton-glasses.eye-tracking = {
    enable = true;
    user = "John88";

    # TODO: Replace with actual by-id path from `ls /dev/v4l/by-id/` on LINDA.
    #       Using index 0 as placeholder until device enumeration is confirmed.
    camera = "0";

    autoStart = false;  # Manual start until validated with real hardware
    outputDir = "/var/lib/denton-glasses/eye-tracking";
    outputFormat = "csv";
  };

  # ── Speech-to-Text (Voxtype / Whisper) ───────────────────────────
  #
  # Audio pipeline: USB mic → PipeWire → PipeWire-Pulse → voxtype (libpulse)
  #
  # LINDA uses PipeWire with ALSA + PulseAudio compatibility.
  # Voxtype talks PulseAudio (libpulse), which PipeWire-Pulse provides.
  # The ALSA udev rules from the voxtype module are compatible —
  # pipewire-alsa still exposes /dev/snd/pcm*c* device nodes.
  #
  # To find the Q9-1 microphone source name:
  #   pactl list sources short
  #   # Look for something like:
  #   #   alsa_input.usb-XXXX_Q9-1_XXXX.analog-stereo
  #   #   or: bluez_input.XX:XX:XX:XX:XX:XX
  #
  # Then set audio.device to that source name.

  services.voxtype = {
    enable = true;
    user = "John88";
    package = llm.voxtype-vulkan;  # GPU-accelerated whisper via Vulkan (from nixpkgs_llm)

    x11.display = ":0";  # LINDA uses X11 i3wm

    loadModels = [ "base.en" ];

    settings = {
      whisper = {
        model = "base.en";
        language = "en";
      };
      audio = {
        # TODO: Replace "default" with actual Q9-1 PulseAudio source name
        #       from `pactl list sources short` on LINDA.
        #       Example: "alsa_input.usb-XXXX_Q9-1_XXXX.analog-stereo"
        device = "default";
        sample_rate = 16000;
        max_duration_secs = 60;
      };
      output = {
        mode = "type";
        fallback_to_clipboard = true;
      };
    };
  };

  # ── Pipewire Compatibility Notes ─────────────────────────────────
  #
  # LINDA's pipewire config (machines/LINDA/default.nix):
  #   services.pipewire.enable = true;
  #   services.pipewire.alsa.enable = true;       # pipewire-alsa compat
  #   services.pipewire.alsa.support32Bit = true;
  #   services.pipewire.pulse.enable = true;       # pipewire-pulse compat
  #
  # Voxtype's ALSA udev rules:
  #   SUBSYSTEM=="sound", KERNEL=="pcm*c*", GROUP="audio", MODE="0660"
  #   SUBSYSTEM=="sound", KERNEL=="controlC*", GROUP="audio", MODE="0660"
  #
  # These are compatible. pipewire-alsa creates /dev/snd/pcm*c* nodes.
  # Voxtype uses libpulse (not raw ALSA), so pipewire-pulse handles routing.
  #
  # If voxtype cannot find the mic, check:
  #   1. pactl list sources short    — verify source exists
  #   2. pactl set-default-source    — set Q9-1 as default if using "default"
  #   3. systemctl --user status voxtype  — check service logs
}
