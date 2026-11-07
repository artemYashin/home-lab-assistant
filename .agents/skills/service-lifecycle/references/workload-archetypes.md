# Generic Workload Archetypes

Reference patterns when deploying or troubleshooting different classes of homelab services.

## 1. Web App + Database + Cache Stack (e.g., Immich, Paperless, Nextcloud, Gitea, Outline)
- **Network Isolation**: Keep Postgres/MariaDB and Redis/Valkey on an internal `backend` Docker network with no host ports published. Only the web container attaches to the `proxy` network or binds `127.0.0.1:<port>:<port>`.
- **Database Pinning**: Always pin major database versions (e.g. `postgres:16-alpine` rather than `postgres:latest`) so `docker compose pull` never triggers an incompatible major data format upgrade.
- **Healthcheck Dependency**: Use `depends_on` with `condition: service_healthy` (`pg_isready` / `redis-cli ping`) so the application container waits for the database before running migrations.
- **ZFS Dataset Tuning**: Place database volumes on a dataset with `recordsize=16K` (Postgres) or `128K` (general appdata) and avoid placing SQLite databases on NFS mounts (file locking issues).

## 2. Hardware-Accelerated / GPU Workloads (e.g., Media Transcoding, Frigate NVR, Ollama, Immich ML)
- **Intel QSV / VAAPI / AMD**:
  - Map `/dev/dri:/dev/dri` into the container.
  - Ensure `group_add` includes the numeric GID of `/dev/dri/renderD128` (`stat -c '%g' /dev/dri/renderD128` on the host).
  - Verify inside the container: `docker exec <container> ls -l /dev/dri`.
- **NVIDIA GPU**:
  - Requires `nvidia-container-toolkit` on the host and `deploy.resources.reservations.devices` with `capabilities: [gpu]`.

## 3. Shared-Storage & Atomic-Move Pipelines (e.g., Downloaders, Indexers, Media Managers, Ingest Folders)
- **Single Underlying Mount Root**: When multiple containers move or hardlink large files between directories, mount a single parent host directory (e.g. `/mnt/storage/data:/data`) rather than separate sibling mounts (`/downloads` and `/library`). Separate mounts appear as distinct filesystems inside containers, forcing slow I/O copies instead of instant atomic `rename(2)` / hardlinks.
- **Verify Hardlinks**:
  ```bash
  ./scripts/hl-ssh.sh <host> "stat -c '%h %i %n' '<file-a>' '<file-b>'"
  ```
  Matching inode numbers (`%i`) and link count `%h >= 2` confirm hardlinks are working.
- **Consistent UID/GID**: Run cooperating containers under the same non-root `PUID`/`PGID` (or `user: "1000:1000"`) with `UMASK=002`.

## 4. Host-Network / Low-Level Daemons (e.g., DNS Servers, Home Automation, VPN Gateways, DHCP/mDNS)
- Services requiring Layer-2 broadcast/multicast (mDNS, Matter/HomeKit, DLNA) or raw port 53 (`systemd-resolved` conflict) may require `network_mode: host` or a macvlan/ipvlan network.
- If port 53 is bound by `systemd-resolved` (`127.0.0.53:53`) on Ubuntu/Debian, disable `DNSStubListener=no` in `/etc/systemd/resolved.conf.d/no-stub.conf` before starting a local DNS service.
