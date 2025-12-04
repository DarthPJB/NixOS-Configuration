{ config, pkgs, ... }:

{
  secrix.services.nix-daemon.secrets.personal-builder.encrypted.file = ../secrets/builder-key;
  nix.buildMachines = [
    {
      hostName = "10.88.127.88"; # Linda
      system = "x86_64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "x86_64-linux" ];
      maxJobs = 50;
      speedFactor = 5;
      supportedFeatures = [ "big-parallel" "kvm" "nixos-test" "benchmark" ];
      mandatoryFeatures = [ ];
    }
  ];
  programs.ssh.knownHosts = {
    linda = {
      hostNames = [ "LINDACORE" "10.88.127.88" "10.88.128.88" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMfuVEzn9keN1iVk4rjJmB07+/ynTMaZCKPvbaZ1cF6";
    };
  };

  nix = {
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
