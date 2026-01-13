#!/usr/bin/env bash
set -euo pipefail

# Prevent two upgrades at once (apt/dpkg lock contention)
LOCKFILE="/tmp/apt-upgrade.lock"

LOGDIR="$HOME/update-logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/apt-upgrade-$(date +%F_%H%M%S).log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "=== $(date -Is) starting apt maintenance ==="

# Use noninteractive behavior for dpkg prompts
export DEBIAN_FRONTEND=noninteractive

# Use flock to avoid concurrent runs
flock -n "$LOCKFILE" bash -lc '
  set -euo pipefail
  sudo -n apt-get update
  sudo -n apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    full-upgrade
  sudo -n apt-get -y autoremove
'

echo "=== $(date -Is) done ==="
