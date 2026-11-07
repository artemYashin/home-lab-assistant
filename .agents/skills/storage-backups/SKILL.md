---
name: storage-backups
description: >-
  Use this skill when managing homelab storage, ZFS pools/datasets/snapshots, TrueNAS/NAS
  mounts (NFS/SMB), disk SMART health, disk space cleanup, or Restic and Borg backups.
---

# Storage, ZFS, NAS & Backups Skill

Use this skill for inspecting storage health, ZFS datasets, network shares, and backup jobs.

## Helpers & References

- [`storage-health.sh`](./scripts/storage-health.sh): Runs a complete storage audit on a remote node (block devices, filesystem & inode usage, NFS/SMB mounts, ZFS pools/datasets/snapshots, and SMART health).
- [`zfs-and-nas-runbook.md`](./references/zfs-and-nas-runbook.md): Recommended ZFS `recordsize`/`compression` settings per workload (Media vs Databases vs Appdata), snapshot retention rules, and 3-2-1 backup verification.

## Workflows

### 1. Run Full Storage Audit on a Node
```bash
./.agents/skills/storage-backups/scripts/storage-health.sh <host>
```

### 2. Pre-Change ZFS Snapshot
Before upgrading a complex service or migrating database files on ZFS:
```bash
./scripts/hl-ssh.sh <host> "sudo zfs snapshot <pool>/<dataset>@pre-change-\$(date +%Y%m%d-%H%M)"
```
To roll back if needed (confirm with user first):
`sudo zfs rollback <pool>/<dataset>@pre-change-<timestamp>`

### 3. Verify Backups (Restic / Borg)
- **Restic**: `restic snapshots --latest 5 && restic check`
- **Borg**: `borg list --last 5 && borg check --info`
- **Safety rule**: Never run `prune --forget` or delete ZFS datasets/snapshots without explicit user confirmation.
