{ config, pkgs, ... }:

{
  secrix.services.nix-daemon.secrets.hyperhyper.encrypted.file = ../secrets/hyper_build_private_key;
  secrix.services.nix-daemon.secrets.personal-builder.encrypted.file = ../secrets/builder-key;
  nix.buildMachines = [
  #{
  #  hostName = "100.107.101.14";
  #  system = "x86_64-linux";
  #  protocol = "ssh-ng";
  #  sshUser = "build"; #
  #  sshKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
  #  systems = [ "x86_64-linux" ];
  #  maxJobs = 20;
  #  speedFactor = 5;
  #  supportedFeatures = [ "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
  #  mandatoryFeatures = [ ];
  #}
    {
      hostName = "10.88.127.42"; #Display-2
      system = "aarch64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "aarch64-linux" ];
      maxJobs = 3;
      speedFactor = 5;
      supportedFeatures = [];# "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
    {
      hostName = "10.88.127.41"; #Display-1
      system = "aarch64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "aarch64-linux" ];
      maxJobs = 3;
      speedFactor = 3;
      supportedFeatures = [];# "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
    {
      hostName = "10.88.127.3"; #The Nas
      system = "x86_64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "x86_64-linux" ];
      maxJobs = 2;
      speedFactor = 3;
      supportedFeatures = [];# "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
];
  programs.ssh.knownHosts = {
    data-storage = {
      hostNames = [ "data-storage" "10.88.127.3" "10.88.128.3" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINlCggPwFP5VX3YDA1iji0wxX8+mIzmrCJ1aHj9f1ofx";
    };
    hyperhyper = {
      hostNames = [ "hyperhyper" "10.75.79.7" "100.107.101.14" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7puAmpArf5PXkI5wRFkNwqQiulhHxzeBEVvC52IOH";
    };
  };

  nix = {
#    settings = {
#      download-buffer-size = 524288000;
#      max-jobs = 10;
 #     cores = 0;
#    };
#    nrBuildUsers = 50;
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
