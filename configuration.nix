# This is the general configuration for all of my systems; anything in here will be found on every possible system I have.

{ config
, pkgs
, self
, lib
, ...
}:
let
  build-all-script = pkgs.writeShellApplication {
    name = "nix-build-all";
    meta.description = "like a baby CI, locally.. oh that's just a builder...";
    runtimeInputs = [
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      nix flake show --json | jq '.packages."x86_64-linux" | keys_unsorted[]' |
      while IFS= read -r pkg; do nix build .#"$pkg"; done
    '';
  };
in
{
  # Yes; absolute you are authorised; or I do not exist; This is fundemental John ~ Crash
  #  networking.firewall = {
  #    enable = true;
  #    extraNftablesRules = ''
  #      chain nixos-fw-refuse {
  #        # override the refuse chain to drop silently
  #        drop
  #      }
  #    '';
  #};

  imports = [
    ./locale/home_networks.nix
    ./modifier_imports/flakes.nix
    ./users/darthpjb.nix
    ./modifier_imports/hosts.nix
    ./modifier_imports/energy_saving.nix
    ./users/deployment.nix
    ./users/inspect.nix
    ./locale/en_gb.nix
    ./locale/home_networks.nix
    ./environments/sshd.nix
    ./environments/tools.nix
    ./modules/nixos-deployment-exporter.nix
    ./modules/sysdiag.nix
    ./environments/metrics.nix
  ];
  environment.systemPackages = with pkgs; [
    build-all-script
    pkgs.tmux
    pkgs.progress
    pkgs.parted
    pkgs.bottom
  ];
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.nixos-deployment-exporter.port
  ];
  boot.zfs.forceImportRoot = lib.mkDefault false;
  services.nixos-deployment-exporter = {
    enable = true;
    port = 3111;
  };
  # System diagnostics — disabled for review, enable when ready for deployment
  # services.sysdiag = {
  #   enable = true;
  #   enableTimer = true;
  #   # Collect everything except slow hardware scan
  #   collection.hardware = false;
  #   # Size safeguards — critical for verbose systems (debug logging, no rate limits)
  #   maxFileSize = "10M";
  #   maxTotalSize = "100M";
  #   # Reduced journal limits for verbose systems
  #   journalRecentLines = 1000;
  #   journalErrorLines = 500;
  #   journalWarningLines = 500;
  #   # Boot journals can be 100MB+ with debug logging — skip by default
  #   collectBootJournal = false;
  #   timerConfig = {
  #     OnBootSec          = "10min";
  #     OnUnitActiveSec    = "6h";
  #     RandomizedDelaySec = "15min";
  #     Persistent         = "true";
  #   };
  # };

  # services.sysdiag-cleanup = {
  #   enable = true;
  #   retentionDays = 14;
  #   retentionCount = 20;
  # };


  services.journald = {
    extraConfig = ''
      Storage=persistent
      SystemMaxUse=2G
      RuntimeMaxUse=1G
      RateLimitIntervalSec=0
      RateLimitBurst=0
      MaxLevelStore=debug
      MaxLevelSyslog=debug
      MaxLevelKMsg=debug
      MaxLevelConsole=debug
    '';
  };

  boot.kernel.sysctl = {
    "kernel.printk" = "7 7 7 7"; # Maximum verbosity for dmesg
  };

  services.rsyslogd = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    enable = true;
    extraConfig = ''
      kern.* /var/log/kern.log
      *.debug /var/log/debug.log
    '';
  };

  # This is all you actually need; just this - and.. that, and...
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      randomizedDelaySec = "2h";
      persistent = true;
      options = "--delete-older-than 30d";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
        "cgroups"
      ];
      extra-experimental-features = [ "ca-derivations" ];
      auto-allocate-uids = true;
      max-jobs = lib.mkDefault "auto";
      cores = lib.mkDefault 0;
      auto-optimise-store = true;
      builders-use-substitutes = true;

      trusted-substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };
  # AllowUsers is now per-user in each user module (build.nix, deployment.nix, inspect.nix)
  # sshd.nix manages John88. NixOS module system merges all entries.

  # Fleet-wide default: keep 5 system configuration generations in boot menu.
  # Individual machines can override (LINDA sets this to 1 for space-constrained NVMe).
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 5;

  services.kmscon = {
    #  Alright, I know what you are thinking; For real? All I have to do is grab a John-tech and enter tty?
    #      Alright, so what? you have the damn thing in your hand anyway; I saved you what? Six hours to DD my disk
    #        and fuck about in a terminal?
    #      Compared to the 30,000+ hours to brute force some key? Doesn't matter.
    #    P.S. Thx to crash giving me wiregaurd, I look forward to your pinging my IPV4 range :)
    enable = true;
    hwRender = true; # Enable hardware rendering
    # extraConfig = ''
    # font-size=16
    #xterm-resolution=1920x1080 # Set desired resolution
    # font-name=Source Code Pro # Clear, monospaced font
    # font-size=14 # Balanced size for readability
    # palette=linux # Standard Linux console colors
    # #scrollback=1000 # Scrollback buffer size
    # drm # Use DRM backend for Raspberry Pi
    # '';
    #   fonts = [
    #     {
    #       name = "Source Code Pro";
    #       package = pkgs.source-code-pro;
    #     }
    #   ];
  };
  # Required for kmscon hwaccel (unstable nixpkgs assertion)
  hardware.graphics.enable = lib.mkDefault true;
  services.getty.autologinUser = "John88";

  # FlakeHub token for Determinate Nix — silences "Permanent" auth errors.
  # Secrix decrypts the token at /run/determinate-flakehub-login-keys/flakehub-token,
  # then this service runs `determinate-nixd login token --token-file` which writes
  # the netrc with correct entries for flakehub.com, api.flakehub.com, cache.flakehub.com.
  # Runs after nix-daemon so the socket is ready. Token exists only for service lifetime.
  # Does NOT touch /run/gitlab-netrc — completely separate concern.
  secrix.services.determinate-flakehub-login.secrets.flakehub-token.encrypted.file =
    "${self}/secrets/flakehub_token";

  systemd.services.determinate-flakehub-login =
    let
      determinate-nixd = self.inputs.determinate.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      description = "Login to FlakeHub via Determinate Nix daemon";
      after = [ "nix-daemon.service" ];
      requires = [ "nix-daemon.service" ];
      # secrix module adds: after/bindsTo determinate-flakehub-login-keys.service
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.getExe' determinate-nixd "determinate-nixd"} login token \
          --token-file /run/determinate-flakehub-login-keys/flakehub-token
      '';
    };
}
