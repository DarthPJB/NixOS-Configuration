# Squaremap Render Failure Analysis — 2026-06-13

**Machine:** gaming-host-1 (`mc-curseforge-all-the-mons`)
**Analysis window:** 2026-06-13 00:59–01:44 UTC (45 min journal snapshot)

---

## Summary

Squaremap rendering is producing widespread unrendered regions due to a
**FramedBlocks NPE** that crashes entire chunk column renders. Within a
5-minute radius render window, **459 chunk column failures** were logged
across 5 distinct Z-bands, creating horizontal unrendered stripes in the
map. The factory base at `x=548, z=-2480` (chunk `[34, -155]`) lies near
one of these bands.

---

## Root Cause

```
java.lang.NullPointerException: Cannot invoke
  "net.minecraft.world.level.BlockGetter.getBlockEntity(
    net.minecraft.core.BlockPos)" because "level" is null

at xfacthd.framedblocks.api.block.IFramedBlock.getMapColor(
  IFramedBlock.java:603)
  ↓
at squaremap/1.3.2/.../MapWorldInternal.getMapColor(
  MapWorldInternal.java:147)
  ↓
at squaremap/.../AbstractRender.iterateDown(
  AbstractRender.java:438)
  ↓
at squaremap/.../AbstractRender.getLastYFromBottomRow(
  AbstractRender.java:364)
  ↓
at squaremap/.../AbstractRender.mapSingleChunk(
  AbstractRender.java:254)
```

**What happens:**
1. Squaremap calls `getMapColor()` on a block to determine its tile color.
2. FramedBlocks' `IFramedBlock.getMapColor()` mixin intercepts this and
   calls `level.getBlockEntity(pos)`.
3. During background/render rendering, `level` (BlockGetter) is `null` —
   a condition FramedBlocks does not handle.
4. The NPE propagates up through `mapSingleChunk`, crashing the entire
   chunk column render.
5. Squaremap logs the error as a WARN and **skips the chunk column**,
   leaving an unrenderable hole.

---

## Error Distribution — 5 Horizontal Bands

```
  Z-chunk | Block Z  | X-column range      | # Failing X columns
  --------|----------|---------------------|---------------------
    160   |   +2560  |   83 to   92        |  10
     96   |   +1536  |  -108 to 211       |  61  ← largest
      0   |       0  |   -89 to 221       |  21
    -96   |   -1536  |  -101 to 223       |  23
   -128   |   -2048  |  -113 to 223       |  22
```

The factory at `chunk [34, -155]` is 27 chunks (432 blocks) south of
the Z=-128 error band. While no errors were logged directly at the
factory area in the 45-minute window, the adjacent Z=-128 band creates
a horizontal unrendered stripe that may visually connect or overlap the
factory region depending on the map zoom level.

**Pattern:** errors cluster at fixed Z-values spanning wide X-ranges.
Each failing column is a vertical strip from bedrock to build height
that squaremap cannot render. Re-renders retry and re-fail indefinitely
(confirmed: the same chunks repeatedly fail).

---

## Timeline

| Time (UTC) | Event |
|---|---|
| 00:59:38 | First NPE logged (single-chunk bg-render from event listeners) |
| 01:04:12 | Server **restart** (left-over Java process detected — unclean shutdown) |
| 01:05:29 | MC server loads world |
| 01:09:52 | 1st radius render starts & **finishes instantly** (empty/trivial radius) |
| 01:39:18 | 2nd **radius render** started |
| 01:39:19 | **First column failures** logged — render worker threads immediately start hitting the FramedBlocks NPE |
| 01:43:18 | Errors continue on new bands (e.g., Z=160) |
| 01:44:23 | Render at **14.3%** (131/904 regions), ETA ~24 min |

The 2nd radius render produced 459 errors in under 6 minutes — averaging
~77 failures/minute across 6 render worker threads.

---

## Why the Existing Mitigation Fails

The `advanced.yml` (`server_services/game_servers/minecraft-curseforge.nix:51`)
currently lists ~40 individual FramedBlocks block IDs as `invisible-blocks`:

```yaml
invisible-blocks:
  - framedblocks:framed_block
  - framedblocks:framed_half_block
  ...
```

This does **not** prevent the crash because:

1. The crash originates from `IFramedBlock.getMapColor()` — the
   **interface** that ALL FramedBlocks implement, via a mixin into
   `BlockStateBase.getMapColor()`.
2. The `invisible-blocks` list skips rendering for those specific block
   types, but the mixin fires on `getMapColor()` *before* squaremap can
   check the invisible list.
3. Even blocks NOT made of FramedBlocks can trigger the crash if the
   FramedBlocks mixin intercepts the wrong call path with a null level.

---

## Impact

- **Map integrity:** 459+ chunk columns permanently unrenderable at 5 Z-bands
- **Resource waste:** Render worker threads spin on reprocessing
  failing chunks every cycle, wasting CPU (10.4G RAM, 191 tasks)
- **Unclean shutdowns:** Left-over Java processes on restart suggest
  the server was kill -9'd, potentially corrupting world/tile state
- **Player experience:** Factory map area at `?x=548&z=-2480` shows
  unrendered vertical gaps

---

## Recommended Actions

### Immediate (does not require config changes)
1. **Cancel the broken render** via RCON:
   ```
   map cancelrender minecraft:overworld
   ```
2. Once FramedBlocks issue is addressed, restart with a focused
   `radiusrender` targeting the factory area.

### Short-term config fix
Add **all** FramedBlocks block IDs to `invisible-blocks` — not just the
common shapes. The current ~40 entries miss many. Consider running a
script to enumerate all `framedblocks:*` block IDs from the mod's
registry and auto-populate the invisible list.

Alternatively, consider removing FramedBlocks from the modpack if it
cannot coexist with squaremap.

### Longer-term
1. **Upgrade squaremap** — v1.3.2 is used; check if newer versions
   handle NPE from modded blocks more gracefully (swallow and skip
   rather than crash the column).
2. **Report upstream** — The FramedBlocks `getMapColor()` should
   null-check `level` before calling `getBlockEntity()`. This is a
   FramedBlocks bug, not a squaremap bug.
3. **Add render thread resilience** — If squaremap or a compatibility
   addon can catch `CompletionException` at the column level and
   continue to the next column without logging the full stack trace
   every cycle, this would reduce log spam and CPU waste.
