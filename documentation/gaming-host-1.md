# Gaming Host 1 — Machine Documentation

**Hostname:** gaming-host-1
**Role:** Game server host
**Last updated:** 2026-10-05

## Current Status

**All game servers DISABLED** (2026-10-05). Configuration preserved below for reference.

## Hardware

- **Platform:** x86_64-linux
- **CPU:** AMD (kvm-amd enabled)
- **Storage:** NVMe (nvme0n1), ext4 root
- **Swap:** UUID 8e2cc7a4-6d8b-47b8-988b-3790a8065318

## Network

- **Public IP:** 65.108.141.32
- **WireGuard:** Peer ID 52, subnet 10.88.127.0/24, trust level 3
- **Domain:** gaming-host-1.johnbargman.net
- **ACME:** Enabled (Let's Encrypt)

## Game Servers (DISABLED — 2026-10-05)

### 1. Minecraft (all-the-mons)

**Status:** DISABLED (was: enabled)

```nix
services.minecraft-curseforge.all-the-mons = {
  enable = true; # re-enabled 2026-06-06
  pack = pkgs.minecraft-curseforge-all-the-mons;
  acceptEula = true;
  maxMemory = "8G";
  minMemory = "4G";
  gamePort = 25565;
  rconPort = 25575;
  rconPassword = "allthemons"; # Plaintext by design — game RCON, not an infrastructure secret
  openFirewall = true;

  # squaremap web map viewer
  enableSquaremap = true;
  squaremapPort = 8080;
  openSquaremapFirewall = true; # accessible on all interfaces (WireGuard + public)
  ops = [
    { uuid = "a02323f6-eaf1-44d2-8d37-d260c914cb00"; name = "John88"; level = 4; bypassesPlayerLimit = true; }
    { uuid = "d23e3eb2-954b-4544-ad3d-982f0ef495aa"; name = "boxfox"; level = 4; bypassesPlayerLimit = true; }
  ];
  serverProperties = {
    "allow-flight" = true;
    "motd" = "in the waters of nurse joy a hero blooms";
    "max-tick-time" = 180000;
    "simulation-distance" = 8;
    "view-distance" = 20;
    "max-players" = 8;
    "difficulty" = "normal";
    "gamemode" = "survival";
    "level-seed" = "4240772663413292738";
  };
};
```

**Scheduled restart:** Every 2 days at 5:00 AM
```nix
systemd.timers.minecraft-restart = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "*-*-01/2 05:00:00";
    Persistent = true;
    RandomizedDelaySec = 0;
  };
};
systemd.services.minecraft-restart = {
  description = "Scheduled restart for all-the-mons";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} restart mc-curseforge-all-the-mons.service";
  };
};
```

### 2. DragonWilds

**Status:** DISABLED (was: enabled)

```nix
services.dragonwilds-server.enable = true;
```

### 3. Windrose

**Status:** DISABLED (was: enabled)

```nix
services.windrose-docker = {
  enable = true;
  serverName = "Fox and Wolf";
  serverNote = "Co-op adventures await - join the pack!";
  openFirewall = true;
};
```

### 4. TerraTech Worlds

**Status:** DISABLED (was: enabled)

```nix
services.terratech-worlds-server = {
  enable = true;
  uid = 29987;
  gid = 29987;
  password = "godlet"; # Plaintext by design — game server password, not a security credential
  openFirewall = true;
  map = "Phaeton";
};
```

**Ports:** 7777 (primary), 7778 (compatibility fallback)

### 5. Space Engineers

**Status:** DISABLED (was: disabled — port 8080 conflict with squaremap)

```nix
services.space-engineers-docker = {
  enable = false; # disabled — port 8080 conflict with squaremap
  instanceName = "KJTNewWorld";
  worldName = "Star System";
  #    gameMode = "SURVIVAL";
  publicIP = "65.108.141.32";
  openFirewall = true;
};
```

## Backup Configuration

**Source of truth:** `topology/gaming-host-1.json` (`backup` keys) — if this
section and the topology JSON disagree, the JSON wins.

**Target:** `game-backups`
**Source:** `/bulk-storage/backups/` (consolidated backup directory — the
per-game paths were consolidated 2026-10-04 when game servers were disabled)
**Remote:** `minio:minecraft-backups`
**User:** `deploy`
**Schedule:** Daily at 6:00 AM
**Mode:** copy
**Bandwidth limit:** 10M
**Retention:** Delete `.tar.gz` and `.tar.zst` files older than 14 days

```json
{
  "backup": {
    "configFile": "../secrets/rclone-config-file",
    "user": "deploy",
    "targets": {
      "game-backups": {
        "filePath": "/bulk-storage/backups/",
        "remoteName": "minio:minecraft-backups",
        "calendar": "*-*-* 06:00:00",
        "mode": "copy",
        "bwlimit": "10M",
        "preExec": "find /bulk-storage/backups/ -name '*.tar.gz' -mtime +14 -delete && find /bulk-storage/backups/ -name '*.tar.zst' -mtime +14 -delete"
      }
    }
  }
}
```

**Note:** MinIO retains ALL historical backups (no lifecycle policy). Source has 8 files (163GB), MinIO has 46 files (743GB). Consider adding MinIO bucket lifecycle policy to expire old backups.

## Nginx Configuration

**Status:** Enabled (topology-derived)

```nix
services.nginx = {
  recommendedProxySettings = true;
  recommendedTlsSettings = true;
  # enable and virtualHosts come from mktopology/genNginx (topology JSON)
};
```

**Firewall:** TCP 80, 443 open

## Re-enabling Game Servers

To re-enable any game server, uncomment the corresponding block in `machines/gaming-host-1/default.nix` and rebuild.

**Important:** After re-enabling, regenerate the golden:
```bash
nix run .#dump-config -- gaming-host-1 | jq -S . > goldens/gaming-host-1.json
```

## References

- **Topology:** `topology/gaming-host-1.json`
- **Config:** `machines/gaming-host-1/default.nix`
- **Hardware:** `machines/gaming-host-1/hardware-configuration.nix`
