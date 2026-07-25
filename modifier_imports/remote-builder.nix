# Remote builder configuration — defines the build machines that importing hosts
# dispatch to via nix-daemon ssh-ng protocol.
#
# The hub machine (remote-builder) imports this file and sets max-jobs = 0 to
# force ALL builds through distribution. The hub itself is NOT a builder — it
# is a coordinator that runs GitHub runners and pushes completed paths to cache.
#
# Active builders:
#   hyperhyper (100.107.101.14) — x86_64-linux, 100+ cores, 1TB RAM
#   arm-builder (10.88.127.43) — aarch64-linux, RPi 4
#
# See: documentation/plans/remote-builder-hub-2026-07-15.md
{ config, pkgs, lib, ... }:

let
  # Dynamically collect builder hostnames for SSH exclusion
  builderHosts = map (m: m.hostName) config.nix.buildMachines;

  # Build /etc/nix/machines manually with store URI query params.
  #
  # WHY: max-connections is a per-store RemoteStoreConfig parameter, NOT a global
  # nix.conf setting. Determinate Nix changed the default from 1 (upstream) to 64,
  # which enables SSH master mode (-M -N) for ssh-ng remote builders and causes
  # protocol mismatch errors when masters die and leave stale sockets.
  #
  # arm-builder (RPi 4) needs max-connections=1 — limited resources can't handle
  # concurrent SSH masters. hyperhyper (100+ cores, 1TB RAM) uses the default.
  #
  # The NixOS nix.buildMachines module generates /etc/nix/machines but does not
  # support store URI query params. StoreReference::parse (machines.cc) DOES parse
  # ?key=value from the store URI, so we inject max-connections=1 there.
  #
  # See: documentation/incidents/2026-07-15-ssh-multiplex-ssh-ng-protocol-mismatch.md
  # See: determinate/src/libstore/include/nix/store/remote-store.hh:29-30
  # See: determinate/src/libstore/machines.cc:66-68
  hyperhyperKey = config.secrix.services.nix-daemon.secrets.hyperhyper.decrypted.path;
  armBuilderKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
  machinesText = ''
    ssh-ng://build@100.107.101.14 x86_64-linux ${hyperhyperKey} 10 10 big-parallel,kvm,nixos-test - -
    ssh-ng://build@10.88.127.43?max-connections=1 aarch64-linux ${armBuilderKey} 3 5 big-parallel - -
  '';
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
    {
      hostName = "100.107.101.14"; # hyperhyper
      protocol = "ssh-ng";
      sshUser = "build";
      sshKey = hyperhyperKey;
      systems = [ "x86_64-linux" ];
      maxJobs = 10;
      speedFactor = 10;
      supportedFeatures = [
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "10.88.127.43"; # arm-builder
      protocol = "ssh-ng";
      sshUser = "build";
      sshKey = armBuilderKey;
      systems = [ "aarch64-linux" ];
      maxJobs = 3;
      speedFactor = 5;
      supportedFeatures = [ "big-parallel" ];
      mandatoryFeatures = [ ];
    }
  ];

  # Override the NixOS-generated /etc/nix/machines to embed max-connections=1
  # as a store URI query param. This is necessary because:
  #   1. max-connections is a per-store RemoteStoreConfig param (not nix.conf)
  #   2. NixOS nix.buildMachines doesn't support store URI query params
  #   3. machines.cc only injects max-connections=1 for ssh:// (not ssh-ng)
  #   4. StoreReference::parse DOES parse ?key=value from URIs
  #
  # mkForce on the text field overrides the NixOS module's types.lines
  # concatenation (without mkForce, both texts merge into a broken file).
  environment.etc."nix/machines".text = lib.mkForce machinesText;

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
