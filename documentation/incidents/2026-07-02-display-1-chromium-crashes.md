# Incident: Chromium renderer crashes on display-1

**Date**: 2026-07-02
**Machine**: display-1
**Architecture**: aarch64
**Chromium version**: 142.0.7444.175

## Summary

Two chromium renderer process crashes within 3 minutes. Both signal SIGTRAP.
User: John88 (UID 1108). Core files captured and later rotated out.

## Crash 1 — OOM in GPU shared image allocation

- **PID**: 147013
- **Timestamp**: 2026-07-02 03:55:35 UTC
- **Core file size**: 83.8M
- **Stack (thread 7, crashing)**:
  ```
  partition_alloc::internal::OnNoMemoryInternal
  partition_alloc::TerminateBecauseOutOfMemory
  gpu::SharedImageInterface::CreateSharedMemoryRegionFromSIInfo
  gpu::ClientSharedImageInterface::CreateSharedImageForSoftwareCompositor
  cc::ResourcePool::InUsePoolResource::InstallSoftwareBacking
  cc::ZeroCopyRasterBufferProvider::AcquireBufferForRaster
  cc::TileManager::AssignGpuMemoryToTiles
  cc::TileManager::PrepareTiles
  cc::LayerTreeHostImpl::UpdateSyncTreeAfterCommitOrImplSideInvalidation
  ```
- **Root cause**: Out of memory in the GPU compositor's shared memory allocation path.
  Chromium renderer attempted to allocate GPU shared memory for software compositing
  tiles during `AssignGpuMemoryToTiles` and hit `partition_alloc` OOM termination.

## Crash 2 — btoa() in JavaScript

- **PID**: 166385
- **Timestamp**: 2026-07-02 03:58:59 UTC
- **Core file size**: 41.4M
- **Stack (thread 1, crashing)**:
  ```
  __memcpy_generic (libc)
  blink::String::Latin1
  blink::UniversalGlobalScope::btoa
  blink::v8_window::BtoaOperationCallback
  Builtins_CallApiCallbackGeneric (V8)
  Builtins_InterpreterEntryTrampoline (V8)
  Builtins_PromiseFulfillReactionJob (V8)
  Builtins_RunMicrotasks (V8)
  Builtins_JSRunMicrotasksEntry (V8)
  ```
- **Root cause**: Crash during `window.btoa()` JavaScript call. The `Latin1` conversion
  triggered a `__memcpy_generic` that hit SIGTRAP. Likely a web page passing
  non-Latin1 data to btoa causing a bounds violation or memory corruption.
  Page content unknown.

## Resolution

Both crashes occurred in isolated renderer processes. No service disruption
to the browser session. Stale `systemd-coredump@*` transient units reset.

## Stale coredump units

12 `systemd-coredump@*` transient units remained in failed state from these and
older mold (Nov 2025) crashes. All core files already rotated/cleaned. Units reset.
