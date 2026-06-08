# local-worker.nix — QEMU guest with CUDA and virtiofs overlay nix store
# Machine was retired. Stored as reference snippet.
#
# Key features:
# - QEMU guest with virtiofs mounts
# - Overlay filesystem for nix store (read-only base + writable layer)
# - CUDA/NVIDIA support
# - Blender environment
# - Serial console support
#
# To reactivate: uncomment local-worker in flake.nix and restore machines/local-worker/

{ config
, pkgs
, hostname
, ...
}:
{
  imports = [
    ../../configuration.nix
    ../../environments/blender.nix
    ../../modifier_imports/cuda.nix
    ../../environments/neovim.nix
    ../../environments/emacs.nix
    ../../environments/sshd.nix
    ./hardware-configuration.nix
  ];
  services.pulseaudio.support32Bit = true;
  services.pulseaudio.enable = true;
  hardware = {
    sane.enable = true;
    graphics.enable = true;
    graphics.enable32Bit = true;
    nvidia = {
      open = false;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
  services = {
    libinput.enable = true;
    xserver = {
      videoDrivers = [ "nvidia" ];
      deviceSection = ''
        Option "Coolbits" "24"
      '';
    };
  };

  boot = {
    kernelParams = [
      "console=ttyS0,115200"
      "console=tty1"
    ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # Special filesystems for virtiofs
    initrd.supportedFilesystems = [
      "overlay"
      "virtiofs"
    ];
    initrd.availableKernelModules = [
      "overlay"
      "virtiofs"
    ];
  };

  # virtiofs mounts for shared storage
  fileSystems = {
    "/public_share" = {
      device = "public_share";
      fsType = "virtiofs";
    };
    "/rendercache" = {
      device = "rendercache";
      fsType = "virtiofs";
    };
    "/88_FS" = {
      device = "88_FS";
      fsType = "virtiofs";
    };

    # Overlay nix store: read-only base via virtiofs + writable tmpfs layer
    "/nix/.ro-store" = {
      neededForBoot = true;
      device = "nixstore";
      fsType = "virtiofs";
    };
    "/nix/store" = {
      fsType = "overlay";
      device = "overlay";
      neededForBoot = true;
      options = [
        "lowerdir=/nix/.ro-store"
        "upperdir=/nix/.rw-store/store"
        "workdir=/nix/.rw-store/work"
      ];
      depends = [
        "/nix/.ro-store"
        "/nix/.rw-store/store"
        "/nix/.rw-store/work"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    cudatoolkit
    linuxPackages.nvidia_x11
    cudaPackages.cudnn
    libGLU
    libGL
    xorg.libXi
    xorg.libXmu
    freeglut
    xorg.libXext
    xorg.libX11
    xorg.libXv
    xorg.libXrandr
    zlib
    ncurses5
    stdenv.cc
    binutils
    ffmpeg
    tmux
    btop
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
