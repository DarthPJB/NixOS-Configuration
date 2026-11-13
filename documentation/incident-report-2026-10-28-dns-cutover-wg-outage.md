# Incident Report — WireGuard outage caused by Gandi → Porkbun DNS cutover

**Date:** 2026-10-28
**Status:** Mitigation in progress — `cortex-alpha` A record restored; awaiting DNS
propagation and peer tunnel re-establishment
**Severity:** High (fleet-wide WireGuard outage; in-house binary cache unusable on LAN)
**Author:** Diagnostics from LINDA + cortex-alpha (read-only), 2026-10-28
**Related:** `documentation/dns-cutover-inventory-2026-10-28.md`

## Summary

The transfer of `johnbargman.net` / `johnbargman.com` from Gandi to Porkbun completed
registry delegation before the zone data had been fully replicated. `cortex-alpha.johnbargman.net`
was among the records absent from the new Porkbun zone. WireGuard clients resolve the
hub endpoint by hostname (`cortex-alpha.johnbargman.net:2108`), so when public resolvers
stopped answering the name — as Gandi's cached answers expired and resolvers flipped to
the empty Porkbun zone — **every WireGuard peer dependent on public DNS lost its endpoint
and the tunnels dropped.**

This was not a WireGuard fault, not a topology fault, and not a machine-configuration
fault. It was a DNS cutback: the hub's reachability hinged on one A record that the
cutover left behind.

## Impact

- **WireGuard:** all peers relying on public resolution of `cortex-alpha.johnbargman.net`
  dropped (remote-builder / 10.88.127.51 confirmed still down at time of writing).
  LAN-resident peers were largely insulated because cortex-alpha's dnsmasq carries a
  split-horizon static entry `cortex-alpha.johnbargman.net → 10.88.128.1`, which masked
  the public outage from on-LAN hosts.
- **In-house binary cache:** LAN consumers resolve `cache.johnbargman.net → 10.88.128.1`
  (cortex-alpha nginx vhost proxying to `10.88.127.51:5001` = remote-builder over WG).
  With the WG tunnel down, that upstream is dead: requests from LINDA hang and return
  `http_code=000` after ~12 s. The public path (`cache.johnbargman.net → 193.16.42.13`,
  TLS on remote-builder itself) remained **healthy throughout** (HTTP 200, valid
  `nix-cache-info`).
- **Fleet builds** using `trusted-substituters = https://cache.johnbargman.net`
  (`/etc/nix/nix.custom.conf`, flake-level `nixConfig`) stall against the dead LAN path.
- **Secondary degradation:** for any *non-static* `johnbargman.net` name, the gateway's
  dnsmasq currently returns SERVFAIL, because its first-priority forwarders
  (208.67.220.220 / 208.67.222.222, OpenDNS) fail DNSSEC validation on the zone during
  transition (`EDE: 9 (DNSKEY Missing)`; answers return correctly with `+cd`). dnsmasq
  relays the SERVFAIL instead of falling through to 1.0.0.1 / 8.8.8.8.

## Root cause

**Primary cause: the Gandi → Porkbun cutover left `cortex-alpha.johnbargman.net`
unresolvable in public DNS, and the WireGuard hub endpoint is specified as that
hostname.**

Mechanism chain:

1. Zone transfer: registry delegation moved to Porkbun (`curitiba`, `fortaleza`,
   `maceio`, `salvador.ns.porkbun.com`) while the Porkbun zone contained only a
   skeleton (apex A + `nextcloud` A per zone, two `.com` TXT). 17 data records on
   `.net` were missing — including `cortex-alpha A 82.5.173.252`
   (`dns-cutover-inventory-2026-10-28.md`, "Missing at Porkbun" table).
2. WireGuard clients configure exactly one endpoint, by name:
   `endpoint = "${hubHostname}.${domain}:${listenPort}"` → `cortex-alpha.johnbargman.net:2108`
   (`modules/enable-wg-topology.nix:93`). There is no IP fallback and no re-resolve
   retry loop; resolution happens when the tunnel/peer unit is set up.
3. As resolvers' Gandi caches expired (up to 48 h per the cutover inventory, in
   practice much sooner for low-TTL names — `cortex-alpha` carried TTL 500), they
   began answering from Porkbun: **NXDOMAIN** for `cortex-alpha.johnbargman.net`.
4. Endpoint resolution failed → handshake impossible → **WireGuard peers dropped.**
5. Cascade: remote-builder's WG address (10.88.127.51) became unreachable from both
   LINDA and cortex-alpha (100 % ping loss; TCP :80/:443/:5001 timeout) → cortex-alpha's
   `cache.johnbargman.net` vhost (proxy_pass `http://10.88.127.51:5001`) had a dead
   upstream → LAN cache consumers hung.

**Why it looked like a cache/DNS-override problem initially:** on LINDA,
`cache.johnbargman.net` resolves to `10.88.128.1` via the gateway's dnsmasq split-horizon
static entry (`topology/cortex-alpha.json` → `genDns` → `address=/cache.johnbargman.net/10.88.128.1`),
while public DNS returns `193.16.42.13`. That split-horizon design is intentional and is
**not** the outage cause — it merely redirected attention. The dead symptom (cache
timeouts) sat one layer above the actual fault (WG endpoint resolution).

## Timeline (2026-10-28, UTC)

| Time | Event |
|---|---|
| ≤ 09:34 | Delegation to Porkbun already live; Porkbun zone skeleton only. Cutover inventory captured. `cortex-alpha`, `cache`, `remote-builder`, `remote-worker`, `gaming-host-1`, `storage-array`, mail records all **missing** from Porkbun. |
| ~09:34–10:00 | Resolver caches expire; public lookups flip to the empty Porkbun zone. `cortex-alpha.johnbargman.net` becomes unresolvable → WG peers drop (exact drop time inferred — see Evidence). `cache.johnbargman.net` already present again at public resolvers by 10:00. |
| 10:00–10:30 | Read-only diagnostics on LINDA and `ssh cortex-alpha -p 1108`: dnsmasq static override confirmed live; hub nginx cache vhost → `10.88.127.51:5001` confirmed; WG peer `PKqZ/2sXuNWX2VCYmVDc/JIxfNyyZKH3sfJwzZMKC0g=` (10.88.127.51) configured with allowed-ips only, no endpoint (hub is passive — clients dial in); 10.88.127.51 unreachable from LINDA and hub; public cache path HTTP 200; OpenDNS SERVFAIL `EDE: 9 (DNSKEY Missing)`; SOA serial disagreement between Gandi-era (1793170734) and Porkbun (2418665935) views. |
| by ~10:40 | **`cortex-alpha A 82.5.173.252` restored** (verified at 8.8.8.8, 1.1.1.1, curitiba.ns.porkbun.com, and ns-85-a.gandi.net). Awaiting propagation and peer reconnection. |
| At time of writing | Still missing at Porkbun: `remote-builder` A, `remote-worker` A, `storage-array` A, `carmel-staging` A, both zones' MX/SPF, `www`/`webmail` CNAMEs, SRV records. remote-builder WG tunnel still down (endpoint re-resolution needed). |

## Resolution & recovery state

Done:
- `cortex-alpha` A record restored to `82.5.173.252` at Porkbun (the DDNS-managed dynamic
  home IP; DDNS service `services/dynamic_domain_porkbun.nix` manages
  `<hostname>.johnbargman.net` records on its next run).

Remaining / pending:
1. **Wait for propagation** of `cortex-alpha.johnbargman.net` to all resolver paths.
2. **Re-establish WG tunnels.** Endpoint hostnames are resolved at interface/peer setup;
   peers that dropped will not self-heal merely because DNS is back. Restart
   `wireguard-wireg0` (or the per-peer units) on affected hosts — remote-builder first
   (10.88.127.51). Verify with `ping 10.88.127.51` from LINDA/cortex-alpha and
   `wg show latest-handshakes` on the hub.
3. **Verify the cache:** `dig cache.johnbargman.net +short` → `193.16.42.13` from LAN;
   `curl https://cache.johnbargman.net/nix-cache-info` via the LAN path (through the
   gateway vhost) → 200 once the tunnel is back.
4. **Restore the remaining missing records** per the cutover inventory — especially MX
   (mail is broken for already-switched resolvers) and the DDNS-managed A records.

## Evidence

- `modules/enable-wg-topology.nix:93` — `endpoint = "${hubHostname}.${domain}:${toString listenPort}"`
  (the single point of dependence on public DNS).
- `documentation/dns-cutover-inventory-2026-10-28.md` — `cortex-alpha A 82.5.173.252`
  listed under "Missing at Porkbun"; note #3: DDNS will recreate hostname records on its
  next run; delegation table shows resolvers mid-flip at capture time.
- Live diagnostics (LINDA): `10.88.127.1/.3/.43/.107` ping UP, `10.88.127.51` ping DOWN;
  `curl --resolve cache.johnbargman.net:443:193.16.42.13 …` → `HTTP/2 200` +
  `StoreDir: /nix/store`; same via default resolver → hang, `http_code=000`.
- Live diagnostics (cortex-alpha): generated dnsmasq conf contains
  `address=/cache.johnbargman.net/10.88.128.1` (matches golden — runtime is not drifted);
  nginx `server_name cache.johnbargman.net` → `proxy_pass http://10.88.127.51:5001`;
  WG peer start script sets only `allowed-ips 10.88.127.51/32` (passive hub, no endpoint);
  `wg` UDP listen on `0.0.0.0:2108`.
- DNSSEC transition artifact: `dig @208.67.220.220 cache.johnbargman.net` → SERVFAIL
  `EDE: 9 (DNSKEY Missing)`; `+cd` → correct answer; `@1.0.0.1`/`@8.8.8.8` →
  `193.16.42.13` with `ad` flag.

## Action items

| # | Item | Owner | Priority |
|---|---|---|---|
| 1 | Finish cutover record restoration (MX/SPF/SRV/CNAME + remaining A records) per inventory | ops | P0 |
| 2 | Restart WG on remote-builder and any remaining down peers; verify handshakes fleetwide | ops | P0 |
| 3 | Cutover checklist: never switch delegation before zone parity is verified record-by-record (the inventory doc is the template) | process | P1 |
| 4 | Consider making the WG hub endpoint independent of the public zone under transition (e.g. secondary name on a stable zone, or DDNS-first ordering before delegation flips) | design | P1 |
| 5 | Reorder/drop OpenDNS forwarders in `topology/cortex-alpha.json` `dns.servers` (or enable `strict-order`/fallthrough) so a SERVFAIL from one upstream doesn't poison the gateway's whole zone view | topology | P2 |
| 6 | Separate, unresolved by this incident: LAN split-horizon design for `cache.johnbargman.net` (points at gateway proxy vs. remote-builder directly) — decide deliberately, see diagnosis notes | design | P2 |
