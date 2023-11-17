{ config, pkgs, ... }:

{
  #    nix.buildMachines = [ {
  #     hostName = "192.168.0.93";
  #     system = "x86_64-linux";
  #     protocol = "ssh-ng";
  #     sshUser = "John88";
  # if the builder supports building for multiple architectures, 
  # replace the previous line by, e.g.,
  # systems = ["x86_64-linux" "aarch64-linux"];
  #     maxJobs = 20;
  #     speedFactor = 2;
  #     supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  #     mandatoryFeatures = [ ];
  #    }] ;
  #    nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
