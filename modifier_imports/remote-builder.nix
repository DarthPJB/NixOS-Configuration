{ config, pkgs, ... }:

{
  secrix.services.nix-daemon.secrets.hyperhyper.encrypted.file = ../secrets/hyper_build_private_key;
  secrix.services.nix-daemon.secrets.personal-builder.encrypted.file = ../secrets/builder-key;
  nix.buildMachines = [
 {
    hostName = "100.107.101.14";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    sshUser = "build"; #
    sshKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
    systems = [ "x86_64-linux" ];
    maxJobs = 10;
    speedFactor = 10;
    supportedFeatures = [ "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    mandatoryFeatures = [ ];
  }
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
      hostName = "10.88.127.50";# "remote-worker.johnbargman.net"; # remote-builder
      system = "x86_64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "x86_64-linux" ];
      maxJobs = 3;
      speedFactor = 2;
      supportedFeatures = [ ];# "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
   {
      hostName = "10.88.127.51"; #"remote-builder.johnbargman.net"; # remote-builder
      system = "x86_64-linux";
      protocol = "ssh-ng";
      sshUser = "build"; #
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "x86_64-linux" ];
      maxJobs = 6;
      speedFactor = 4;
      supportedFeatures = [ ];# "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
];
  programs.ssh.knownHosts = {
    display-1 = {
      hostNames = [ "display-1" "10.88.127.41" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOxb+iAm5nTcC3oRsMIcxcciKRj8VnGpp1JIAdGVTZU root@display-1";
    };
    display-2 = {
      hostNames = [ "display-2" "10.88.127.42" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcOQZcWlN4XK5OYjI16PM/BWK/8AwKePb1ca/ZRuR1p root@display-2";
    };
    remote-builder = {
      hostNames = [ "remote-builder" "10.88.127.50" "remote-builder.johnbargman.net" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfb/Bbr0PaFDyO92q+GXHHXTAlTYR4uSLm0jivou4IB";
    };
    remote-worker = {
      hostNames = [ "remote-worker" "10.88.127.51" "remote-worker.johnbargman.net"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7Owkd/9PC7j/L5PbPXrSMx0Aw/1owIoCsfp7+5OKek";
    };
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
    settings = {
     # download-buffer-size = 524288000;
#      max-jobs = 10;
 #     cores = 0;
    };
#    nrBuildUsers = 50;
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
