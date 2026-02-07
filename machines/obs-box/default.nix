# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }: { hostname }
{
systemd.user.services.obs-auto =
{
description = "obs-studio-autostart";
wantedBy = [ "graphical-session.target" ];
serviceConfig =
{
Restart = "always";
ExecStart = ''
            ${pkgs.obs-studio}/bin/obs
          '';
PassEnvironment = "DISPLAY XAUTHORITY";
};
};
systemd.user.services.x11vnc =
{
description = "run X11 vnc server";
wantedBy = [ "graphical-session.target" ];
serviceConfig =
{
Restart = "always";
ExecStart = ''
            ${pkgs.x11vnc}/bin/x11vnc -display $DISPLAY 
          '';
PassEnvironment = "DISPLAY XAUTHORITY";
};
};

imports =
[
# Include the results of the hardware scan.
./hardware-configuration.nix
];
security = {
sudo = {
wheelNeedsPassword = false;
extraConfig = ''
        %psudo ALL=(ALL) PASSWD: ALL
      '';
};
};
environment.extraInit = ''
    xset s off -dpms
  '';
# Use the systemd-boot EFI boot loader.
boot.loader.systemd-boot.enable = true;
boot.zfs.extraPools = [ "storage" ];
boot.loader.efi.canTouchEfiVariables = true;

services.syncthing = {
enable = true;
openDefaultPorts = true;
guiAddress = "0.0.0.0:8080";
};

networking.hostId = "1d2797ef"; # Define your hostname.
networking.useDHCP = false;
networking.interfaces.enp0s31f6.useDHCP = true;
networking.interfaces.wlp4s0.useDHCP = true;
users.users.commander = {
openssh.authorizedKeys.keys =
[
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcZrafX+y1V7Q1lSZUSSR6R0ouIPuYL1KCAZw6kOsqe l33@nixos"
];
};


# Set your time zone.
time.timeZone = "Etc/UTC";

#  Select internationalisation properties.
i18n.defaultLocale = "en_GB.UTF-8";
console = {
font = "Lat2-Terminus16";
keyMap = "uk";
};
# Enable the OpenSSH daemon.
services.openssh.ports = [ 1108 22 ];
# Open ports in the firewall.
networking.firewall.allowedTCPPorts = [ 1108 8080 22 5900 ];

# Configure keymap in X11

system.stateVersion = "22.11";

services.pipewire = {
enable = true;
alsa.enable = true;
alsa.support32Bit = true;
pulse.enable = true;
};
hardware = {
sane.enable = true;
opengl.enable = true;
#pulseaudio.enable = true;
cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
opengl.driSupport32Bit = true;
#pulseaudio.support32Bit = true;
nvidia = {
package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
modesetting.enable = false;
powerManagement.enable = true;
};
};
nixpkgs.config.allowUnfree = true;
nixpkgs.config.nvidia.acceptLicense = true;
environment.systemPackages =
[
(pkgs.wrapOBS {
plugins = with pkgs.obs-studio-plugins; [
obs-multi-rtmp
obs-move-transition
];
})
];
services =
{
xserver =
{
libinput.enable = true;
videoDrivers = [ "nvidia" ];
layout = "gb";
displayManager = {
defaultSession = "none+i3";
autoLogin = {
enable = true;
user = "commander";
};
};
windowManager.i3.enable = true;
};
};
