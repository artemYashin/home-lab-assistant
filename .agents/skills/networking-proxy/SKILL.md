---
name: networking-proxy
description: >-
  Use this skill when configuring or troubleshooting homelab networking, reverse proxies
  (Caddy, Traefik, Nginx, Nginx Proxy Manager / NPM), local DNS and ad-blocking (Pi-hole,
  AdGuard Home), TLS certificates, and firewall/port routing.
---

# Networking, Reverse Proxy & DNS Skill

Use this skill to manage ingress routing, local DNS resolution, TLS certificates, and firewall rules.

> **Recommendation for New Setups**: Prefer declarative, config-driven reverse proxies (**Caddy**, **Traefik**, or **Nginx**) so routes live in plain text/labels over SSH without needing database state or API credentials. If the user already runs **Nginx Proxy Manager (NPM)**, use [`npm-api.sh`](./scripts/npm-api.sh).

## Helpers & References

- [`check-ingress-tls.sh`](./scripts/check-ingress-tls.sh): Tests DNS resolution, HTTPS response codes, and TLS certificate expiration dates across one or more homelab domains.
- [`proxy-configs.md`](./references/proxy-configs.md): Traefik v3 security middlewares (including LAN + Tailscale allowlists), Caddyfile wildcard DNS-01 patterns, and Pi-hole / AdGuard Home wildcard DNS setup.
- [`npm-api.sh`](./scripts/npm-api.sh): Optional helper for **Nginx Proxy Manager (NPM)** via its REST API (`list-hosts`, `list-certs`, `add-host`, `delete-host`) using `NPM_URL`, `NPM_USER`, and `NPM_PASSWORD` from `.env` or `secrets/npm.env`.

## Workflows

### 1. Config-Driven Reverse Proxies (Preferred: Caddy / Traefik / Raw Nginx)
Always validate syntax before reloading so a typo never brings down homelab ingress:
- **Caddy**: Edit `Caddyfile`, then run `caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy` (or `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`).
- **Traefik**: Add router/service labels to the target service's `compose.yaml` (or a file in Traefik's dynamic config directory) and verify `/api/http/routers`.
- **Nginx**: Edit site config, then run `nginx -t && systemctl reload nginx`.

### 2. Nginx Proxy Manager (If Used by the User)
Never manually edit `/data/nginx/proxy_host/*.conf` inside an NPM container—NPM stores its state in its database and overwrites manual file changes. Use [`npm-api.sh`](./scripts/npm-api.sh):
```bash
./.agents/skills/networking-proxy/scripts/npm-api.sh list-hosts
./.agents/skills/networking-proxy/scripts/npm-api.sh list-certs
./.agents/skills/networking-proxy/scripts/npm-api.sh add-host "<domain>" "<forward_ip>" <port> http <cert_id>
```

### 3. Audit Homelab Domains (DNS + HTTPS + TLS Expiry)
```bash
DNS_SERVER=<pihole-or-adguard-ip> ./.agents/skills/networking-proxy/scripts/check-ingress-tls.sh <domain>
```

### 4. Port & Firewall Inspection
```bash
./scripts/hl-ssh.sh <host> '
  ss -tulpn
  sudo -n ufw status verbose 2>/dev/null || sudo -n nft list ruleset 2>/dev/null || true
'
```
**Safety rule**: Never disable SSH port access or apply a default-drop firewall policy without confirming the active SSH subnet/Tailscale interface is explicitly permitted.
