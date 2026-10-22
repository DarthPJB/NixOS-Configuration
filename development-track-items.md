# Development Track Items — Open Issues

This file tracks the development issues requested for resolution as part of our development track.

**NOTE:** These issues have been **OPEN** and recently requested. They have not been implemented yet.

---

## 1. LDAP Extension

**Status:** OPEN
**Priority:** High

**Requested by:** User
**Description:** LDAP needs to be extended to as many internal services as possible.

**Security Model Context:**
- LDAP over WAN is accepted for web-interfaces (user specification)
- Needs integration with existing topology generators

**Implementation Needed:**
- Integrate LDAP auth into existing services via topology-driven generators
- Connect LDAP to services that currently use other auth methods
- Ensure LDAP auth configuration can be expressed in topology JSON files

---

## 2. Security Model Matrix

**Status:** OPEN
**Priority:** High

**Requested by:** User
**Description:** Security model defined as:
```
WAN | WG/LAN | LDAP | SSH
zero trust | read-only zero-trust | high trust | absolute trust
```

**Requirements:**
- WAN: zero trust (no SSH, no LDAP except web-interfaces)
- WG/LAN: read-only zero-trust (LDAP read-only, no SSH)
- LDAP: high trust (full access to LDAP services)
- SSH: absolute trust (full SSH access when trusted)

**Implementation Needed:**
- Implement security model validation logic in validate.nix
- Add firewall rules in genFirewall.nix based on the matrix
- Configure SSH access restrictions
- Wire the model into topology generation and validation

---

## 3. SSH over WAN Restrictions

**Status:** OPEN
**Priority:** Critical

**Requested by:** User
**Description:** SSH over WAN should not be trusted or allowed except for required maintenance backdoors in the event of WG failure on specific systems.

**Requirements:**
- Global prohibition of SSH over WAN
- Exception list limited to maintenance back-doors
- Only on systems with explicit WG failure recovery scenarios
- Prevent all SSH over WAN except authorized exceptions

**Implementation Needed:**
- Add global SSH WAN deny rules in genFirewall.nix
- Create exception list for maintenance back-doors
- Implement monitoring/alerting for SSH over WAN access attempts
- Ensure SSH config blocks WAN access by default

---

## 4. LDAP over WAN Acceptance

**Status:** OPEN
**Priority:** Medium

**Requested by:** User
**Description:** LDAP over WAN would be accepted for web-interfaces.

**Requirements:**
- LDAP over WAN permitted only for web-interfaces
- Must maintain security and TLS requirements
- No LDAP over WAN for administrative access
- Need to enforce that only web-interface services can use LDAP over WAN

**Implementation Needed:**
- Implement restrictions in genNginx.nix for LDAP over WAN
- Add validation logic to ensure only web-interface services can use LDAP over WAN
- Configure TLS-wrapped LDAP (ldaps://) for WAN connections
- Monitor for non-web-interface LDAP over WAN access

---

## 5. Archetype Transition

**Status:** OPEN
**Priority:** High

**Requested by:** User
**Description:** Move towards an architecture where while local-user login exists, LDAP auth becomes standard for internal services and possibly Linux logins.

**Requirements:**
- Local-user login continues to exist
- LDAP auth becomes standard for internal services
- Potentially extend LDAP to Linux logins
- Maintain ability for emergency console access
- Preserve root access capabilities

**Implementation Needed:**
- Modify mktopology.nix to configure `services.authentication.method = "ldap";`
- Update service configurations to use LDAP auth by default
- Implement fallback mechanisms for emergency access
- Ensure all machines can be transitioned safely
- Update golden tests for LDAP-configured machines

---

**Summary:**
All 5 development track items are currently **OPEN** and await implementation. None have been implemented yet. The security model matrix defines the trust boundaries, and the archetype transition aims to make LDAP the standard authentication method for internal services while preserving local-user login for emergencies.

*Last updated: 2026-10-14*
