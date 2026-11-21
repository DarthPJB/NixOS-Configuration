# Incident Report — WiFi/LAN segment outage caused by a Layer-2 loop through a dual-homed laptop

**Date:** 2026-11-20
**Status:** Resolved — service restored 21:02:50 UTC; prevention actions open
**Severity:** High (entire WiFi cell + multiple wired hosts on the interconnect
switch unreachable for ~40 minutes)
**Author:** Diagnostics from LINDA + cortex-alpha (read-only), 2026-11-20
**Related:** `topology/cortex-alpha.json` (`lan_dhcp.hosts` — `ap` = `10.88.128.2`,
static), `documentation/operations-runbooks.md` (Incident Response)

## Summary

All systems on the local WiFi stopped responding, along with several wired hosts.
The access point (`ap`, `10.88.128.2`, TP-Link, wired MAC `14:cc:20:46:f8:ab`) was
ARP-silent for the entire incident window despite having **powered, functioning
radios** — a WiFi scan from LINDA found its BSSID (`14:cc:20:46:f8:a9`, SSID
`MI5-Monitoring-System`) beaconing at −58 dBm with an uptime matching the operator's
20:43 factory reset. The AP was a **victim, not the cause**: a factory reset at 20:43
UTC changed nothing.

The outage ended the moment a **cable from Michel's laptop was unplugged** (operator
testimony). Within ~100 seconds, eight clients completed full DHCP leases and the
whole segment came back. Michel's laptop is **dual-homed onto the same L2 segment** —
wired (`00:e0:4c:68:03:8f` → `10.88.128.248`, static lease `michel`) and WiFi
(`60:45:2e:9d:42:ac` → `10.88.128.247`, static lease `michel-wifi`) — and a forwarding
path between the two interfaces (Windows Network Bridge, VM bridged networking, ICS
"share this connection", or a VPN/TAP adapter) closed a frame loop:

```
laptop(wired) → switch → AP → radio → laptop(wifi) → [bridge] → laptop(wired) → …
```

The interconnect switch between cortex-alpha and terminal-nx-01/razorcrest is
unmanaged (no STP/RSTP). The loop either storm-flooded the fabric or tripped the
switch's loop/storm protection, which **black-holed the entire segment**: the AP's
wired bridge, all WiFi clients, terminal-nx-01, terminal-zero-1 and razorcrest.

This was **not** a duplicate-IP fault (dnsmasq assigned distinct per-MAC leases
throughout), not a WiFi/radio fault, not an AP configuration fault, and not a
cortex-alpha fault. It was a host-hygiene fault on one laptop, amplified by a switch
with no loop protection.

## Impact

- **WiFi clients:** all unreachable for the full window — `michel-wifi` (.247),
  `display-1` (.230), `eudaimonia` (.183), `BV6200-Plus` (.224), `Galaxy-A17-5G`
  (.211).
- **Wired hosts on the interconnect switch:** `terminal-nx-01-1` (.22),
  `terminal-zero-1` (.20), `razorcrest` (`.175`, Windows machine) — unreachable.
- **The AP itself** (`10.88.128.2`): ARP-silent the whole window (radios up).
- **Degraded-but-alive (asymmetric bridge, 20:41):** `eudaimonia` completed
  `DHCPDISCOVER`/`DHCPOFFER` but never `DHCPREQUEST` — downstream frames were being
  lost even before the segment went fully dark.
- **Unaffected:** hosts not on the interconnect switch — `local-nas` (.3),
  `print-controller` (.10), `LINDA`/`LINDACORE-88` (.88), `alpha-one` (.108),
  `pillar-of-autum` (.150), printer (`.155`), `alpha-three` (.193) — all answered
  throughout. WireGuard, Tailscale, WAN unaffected.
- **Operator cost:** ~40 minutes of WiFi outage (20:25 → 21:02:50 UTC), three AP
  power cycles and one factory reset performed in good faith against the wrong
  culprit.

## Root cause

**Primary cause: a Layer-2 forwarding loop through a dual-homed laptop (wired + WiFi
into the same broadcast domain), sustained by a bridging path between its two
interfaces, black-holing the unmanaged interconnect switch.**

Mechanism chain:

1. Michel's laptop holds two interfaces on the same L2 segment (`cortex-alpha.lan`,
   10.88.128.0/24): wired MAC `00:e0:4c:68:03:8f` (static `.248` = `michel`) and WiFi
   MAC `60:45:2e:9d:42:ac` (static `.247` = `michel-wifi`) — both reserved in
   `topology/cortex-alpha.json` → `lan_dhcp.hosts`.
2. A forwarding path between those interfaces (typical culprits: Windows "Network
   Bridge" adapter — often created accidentally via right-click → *Bridge
   Connections* — or VirtualBox/VMware/Hyper-V bridged networking, ICS, or a VPN
   TAP adapter) means frames are relayed, not terminated.
3. With the wired leg plugged in *and* WiFi associated to the AP, the relay closes a
   loop: frames circulate laptop → switch → AP → radio → laptop → … Each pass
   replicates broadcasts. The unmanaged switch has no STP to block the loop.
4. The fabric either storms or trips loop/storm protection and drops everything on
   the segment. The AP's Ethernet bridge is strangled (ARP-silent to the router) while
   its radios keep beaconing independently — which is why the SSID stayed visible
   while nothing could pass traffic. Clients' DHCP was already failing earlier in the
   window (a `169.254.100.37` link-local address is recorded in cortex-alpha's ARP
   table against the WiFi MAC — a self-assigned address from the chaos window).
5. Breaking the loop at ~21:02:50 (cable pulled) restored the segment instantly:
   mass DHCP completed within ~100 s and the AP answered ping by 21:06:16.

**Ruled out — duplicate IP.** dnsmasq's static reservations hand out distinct
addresses per MAC (`.248` wired / `.247` WiFi) and the runtime lease file shows no
conflict or duplicate assignment at any point. A single-IP conflict would break one
host; this outage took down an entire segment.

**Ruled out — AP failure.** The AP's BSSID beaconed throughout (observed at 20:55
with TSF uptime 14m09s — booting exactly at the 20:43 factory reset), and a factory
reset at 20:43 changed nothing. The poison was upstream of the AP, in the switch
fabric.

**Open sub-question — the 20:23:55 cortex-alpha death.** The router's previous boot
(109 days up) ended abruptly mid-log with no shutdown sequence, and the system came
back at 20:25:10 on kernel 6.18.55. Both power loss and a storm-induced hard lock fit
the evidence; the two may even be connected (an L2 storm on `enp3s0` could have
contributed). Not proven either way — see Action items.

## Timeline (2026-11-20, UTC)

| Time | Event |
|---|---|
| ~20:23:55 | cortex-alpha's previous boot (since Aug 3) dies mid-log — no shutdown messages. Cause open (power vs. hard lock). |
| 20:25:10 | cortex-alpha boots (kernel 6.18.55); dnsmasq up 20:25:29. AP `10.88.128.2` ARP-silent from the first probe. |
| 20:32 | First diagnostics: fleet sweep shows only 8 hosts alive on the LAN (router + `.3 .10 .88 .108 .150 .155 .193`); all WiFi clients, terminals and the AP dark. `nft` ruleset empty (no firewall involvement); `ip_forward=1`; dnsmasq healthy. |
| 20:41:09 | `eudaimonia` `DHCPDISCOVER`/`DHCPOFFER` only — no `DHCPREQUEST` follows. The segment is degraded/asymmetric: upstream frames cross the dying bridge, downstream frames are lost. |
| 20:43 | Operator factory-resets the AP (testimony). No change to the outage. |
| 20:43–20:53 | Zero DHCP. ARP for `.2` `FAILED`. AP radio scan pass 1 (from LINDA, `wlp72s0`): AP absent from the band. |
| ~20:55 | Scan pass 2: **BSS `14:cc:20:46:f8:a9`, SSID `MI5-Monitoring-System`, 2412 MHz (ch 1), −58 dBm, TSF uptime 14m09s** — the AP booted at 20:43 and its radios are alive. Wired side still dead. |
| 21:02:01–21:02:28 | tcpdump on LINDA's wire (`enp69s0f0`): cortex-alpha ARPs `who-has 10.88.128.2` / `.183` every 1–2 s (watcher prober) — **zero replies**. LINDA answers for `.88` (capture path proven sound). No frames from `14:cc:20:*` or either michel MAC. |
| **~21:02:50** | **Michel unplugs the cable from his laptop** (testimony: *"unplugged the cable from his laptop and the wifi came back"*). **Recovery burst:** `michel-wifi`, `display-1`, `eudaimonia`, `terminal-nx-01-1`, `terminal-zero-1` all complete `DISCOVER→REQUEST→ACK` within seconds. |
| 21:03:02 | `michel` (.248, wired MAC) completes a lease — the wired leg's last gasp before the cable was out. |
| 21:03:50 | `razorcrest` (`.175`, `c8:7f:54:01:35:04`) full DORA. |
| 21:04:31 | `BV6200-Plus` (.224) lease ACK. |
| 21:06:16 | Watcher log: `PING-AP: RESPONDED`, `PING-eudaimonia-183: RESPONDED`. Service restored. |
| 21:06:49 | Sweep: 15 hosts up. Dark: `.21` terminal-zero-2, `.22` terminal-nx-01-1 (leased 21:02:57 but not answering ping — host-side firewall/sleep), `.24` LINDA-WM (VM), `.151` LINDA-lan, `.211` Galaxy (phone), `.248` michel wired (unplugged by design). |
| 21:12 | Wired MAC `00:e0:4c:68:03:8f` ARP `FAILED`, absent from the wire; WiFi MAC `60:45:2e:9d:42:ac` `REACHABLE`, passing SSDP. Consistent with the cable being out and the laptop running on WiFi only. |

## Resolution & recovery state

Done:
- **Loop broken:** the offending cable was pulled from Michel's laptop (~21:02:50).
  Segment recovered spontaneously; no configuration changes were made on any host
  (observation-only per Nix declarative doctrine).
- **Service verified:** AP answers ping; eight clients re-leased within ~100 s; 15
  hosts up at the 21:06 sweep.
- **Tripwire:** `ap-watch` tmux monitor armed on cortex-alpha (neighbor state for
  `10.88.128.2`, DHCP journal tail, 3 s probe cycle, log at `/tmp/ap-watch.log`).

Remaining / pending:
1. **Michel's laptop hygiene** — identify and remove the bridging path (checklist in
   Action items) before the wired cable is reconnected. Until then, wired stays out.
2. **Switch hardening decision** — the interconnect switch is unmanaged; decide
   whether to enable RSTP/storm control (managed unit) or accept the risk with the
   host-side rule alone.
3. **Open sub-question:** determine whether the 20:23:55 cortex-alpha reboot was
   power-related or storm-induced (check PDU/UPS logs; kernel logs from the crashed
   boot are gone).
4. Retire or formalize the `ap-watch` tripwire (see action items).

## Evidence

Reproduction commands and observed results (all read-only):

- **AP ARP-silent (router side):** `ssh cortex-alpha -p 1108` → `ip neigh show |
  grep 10.88.128.2` → `FAILED` / `INCOMPLETE` throughout 20:25–21:02;
  `ping -c3 10.88.128.2` → 100 % loss, `Destination Host Unreachable`.
- **DHCP journal (the recovery signature):**
  `journalctl -u dnsmasq --since "20:43:00"` → silence until `21:02:50`, then
  `DHCPDISCOVER/DHCPOFFER/DHCPREQUEST/DHCPACK` bursts for `60:45:2e:9d:42:ac`,
  `bc:d0:74:50:34:47`, `2c:cf:67:0d:ee:83`, `dc:85:de:86:a8:77`, `10:0b:a9:7e:cc:8c`,
  `00:e0:4c:68:03:8f`, `c8:7f:54:01:35:04`, `3a:2c:81:90:31:2c` — eight clients in
  ~100 s.
- **AP radios alive throughout:** `sudo iw dev wlp72s0 scan` on LINDA (via
  `ssh deploy@LINDA -p 1108`) → `BSS 14:cc:20:46:f8:a9 … SSID: MI5-Monitoring-System
  … freq: 2412.0 … signal: -58.00 dBm … TSF: 849617029 usec (0d, 00:14:09)` —
  14m09s uptime at ~20:57 ⇒ boot at 20:43 = the factory reset.
- **Quiet-wire black-hole (not a visible storm on LINDA's port):**
  `sudo tcpdump -n -e -i enp69s0f0` (21:02:01–21:02:28) → cortex-alpha ARP requests
  for `.2` and `.183` every 1–2 s with **no replies**; LINDA replies for `.88`
  (`18:c0:4d:8d:53:6d`) proving the capture path works; zero frames from
  `14:cc:20:46:f8:ab`/`:a9` or `00:e0:4c:68:03:8f`.
- **Distinct per-MAC leases (duplicate-IP ruled out):**
  `/var/lib/dnsmasq/dnsmasq.leases` → `0 60:45:2e:9d:42:ac 10.88.128.247 michel-wifi *`
  and `0 00:e0:4c:68:03:8f 10.88.128.248 michel *`; journal shows no duplicate/conflict
  warnings (only the benign `not giving name X … exists in /etc/hosts` class).
- **Chaos fingerprint:** cortex-alpha ARP table carries `169.254.100.37 dev enp3s0
  lladdr 60:45:2e:9d:42:ac` — the WiFi adapter self-assigned link-local during the
  window when DHCP was failing.
- **Post-recovery state (21:12):** wired MAC ARP `FAILED` (cable out), WiFi MAC
  `REACHABLE` passing SSDP multicast — matches operator testimony exactly.
- **Topology ground truth:** `topology/cortex-alpha.json` `lan_dhcp.hosts` reserves
  `ap` = `14:cc:20:46:f8:ab` → `10.88.128.2`, `michel` = `00:e0:4c:68:03:8f` →
  `.248`, `michel-wifi` = `60:45:2e:9d:42:ac` → `.247`.
- **Operator testimony (Michel, via user):** *"unplugged the cable from his laptop and
  the wifi came back"* — time-correlated with the 21:02:50 DHCP burst.

## Action items

| # | Item | Owner | Priority |
|---|---|---|---|
| 1 | **Michel's laptop:** before reconnecting the cable — delete any "Network Bridge" adapter (Control Panel → Network Connections), disable ICS/mobile-hotspot sharing, check VirtualBox/VMware/Hyper-V for bridged networking on VMs, check VPN TAP adapters for bridging; confirm both NICs are on DHCP (reservations `.248`/`.247` are per-MAC). | Michel | P0 |
| 2 | **Standing rule:** no host may bridge/forward between two interfaces attached to the same L2 segment. Dual-homing (wired + WiFi to the same LAN) is permitted; forwarding between them is not. | process | P0 |
| 3 | Decide switch hardening for the interconnect switch (cortex-alpha ↔ terminal-nx-01/razorcrest/AP): managed unit with **RSTP + storm control**, or accept risk with rule #2 alone. A loop would then be contained to one port. | ops | P1 |
| 4 | Longer-term design: separate **VLAN for WiFi clients** vs. wired — a loop can then never strangle the whole estate. Ties into topology planes (`cortex-alpha.lan` sub-planes). | design | P2 |
| 5 | Formalize AP liveness monitoring (Prometheus blackbox ICMP probe on `10.88.128.2` + ARP-reachability alert, or equivalent) — replace the ad-hoc `ap-watch` tmux tripwire once in place. | ops | P1 |
| 6 | Determine cause of the 20:23:55 cortex-alpha reboot (power loss vs. storm-induced lock): check PDU/UPS logs; consider whether the loop predates the reboot and contributed to it. | ops | P2 |
| 7 | Investigate still-dark hosts post-recovery (`.21` terminal-zero-2, `.22` terminal-nx-01-1 leased-but-silent, `.151` LINDA-lan, `.211` Galaxy) — likely sleep/firewall/powered-down, confirm individually. | ops | P2 |
