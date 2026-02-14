#!/bin/bash
set -Eeuo pipefail

STATE_DIR="${STATE_DIR:-/tmp/start-vm-state}"
mkdir -p "$STATE_DIR"

# Save original ip_forward once
if [[ ! -f "$STATE_DIR/ip_forward.before" ]]; then
  sudo sysctl -n net.ipv4.ip_forward | sudo tee "$STATE_DIR/ip_forward.before" >/dev/null
fi

sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
