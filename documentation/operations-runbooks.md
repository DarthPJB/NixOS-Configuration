# Operations Runbooks

Extracted from operations.html (April 2026). Consolidates maintenance schedules and operational runbooks not documented elsewhere.

## Maintenance Schedule

### Daily
- Check system logs for errors
- Verify service status
- Monitor disk usage
- Check backup status
- Review security alerts

### Weekly
- Run Nix garbage collection
- Update flake inputs
- Review system performance
- Test disaster recovery
- Update documentation

### Monthly
- Security audit
- Performance optimization
- Backup verification
- System updates
- Capacity planning

### Quarterly
- Full system backup
- Hardware inspection
- Security review
- Disaster recovery test
- Documentation update

## Runbook: New Machine Deployment

1. Generate hardware configuration
2. Create machine directory and `default.nix`
3. Generate WireGuard keys
4. Add to topology (`real-topology/<machine>.nix` or `topology.nix`)
5. Add to `flake.nix`
6. Test configuration locally
7. Deploy to machine
8. Verify operation
9. Update documentation

## Runbook: Service Deployment

1. Create service configuration file
2. Configure service options
3. Add secrets if required
4. Import in machine config
5. Test configuration
6. Deploy to target
7. Verify service operation
8. Update monitoring

## Common Commands

```bash
# Nix garbage collection
nix-collect-garbage -d

# Update flake inputs
nix flake update

# Check system health
systemctl --failed
journalctl -p err --since "1 day ago"

# Service troubleshooting
systemctl status servicename
journalctl -u servicename -f

# Network troubleshooting
ping 10.88.127.1
traceroute 10.88.127.3
ss -tulpn

# Storage troubleshooting
df -h
zpool status
iostat -x 1
```
