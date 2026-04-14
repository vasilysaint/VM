#!/bin/bash
set -Eeuo pipefail

WAN="${WAN_IF:-enp0s31f6}"
VM_NET="${VM_NET:-15.10.0.0/24}"

sudo nft list table ip qemu_nat >/dev/null 2>&1 || sudo nft add table ip qemu_nat
sudo nft list chain ip qemu_nat postrouting >/dev/null 2>&1 || \
sudo nft add chain ip qemu_nat postrouting '{ type nat hook postrouting priority srcnat; }'

# Idempotent rule add (only add if missing)
if ! sudo nft list chain ip qemu_nat postrouting | grep -q "oifname \"$WAN\".*ip saddr $VM_NET.*masquerade"; then
  sudo nft add rule ip qemu_nat postrouting oifname "$WAN" ip saddr "$VM_NET" masquerade
fi
