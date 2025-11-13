{ config, pkgs, ... }:

{
  secrix.services.nix-daemon.secrets.hyperhyper.encrypted.file = ../secrets/hyper_build_private_key;
  nix.buildMachines = [{
    hostName = "100.107.101.14";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    sshUser = "build"; #
    sshKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
    # if the builder supports building for multiple architectures, 
    # replace the previous line by, e.g.,
    systems = [ "x86_64-linux" /*"aarch64-linux"*/ ];
    maxJobs = 20;
    speedFactor = 5;
    supportedFeatures = [ "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    mandatoryFeatures = [ ];
  }
    #  ,{
    #    hostName = "10.88.128.3"; #The Nas
    #    system = "x86_64-linux";
    #    protocol = "ssh-ng";
    #    sshUser = "build";#
    #sshKey = "/root/id_ed25519_builder";
    # if the builder supports building for multiple architectures, 
    # replace the previous line by, e.g.,
    #    systems = [ "x86_64-linux" /*"aarch64-linux"*/ ];
    #    maxJobs = 20;
    #    speedFactor = 5;
    #    supportedFeatures = [ "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    #    mandatoryFeatures = [ ];
    #}
  ];
  nix = {
    settings = {
      download-buffer-size = 524288000;
      max-jobs = 50;
      cores = 0;
    };
    nrBuildUsers = 50;
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
