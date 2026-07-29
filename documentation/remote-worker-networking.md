# Remote-Worker Network Configuration

## IP Addressing

| Interface | IP | Purpose |
|---|---|---|
| `ens3` | `10.0.1.42/26` | WAN (actual interface) |
| `wireg0` | `10.88.127.50/32` | WireGuard |
| `lo` | `127.0.0.1` | Loopback |

## NAT Mapping

The public IP `193.16.42.101` is **not assigned** to any interface on remote-worker.
It is NAT-forwarded to `10.0.1.42` (ens3) by the upstream provider.

**Nginx must bind to `10.0.1.42`, not `193.16.42.101`.**
Binding to the public IP fails with `Cannot assign requested address` (errno 99)
and crashes the entire nginx service — taking down all vhosts including WireGuard.

All nginx listen addresses use the internal WAN IP `10.0.1.42` with a comment
noting the external NAT mapping.

## Split-Horizon DNS

`johnbargman.com` uses split-horizon via cortex-alpha DNS:

- **Internal (LAN/WG)**: resolves to `10.88.127.50` (remote-worker WG) → staging site
- **External**: resolves via public DNS to `193.16.42.101` → NAT → `10.0.1.42` → release site

DNS entry defined in `topology/cortex-alpha.nix` under `dns.static`.

## Nginx VHosts

| VHost | Listen Addresses | Source |
|---|---|---|
| `default` (fallthrough) | `0.0.0.0` | `default.nix` |
| `johnbargman.net` | `10.0.1.42`, `10.88.127.50` | `default.nix` |
| `johnbargman.com` (release) | `10.0.1.42` | `default.nix` |
| `johnbargman.com-lan` (staging) | `10.88.127.50` | `default.nix` |
| `csfinancialconsulting.com` | `10.0.1.42` | `flake.nix` |
| `csfincon.us` | `10.0.1.42` | `flake.nix` |
| `nextcloud.johnbargman.net` | `10.0.1.42`, `10.88.127.50` | `nextcloud.nix` |
| `nextcloud.johnbargman.com` | `10.0.1.42`, `10.88.127.50` | `nextcloud.nix` |
