# k3s & Talos Linux Homelab Runbook

## 1. k3s Operations

### Service & Logs
- Server status: `systemctl status k3s` / `journalctl -u k3s -n 100 --no-pager`
- Agent status: `systemctl status k3s-agent` / `journalctl -u k3s-agent -n 100 --no-pager`
- Kubeconfig location on server: `/etc/rancher/k3s/k3s.yaml`

### Embedded etcd Snapshots (Single or HA Control Plane)
- List snapshots: `sudo k3s etcd-snapshot ls`
- Create manual snapshot before upgrade:
  `sudo k3s etcd-snapshot save --name pre-upgrade-$(date +%Y%m%d-%H%M)`

### Bundled Addons (HelmChart / HelmChartConfig)
- k3s manages bundled Traefik/CoreDNS via manifests in `/var/lib/rancher/k3s/server/manifests/`.
- Never edit `/var/lib/rancher/k3s/server/manifests/traefik.yaml` directly (it gets overwritten on restart); instead place a `HelmChartConfig` in `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`.

---

## 2. Talos Linux Operations (`talosctl`)

- **Cluster health check**:
  `talosctl -n <node-ip> health`
- **Service list & logs**:
  `talosctl -n <node-ip> services`
  `talosctl -n <node-ip> logs kubelet`
- **etcd member status & defrag**:
  `talosctl -n <controlplane-ip> etcd members`
  `talosctl -n <controlplane-ip> etcd status`
- **Safe Talos upgrade**:
  `talosctl upgrade --nodes <node-ip> --image factory.talos.dev/installer/<schematic>:<version> --preserve`
