# Aether moa_type registry fix for all-the-mons 1.0.0-rc.6
#
# The Aether mod (1.21.1-1.5.10-neoforge) ships aether:blue moa_type
# with egg.id = minecraft:air, which fails registry serialization on
# every player join, blocking connections for 2-10 minutes.
#
# This patch creates a data pack that overrides all three moa types
# with correct egg.id values.
#
# *** MUST BE REVALIDATED when updating past rc.6 ***

{ lib, version }:

let
  # Force evaluation error if version changes — caller must revalidate this patch
  _versionCheck =
    assert lib.assertMsg (version == "1.0.0-rc.6")
      "rc6-moa-patch: expected modpack version '1.0.0-rc.6', got '${version}'. This patch must be revalidated for the new version.";
    true;
in
assert _versionCheck;
''
  mkdir -p ''$out/datapacks/aether-moa-fix/data/aether/aether/moa_type
  printf '%s\n' '{"pack":{"pack_format":48,"description":"Fix Aether moa_type air item bug"}}' > ''$out/datapacks/aether-moa-fix/pack.mcmeta
  printf '%s\n' '{"egg":{"id":"aether:blue_moa_egg"},"max_jumps":3,"moa_texture":"aether:textures/entity/mobs/moa/blue_moa.png","saddle_texture":"aether:textures/entity/mobs/moa/moa_saddle.png","spawn_chance":100,"speed":0.155}' > ''$out/datapacks/aether-moa-fix/data/aether/aether/moa_type/blue.json
  printf '%s\n' '{"egg":{"id":"aether:black_moa_egg"},"max_jumps":8,"moa_texture":"aether:textures/entity/mobs/moa/black_moa.png","saddle_texture":"aether:textures/entity/mobs/moa/black_moa_saddle.png","spawn_chance":25,"speed":0.155}' > ''$out/datapacks/aether-moa-fix/data/aether/aether/moa_type/black.json
  printf '%s\n' '{"egg":{"id":"aether:white_moa_egg"},"max_jumps":4,"moa_texture":"aether:textures/entity/mobs/moa/white_moa.png","saddle_texture":"aether:textures/entity/mobs/moa/moa_saddle.png","spawn_chance":50,"speed":0.155}' > ''$out/datapacks/aether-moa-fix/data/aether/aether/moa_type/white.json
''
