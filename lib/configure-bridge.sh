#!/bin/bash
set -Eeuo pipefail

BR="${BRIDGE_IF:-br0}"
ADDR="${BRIDGE_ADDR:-15.10.0.7/24}"
TAP="${TAP_IF:-tap0}"
USER_TO_OWN_TAP="${SUDO_USER:-$USER}"

sudo ip link show "$BR" >/dev/null 2>&1 || sudo ip link add name "$BR" type bridge
sudo ip link set "$BR" up
sudo ip address replace "$ADDR" dev "$BR"

# Pre-create tap so networking is ready BEFORE QEMU.
# QEMU will open this exact device because you pass ifname=tap0 in config.
sudo ip link show "$TAP" >/dev/null 2>&1 || sudo ip tuntap add dev "$TAP" mode tap user "$USER_TO_OWN_TAP"
sudo ip link set "$TAP" up
sudo ip link set "$TAP" master "$BR"
