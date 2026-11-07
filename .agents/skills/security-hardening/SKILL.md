---
name: security-hardening
description: >-
  Use this skill when auditing or hardening homelab node security, including SSH daemon
  configuration, firewall rules (UFW/nftables), Fail2ban/CrowdSec, unattended security
  upgrades, and exposed container ports.
---

# Homelab Security & Hardening Skill

Use this skill to audit and harden homelab nodes without locking out management access.

## Helper Scripts

- [`security-audit.sh`](./scripts/security-audit.sh): Read-only audit of SSH config, open public ports, Docker ports bypassing UFW (`0.0.0.0` vs `127.0.0.1`), sudoers, and pending security updates.

## Key Guardrails

1. **SSH Lockout Prevention**:
   - Before setting `PasswordAuthentication no` in `/etc/ssh/sshd_config`, always verify key-based login succeeds with `./scripts/hl-ssh.sh --check <host>`.
   - Always test config syntax before reloading sshd: `sudo sshd -t && sudo systemctl reload ssh`.
2. **Docker vs UFW Bypass**:
   - Publishing a Docker port as `-p 8080:8080` binds to `0.0.0.0:8080` and manipulates `iptables` directly, bypassing `ufw` rules!
   - For services behind a local reverse proxy on the same host, bind to loopback (`127.0.0.1:8080:8080`) or keep them on an internal Docker network with no host port published.
