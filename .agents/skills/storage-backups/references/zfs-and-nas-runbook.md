# ZFS, TrueNAS & Backup Best Practices Reference

## 1. Recommended ZFS Dataset Properties by Workload

| Workload | `recordsize` | `compression` | `atime` | `sync` | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Media (`movies`, `tv`, `music`)** | `1M` | `lz4` or `zstd-3` | `off` | `standard` | Large sequential files benefit from `1M` recordsize and minimal metadata overhead. |
| **General Docker Appdata** | `128K` | `lz4` | `off` | `standard` | Good default for mixed config/log files. |
| **PostgreSQL / MySQL / SQLite** | `16K` (PG/MySQL) or `64K` | `lz4` | `off` | `standard` | Match database page size to avoid read-modify-write amplification. |
| **VM / iSCSI Zvols** | `volblocksize=16K` or `64K` | `lz4` | N/A | `standard` | Keep pool occupancy below **80%** to prevent fragmentation spikes. |

## 2. ZFS Scrub & Snapshot Schedule

- **Scrubs**: Run `zpool scrub <pool>` at least once a month (e.g., 1st Sunday at 02:00) and check `zpool status` afterward for `0B repaired, 0 errors`.
- **Snapshot retention (Sanoid / TrueNAS Periodic Snapshot Tasks)**:
  - `hourly = 24`, `daily = 14`, `weekly = 4`, `monthly = 3` on critical appdata/documents.
  - Avoid long-retention snapshots on high-churn temp/torrent-incomplete directories (place `torrents/incomplete` on a separate dataset or exclude from snapshots to avoid CoW space bloat).

## 3. Restic / Borg 3-2-1 Backup Checklist

- Always test restore ability periodically:
  ```bash
  restic restore latest --target /tmp/restore-test --include /path/to/critical/config
  ```
- Keep database dumps (`pg_dumpall`, `sqlite3 .backup`) as part of the pre-backup hook rather than relying solely on raw live database file copies without filesystem freeze/snapshots.
