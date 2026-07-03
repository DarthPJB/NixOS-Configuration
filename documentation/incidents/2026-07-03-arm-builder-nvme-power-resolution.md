# Incident Resolution: arm-builder NVMe Disconnect — Power Delivery Fix

> **Date:** 2026-07-03
> **Status:** Resolved
> **Root cause:** Insufficient power delivery to NVMe enclosure under sustained write load
> **Fix:** Separate 5A USB-C power supplies for Pi and DockCase

## Problem

The WD SN750 NVMe in a DockCase DSWC1P USB enclosure disconnected from the USB bus
under sustained write load during CI kernel builds. This caused:
- EXT4 journal abort and filesystem corruption
- nix-daemon crash
- CI build failures (print-controller, display-1)

## Root Cause

The Pi 4's official 3A power supply was insufficient for sustained NVMe writes.
Peak power draw during kernel builds was ~4.3-4.8A (Pi 4 + VL805 + DockCase + SN750).

The voltage sag caused the DockCase's USB link to degrade and eventually drop. The
failure was gradual — SCSI commands stalled for minutes before the USB device reset
and disconnected.

## Solution

Two separate 5A USB-C chargers:
1. One for the Pi 4 (dedicated power)
2. One for the DockCase DSWC1P (dedicated power)

This eliminates the shared 5V rail bottleneck. The Pi's USB controller still handles
the data connection, but power delivery is independent.

## Verification

Test build of `dbus-1` for display-2 completed successfully:
- Pre-build: Load 0.22, Memory 3.4GB available
- Post-build: Load 4.21 (all 4 cores), Memory stable
- Zero `device offline` errors
- Zero USB reset events

## Monitoring

Deployed Prometheus + Grafana monitoring:
- `node_exporter` on port 9100 (system metrics)
- `smartctl_exporter` on port 3107 (SMART — unavailable through DockCase bridge)
- Shared module: `environments/metrics.nix`
- Scraped by local-nas prometheus at `10.88.127.3:8080`

## Related Documents

- `documentation/incidents/2026-07-03-arm-builder-nvme-ci-disconnect.md` — CI failure analysis
- `documentation/incidents/2026-07-03-arm-builder-nvme-failure.md` — initial incident
- `documentation/plans/arm-builder-usb-nvme-reliability-2026-07-03.md` — reliability action plan
- `documentation/research/rpi4-usb-nvme-kernel-tuning.md` — kernel tuning research
- `documentation/research/rpi4-usb-nvme-firmware-research.md` — firmware research
- `documentation/research/prometheus-metrics-scraping.md` — monitoring reference
- `environments/metrics.nix` — shared metrics module
