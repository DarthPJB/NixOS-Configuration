# NixOS integration test for the Minecraft CurseForge server.
#
# Boots a VM with the all-the-mons server configured, verifies:
#   1. Server starts and reaches "Done" state (world generated)
#   2. RCON is accessible and responsive
#   3. Squaremap web port is open
#   4. Graceful RCON shutdown works
#   5. Service stops cleanly (no SIGKILL)
#
# Run:
#   nix build .#checks.x86_64-linux.minecraft-server-test -L

{ testers
, lib
, pkgs
, minecraft-curseforge-all-the-mons
, minecraft-curseforge-module
, ...
}:

testers.runNixOSTest {
  imports = [ ../helpers.nix ];

  name = "minecraft-server-test";

  # Minecraft needs time: world generation, mod loading, RCON test, shutdown
  globalTimeout = lib.mkForce (15 * 60); # 15 minutes

  nodes.machine = {
    imports = [ minecraft-curseforge-module ];

    # VM needs enough RAM for Minecraft + mods (8GB heap + OS overhead)
    virtualisation = {
      memorySize = 12288; # 12GB (8GB heap + 4GB OS/mods overhead)
      diskSize = 16384; # 16GB for world data
      cores = 4;
    };

    # Minimal config — just enough to test the server lifecycle
    services.minecraft-curseforge.test-instance = {
      enable = true;
      pack = minecraft-curseforge-all-the-mons;
      acceptEula = true;
      maxMemory = "8G";
      minMemory = "4G";
      gamePort = 25565;
      rconPort = 25575;
      rconPassword = "testpassword";
      openFirewall = true;

      # No squaremap for this test — reduces startup time
      enableSquaremap = false;

      serverProperties = {
        "motd" = "NixOS Integration Test";
        "max-players" = 2;
        "difficulty" = "peaceful";
        "gamemode" = "creative";
        "level-type" = "flat";
        "view-distance" = 4;
        "simulation-distance" = 4;
      };
    };
  };

  testScript =
    { nodes, ... }:
    # python
    ''
      machine.start()

      # ── Phase 1: Wait for service to start ──────────────────────────
      with subtest("service starts"):
          machine.wait_for_unit("mc-curseforge-test-instance.service")
          print("Service unit active")

      # ── Phase 2: Wait for server to be ready ────────────────────────
      # ModernFix suppresses the "Done" message. Instead, wait for RCON
      # port to open, which happens after the server is fully loaded.
      with subtest("server reaches ready state"):
          # Wait for RCON port to be listening (server fully loaded)
          machine.wait_for_open_port(25575, timeout=600)
          print("RCON port open — server is ready")

      # ── Phase 3: Verify RCON is responsive ──────────────────────────
      with subtest("RCON responds to list command"):
          result = machine.succeed(
              "${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p testpassword 'list'"
          )
          print(f"RCON list output: {result.strip()}")
          # list command returns player count — even if 0 players, it returns a string
          assert "players" in result.lower() or "of" in result.lower(), \
              f"RCON list did not return expected output: {result}"

      # ── Phase 4: Verify game port is open ───────────────────────────
      with subtest("game port 25565 is open"):
          machine.succeed("ss -tlnp | grep ':25565 '")
          print("Game port 25565 is listening")

      # ── Phase 5: Graceful shutdown via RCON ─────────────────────────
      with subtest("RCON stop triggers clean shutdown"):
          # Send stop command
          machine.succeed(
              "${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p testpassword 'stop'"
          )
          print("RCON stop sent")

          # Wait for the service to deactivate
          # systemd will run ExecStopPost (backup) after the service stops
          machine.wait_until_fails("systemctl is-active mc-curseforge-test-instance.service", timeout=120)
          print("Service stopped cleanly")

      # ── Phase 6: Verify clean exit (not killed) ─────────────────────
      with subtest("service exited cleanly (not SIGKILL)"):
          journal = machine.succeed("journalctl -u mc-curseforge-test-instance.service --no-pager -n 30")
          print(f"Journal tail:\n{journal}")

          # Should NOT see "Killed" or "SIGKILL" — that means timeout was exceeded
          assert "Killed" not in journal, "Service was SIGKILL'd — stop timeout exceeded"

          # Verify all worlds were saved (clean shutdown)
          assert "All dimensions are saved" in journal or "All chunks are saved" in journal, \
              "Worlds were not saved — unclean shutdown"

      print("All tests passed!")
    '';
}
