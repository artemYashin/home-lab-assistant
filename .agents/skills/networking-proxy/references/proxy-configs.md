# Reverse Proxy & Local DNS Reference Snippets

## 1. Traefik v3 Dynamic Middlewares (`dynamic/middlewares.yml`)

```yaml
http:
  middlewares:
    security-headers:
      headers:
        frameDeny: true
        browserXssFilter: true
        contentTypeNosniff: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
    lan-whitelist:
      ipAllowList:
        sourceRange:
          - "127.0.0.1/32"
          - "10.0.0.0/8"
          - "172.16.0.0/12"
          - "192.168.0.0/16"
          - "100.64.0.0/10" # Tailscale CGNAT
```

## 2. Caddyfile Reverse Proxy Pattern

```caddyfile
*.lab.example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }

    @jellyfin host jellyfin.lab.example.com
    handle @jellyfin {
        reverse_proxy 192.168.1.10:8096
    }

    @sonarr host sonarr.lab.example.com
    handle @sonarr {
        reverse_proxy 192.168.1.10:8989
    }
}
```

## 3. AdGuard Home & Pi-hole DNS Verification

- **AdGuard Home**: Custom DNS rewrites (`Filters -> DNS rewrites`) allow wildcard entries like `*.lab.example.com -> <reverse-proxy-ip>` so new containers work immediately without adding per-service DNS records.
- **Pi-hole v6**: Local DNS records and CNAMEs live in `/etc/pihole/pihole.toml` (or `/etc/dnsmasq.d/` for custom wildcard `address=/.lab.example.com/<reverse-proxy-ip>`).
