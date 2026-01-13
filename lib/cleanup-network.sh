#!/bin/bash
set -Eeuo pipefail

BR="${BRIDGE_IF:-br0}"
TAP="${TAP_IF:-tap0}"
STATE_DIR="${STATE_DIR:-/tmp/startvm-state}"

# nft cleanup (dedicated table => safe to delete)
sudo nft list table ip qemu_nat >/dev/null 2>&1 && sudo nft delete table ip qemu_nat || true

# restore ip_forward if we saved it
if [[ -f "$STATE_DIR/ip_forward.before" ]]; then
  before="$(cat "$STATE_DIR/ip_forward.before")"
  sudo sysctl -w "net.ipv4.ip_forward=$before" >/dev/null || true
fi

# detach + remove tap (may already be gone if QEMU removed it)
sudo ip link set "$TAP" nomaster >/dev/null 2>&1 || true
sudo ip link del "$TAP" >/dev/null 2>&1 || true

# remove bridge
sudo ip link set "$BR" down >/dev/null 2>&1 || true
sudo ip link del "$BR" type bridge >/dev/null 2>&1 || true

rm -rf "$STATE_DIR" >/dev/null 2>&1 || true
