# DNS cutover inventory — johnbargman.net / johnbargman.com

**Captured:** 2026-10-28T09:34Z
**Purpose:** Reference list of every record that existed in the old Gandi zone and is
missing from the new Porkbun zone, so the cutover can be completed without relying on
expiring resolver caches.

## Sources and method

- **Old zone (ground truth):** Gandi's authoritative nameservers are still answering
  with `aa` for both zones, even though the registry no longer delegates to them.
  Queried directly: `ns-85-a.gandi.net` (.net), `ns-155-a.gandi.net` (.com).
- **New zone:** `curitiba.ns.porkbun.com` (and the other three Porkbun NS).
- **Enumerator:** candidate names were assembled from `topology/*.json` static DNS
  entries, topology vhost names, machine names, repo-wide grep for
  `*.johnbargman.net`/`*.johnbargman.com`, and common mail/service names, then queried
  for `A, AAAA, CNAME, MX, TXT, CAA, SRV` at both authoritative sets.
- **Caveat:** AXFR is refused by both providers, so absence is based on enumeration,
  not a zone transfer. A Gandi LiveDNS API export
  (`GET /v5/livedns/domains/<domain>/records`) remains the definitive check if the
  token still has access.

## Delegation / propagation at capture time

Registry delegation for both zones is Porkbun:
`curitiba`, `fortaleza`, `maceio`, `salvador.ns.porkbun.com` (TTL 172800).

| Resolver | johnbargman.net | johnbargman.com |
|---|---|---|
| 8.8.8.8 | Porkbun NS (SOA cached from Gandi) | Porkbun |
| 9.9.9.9 | Porkbun | Porkbun |
| 1.1.1.1 | **still Gandi (cached)** | Porkbun |
| 208.67.222.222 (OpenDNS) | **still Gandi (cached)** | Porkbun |

Some resolvers will serve the old Gandi answers for up to 48h and then return what
Porkbun has. Porkbun currently has only the "Present" rows below.

## Status summary

Data records only, excluding NS/SOA:

| Zone | At Gandi | At Porkbun | Missing |
|---|---|---|---|
| johnbargman.net | 19 | 2 (apex A, nextcloud A) | 17 |
| johnbargman.com | 13 | 4 (apex A, nextcloud A, two apex TXT) | 9 |

## Present at Porkbun (no action)

| Zone | Name | Type | TTL | Value |
|---|---|---|---|---|
| johnbargman.net | @ | A | 600 | 193.16.42.101 |
| johnbargman.net | nextcloud | A | 600 | 193.16.42.101 |
| johnbargman.com | @ | A | 600 | 193.16.42.101 |
| johnbargman.com | nextcloud | A | 600 | 193.16.42.101 |
| johnbargman.com | @ | TXT | 600 | `"domain-verification=933db6bba1f57e5e01fa0993eb73317c09117caa4459ab558beb38f1a50c7bf4"` |
| johnbargman.com | @ | TXT | 600 | `"v=spf1 include:_mailcust.gandi.net ?all"` |

NS and SOA are managed by Porkbun and must not be recreated.

## Missing at Porkbun — johnbargman.net

TTL shown is the old Gandi TTL. **Porkbun minimum is 600s**, so 300/500 must be raised
to 600 when recreating.

| Name | Type | Prio | TTL(old) | Value | Notes |
|---|---|---|---|---|---|
| cache | A | — | 500 | 193.16.42.13 | in-house binary cache; same host as remote-builder |
| remote-builder | A | — | 500 | 193.16.42.13 | DDNS-managed today |
| remote-worker | A | — | 500 | 193.16.42.101 | DDNS-managed today |
| gaming-host-1 | A | — | 500 | 65.108.141.32 | DDNS-managed today |
| cortex-alpha | A | — | 500 | 82.5.173.252 | DDNS-managed today (dynamic home IP) |
| storage-array | A | — | 500 | 90.249.102.50 | dormant machine |
| agentic-gateway | A | — | 1200 | 10.88.127.107 | WireGuard-only address, published publicly by design |
| carmel-staging | A | — | 300 | 193.16.42.101 | staging vhost |
| @ | MX | 10 | 10800 | spool.mail.gandi.net. | Gandi Mail |
| @ | MX | 50 | 10800 | fb.mail.gandi.net. | Gandi Mail |
| @ | TXT | — | 10800 | `"v=spf1 include:_mailcust.gandi.net ?all"` | SPF |
| www | CNAME | — | 10800 | webredir.vip.gandi.net. | Gandi URL forwarding |
| webmail | CNAME | — | 10800 | webmail.gandi.net. | Gandi webmail |
| _imaps._tcp | SRV | 0 | 10800 | `1 993 mail.gandi.net.` | IMAP over TLS |
| _submission._tcp | SRV | 0 | 10800 | `1 465 mail.gandi.net.` | SMTP submission |
| _pop3s._tcp | SRV | 10 | 10800 | `1 995 mail.gandi.net.` | POP3 over TLS |
| _imap._tcp | SRV | 0 | 10800 | `0 0 0 .` | "service unavailable" marker; optional |

## Missing at Porkbun — johnbargman.com

| Name | Type | Prio | TTL(old) | Value | Notes |
|---|---|---|---|---|---|
| LINDA | A | — | 10800 | 82.8.241.31 | questionable/stale; confirm before restoring |
| @ | MX | 10 | 10800 | spool.mail.gandi.net. | Gandi Mail |
| @ | MX | 50 | 10800 | fb.mail.gandi.net. | Gandi Mail |
| www | CNAME | — | 10800 | webredir.vip.gandi.net. | Gandi URL forwarding |
| webmail | CNAME | — | 10800 | webmail.gandi.net. | Gandi webmail |
| _imaps._tcp | SRV | 0 | 10800 | `1 993 mail.gandi.net.` | IMAP over TLS |
| _submission._tcp | SRV | 0 | 10800 | `1 465 mail.gandi.net.` | SMTP submission |
| _pop3s._tcp | SRV | 10 | 10800 | `1 995 mail.gandi.net.` | POP3 over TLS |
| _imap._tcp | SRV | 0 | 10800 | `0 0 0 .` | "service unavailable" marker; optional |

## Queried and confirmed absent from the old zone

These were never in public DNS; they resolve only through cortex-alpha's dnsmasq
(LAN/WG split-horizon) and require **no** public records:

`gitea`, `code`, `git`, `ldap`, `print-controller`, `ollama`, `prometheus`, `grafana`,
`minio`, `ap`, `alpha-one`, `alpha-two`, `alpha-three`, `arm-builder`, `display-0/1/2`,
`terminal-zero`, `terminal-nx-01`, `pillar-of-autum`, `local-nas`, `cluster-box`,
`beta-one`, `grimterm`, and the remaining machine/topology names.

Also absent at Gandi (so nothing to migrate):

- No `AAAA` records anywhere.
- No `CAA` records.
- No `_dmarc` TXT, no DKIM selectors (`default`, `mail`, `google`, `selector1/2`, `k1`, `s1`, `s2`).
- No `autodiscover` / `autoconfig` / `mta-sts` / `_mta-sts` / `_smtp._tls`.
- No wildcard `*.johnbargman.net` or `*.johnbargman.com`.

## Operational notes

1. **Mail is already broken for switched resolvers.** `MX` is empty in both Porkbun
   zones; restore the Gandi MX/SPF (and SRV records) first if Gandi Mail is still used.
2. **`cache.johnbargman.net` has no public record right now.** Google/Quad9 already
   return NXDOMAIN. Fleet hosts that use the split-horizon resolver are unaffected,
   but any consumer on public DNS (CI, external builders) will fail. Restore it, or
   add `cache` to the DDNS script/CNAME it to `remote-builder` so it follows the IP.
3. **DDNS only manages `<hostname>.johnbargman.net`.** It will create
   `cortex-alpha`, `remote-worker`, `gaming-host-1`, `remote-builder`, and
   `storage-array` on its next run, but not `cache`, `www`, mail, or the SRV records.
4. **TTL floor:** everything recreated with TTL 600+.
5. **`www`/`webmail` point at Gandi-hosted services** (`webredir.vip.gandi.net`,
   `webmail.gandi.net`). Those CNAME targets keep working regardless of which
   nameservers host the zone — but decide whether to keep Gandi's forwarding/webmail
   or replace them before restoring.
6. **`LINDA.johnbargman.com` (82.8.241.31)** looks like an old dynamic address. Do not
   restore it blindly.
7. **`agentic-gateway` (10.88.127.107)** is an RFC1918 WireGuard address published in
   public DNS — intentional in the old zone, but confirm before republishing.

## Verification

```bash
# Old zone (Gandi still authoritative)
dig @ns-85-a.gandi.net cache.johnbargman.net A +short
dig @ns-155-a.gandi.net MX johnbargman.com +short

# New zone
dig @curitiba.ns.porkbun.com cache.johnbargman.net A +short
dig @curitiba.ns.porkbun.com MX johnbargman.net +short

# What the world sees
dig @8.8.8.8 cache.johnbargman.net A
dig @1.1.1.1 cache.johnbargman.net A
```
