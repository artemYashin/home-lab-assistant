#!/usr/bin/env bash
set -euo pipefail

# Audit storage health on a remote homelab node: ZFS pools, filesystems, inodes, NFS/SMB mounts, and SMART status.
# Usage: ./storage-health.sh <host>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"
HOST="${1:?Usage: $0 <host>}"

"${HL_SSH}" "${HOST}" '
  echo "=== BLOCK DEVICES ==="
  lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS,MODEL
  echo ""
  echo "=== FILESYSTEM USAGE (>=75% highlighted) ==="
  df -hT -x tmpfs -x devtmpfs -x overlay -x squashfs
  echo ""
  echo "=== INODE USAGE ==="
  df -i -x tmpfs -x devtmpfs -x overlay -x squashfs | awk "NR==1 || int(\$5) >= 50"
  echo ""
  echo "=== NETWORK MOUNTS (NFS / SMB) ==="
  findmnt -t nfs,nfs4,cifs || echo "No active NFS/CIFS mounts"
  if command -v zpool >/dev/null 2>&1; then
    echo ""
    echo "=== ZFS POOLS & CAPACITY ==="
    zpool list
    zpool status -x
    echo ""
    echo "=== ZFS DATASETS ==="
    zfs list -o name,used,avail,refer,compressratio,mountpoint
    echo ""
    echo "=== RECENT ZFS SNAPSHOTS ==="
    zfs list -t snapshot -o name,used,creation -s creation | tail -n 15
  fi
  if command -v smartctl >/dev/null 2>&1; then
    echo ""
    echo "=== SMART DISK HEALTH ==="
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n1; do
      if [ -e "$disk" ]; then
        echo "--- $disk ---"
        sudo -n smartctl -H "$disk" 2>/dev/null | grep -E "SMART overall-health|result" || echo "Run with sudo for SMART details on $disk"
      fi
    done
  fi
'
