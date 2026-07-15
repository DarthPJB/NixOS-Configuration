{ config, pkgs, lib, ... }:

let
  # Dynamically collect builder hostnames for SSH exclusion
  builderHosts = map (m: m.hostName) config.nix.buildMachines;
in
{
  secrix.services.nix-daemon.secrets.hyperhyper.encrypted.file = ../secrets/hyper_build_private_key;
  secrix.services.nix-daemon.secrets.personal-builder.encrypted.file = ../secrets/builder-key;

  # Wire builder hosts into ssh-multiplex exclusion list.
  # Nix-daemon's ssh-ng connections MUST NOT be multiplexed —
  # ControlMaster corrupts the protocol handshake (NixOS/nix#14132).
  sshMultiplex.exclusions = builderHosts;

  # Belt-and-suspenders: explicit Host block for build user connections.
  # Matches any host accessed as the build user, regardless of IP.
  programs.ssh.extraConfig = ''
    # Nix remote builder — disable multiplexing for ssh-ng protocol
    Host build@*
      ControlMaster no
      ControlPath none
  '';

  nix.buildMachines = [
    /*
      {
        hostName = "100.127.177.30";
        protocol = "ssh-ng";
        sshUser = "build";
        sshKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
        systems = [ "aarch64-darwin" ];
        maxJobs = 10;
        speedFactor = 10;
        supportedFeatures = [ "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
        mandatoryFeatures = [ ];
      }
    */
    {
      # in nix.conf this reads:
      #  builders = 'ssh://build@100.107.101.14 x86_64-linux /home/razvan/.ssh/??? 30 5 big-parallel,kvm,nixos-test,benchmark - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUV4N3B1QW1wQXJmNVBYa0k1d1JGa053cVFpdWxoSHh6ZUJFVnZDNTJJT0gK';
      hostName = "100.107.101.14";
      protocol = "ssh-ng";
      sshUser = "build";
      sshKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
      systems = [ "x86_64-linux" ];
      maxJobs = 10;
      speedFactor = 10;
      supportedFeatures = [
        "big-parallel"
        "kvm"
      ]; # "nixos-test" "benchmark"
      mandatoryFeatures = [ ];
    }
    {
      hostName = "10.88.127.43"; # arm-builder
      protocol = "ssh-ng";
      sshUser = "build";
      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
      systems = [ "aarch64-linux" ];
      maxJobs = 3;
      speedFactor = 5;
      supportedFeatures = [ "big-parallel" ];
      mandatoryFeatures = [ ];
    }
    # {
    #   hostName = "10.88.127.41"; # Display-1 (kitchen wall display — not a builder)
    #   protocol = "ssh-ng";
    #   sshUser = "build";
    #   sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
    #   systems = [ "aarch64-linux" ];
    #   maxJobs = 3;
    #   speedFactor = 3;
    #   supportedFeatures = [ ]; # "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    #   mandatoryFeatures = [ ];
    # }
    #   {
    #      hostName = "10.88.127.50"; # "remote-worker.johnbargman.net"; # remote-builder
    #      system = "x86_64-linux";
    #      protocol = "ssh-ng";
    #      sshUser = "build"; #
    #      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
    #      systems = [ "x86_64-linux" ];
    #      maxJobs = 3;
    #      speedFactor = 2;
    #      supportedFeatures = [ ]; # "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    #      mandatoryFeatures = [ ];
    #    }
    #    {
    #      hostName = "10.88.127.51"; #"remote-builder.johnbargman.net";
    #      system = "x86_64-linux";
    #      protocol = "ssh-ng";
    #      sshUser = "build"; #
    #      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
    #      systems = [ "x86_64-linux" ];
    #      maxJobs = 6;
    #      speedFactor = 4;
    #      supportedFeatures = [ ]; # "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    #      mandatoryFeatures = [ ];
    #    }
    #    {
    #      hostName = "10.88.127.21"; #"nx-01.local";
    #      system = "x86_64-linux";
    #      protocol = "ssh-ng";
    #      sshUser = "build"; #
    #      sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
    #      systems = [ "x86_64-linux" ];
    #      maxJobs = 6;
    #      speedFactor = 2;
    #      supportedFeatures = [ ]; # "big-parallel" "kvm" ]; #   "nixos-test" "benchmark"
    #      mandatoryFeatures = [ ];
    #    }
  ];
  programs.ssh.knownHosts = {
    pompeii = {
      hostNames = [
        "pompeii"
        "100.127.177.30"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL4FWg5satPAkNLJ0kRFEUi7DFtly4Xb3Yr0kUrrb53d";
    };
    hyperhyper = {
      hostNames = [
        "hyperhyper"
        "10.75.79.7"
        "100.107.101.14"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7puAmpArf5PXkI5wRFkNwqQiulhHxzeBEVvC52IOH";
    };
  };

  nix = {
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
