# What is this?

It's a  **QEMU VM launcher toolkit** that simplifies running and managing virtual machines on Linux.

**Key features:**
- **Profile-based configuration** — One file per VM defines resources, disks, network, and lifecycle hooks `.conf`
- **Automated networking** — Sets up bridged networking with tap devices and nftables NAT, cleans up on exit
- **Reset & update workflow** — Restore a VM from backup, boot it, SSH in, and run system updates automatically
- **Clean teardown** — Always restores system state (network interfaces, firewall rules, sysctl) when the VM stops

**Use case:** Quickly spin up reproducible QEMU VMs with proper networking, optionally resetting to a known-good state before each run.

# Workflow Summary
1. `startvm <vm_name>` - Loads `conf/<vm_name>.conf`, runs **BEFORE_QEMU** hooks, starts QEMU, runs **AFTER_QEMU** hooks, waits, then runs CLEANUP on exit.
2. `reset-update-vm <vm_host>` - Optionally restores a backup image, starts the VM, waits for SSH, copies **update.sh** to the guest, and runs it inside tmux.

# Project structure
## Project layout
```aiignore
VM/
├── backups/          # VM disk image backups (for rollback/reset)
├── bin/              # Executable scripts
│   ├── startvm           # Main VM launcher
│   └── reset-update-vm   # Restore + start + auto-update workflow
├── conf/             # Per-VM configuration files
├── images/           # VM disk images (.img files)
├── lib/              # Reusable helper scripts (hooks)
├── logs/             # Runtime logs
└── README.md         # This file
```
## Configuration Files (`conf/`)
Each `.conf` file defines a VM profile - sourced as a bash script by startvm. They set:

| Variable | Purpose |
|----------|---------|
| `RAM`, `CPU` | Hardware resources |
| `DISKS` | QEMU `-drive` arguments |
| `NETWORK` | QEMU network device/backend args |
| `USB`, `BIOS` | Optional device passthrough / UEFI boot |
| `BEFORE_QEMU` | Hook scripts to run before QEMU starts |
| `AFTER_QEMU` | Hook scripts to run after QEMU starts |
| `CLEANUP` | Hook scripts to run on exit (cleanup networking, etc.) |

## Library Scripts (`lib/`)
Reusable hooks called by config files:

| Script | Purpose |
|--------|---------|
| `configure-bridge.sh` | Creates bridge (`br0`) and tap device, assigns IP |
| `configure-tap_and_route.sh` | Enables IP forwarding (`net.ipv4.ip_forward=1`) |
| `configure-nft.sh` | Adds nftables masquerade rule for VM subnet NAT |
| `cleanup-network.sh` | Tears down bridge/tap, removes nft rules, restores sysctl |
| `update.sh` | Pushed to the guest VM to run `apt full-upgrade` |
# Knowlege base
## Networking 
- https://www.linux-kvm.org/page/Networking
- https://wiki.archlinux.org/index.php/Network_bridge
- https://wiki.gentoo.org/wiki/QEMU/Options
- https://dougvitale.wordpress.com/2011/12/21/deprecated-linux-networking-commands-and-their-replacements/

## Bridge & tap
```
sudo ip link add name br0 type bridge
sudo ip link set br0 up
sudo ip address add 15.10.0.7 dev br0
sudo ip link set tap0 master br0
sudo ip link set tap0 up
```

## IP Forwarding
```
sudo sysctl -w net.ipv4.ip_forward=1
```

## NFT: create NAT table/chain if they don't exist
```
sudo nft add table ip nat 
sudo nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat; }' 
```

## NFT: routing examples
```
sudo nft add rule ip nat POSTROUTING oifname "enp0s31f6" masquerade
sudo nft add rule ip qemu_nat postrouting oifname "wlp3s0" ip saddr "15.10.0.0/24" masquerade
```

## Frequent commands
```
sudo qemu-system-x86_64 -m 5120 -k fr /home/asilin/VM/images/agnes.img  -enable-kvm -cpu host  -cpu host -smp 4 -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2212-:2212 -cdrom /home/asilin/kali-linux-2025.4-installer-everything-amd64.iso
sudo qemu-system-x86_64 -m 5120 -k fr /home/asilin/VM/debk.img  -enable-kvm -cpu host  -cpu host -smp 4 -device e1000,netdev=net0 -netdev tap,id=net0,script=no,downscript=no
sudo qemu-system-x86_64 -m 9116 -k fr -net none -enable-kvm -cpu host -smp 4 -drive file=VM/windows.img,format=qcow2 -bios VM/OVMF_CODE.fd
```

## Free space safely (preferred: remove old kernels)
```
dpkg -l | grep -E 'linux-image-[0-9]' | awk '{print $2 "\t" $3}'
apt purge linux-image-<old-version>-kali-amd64
```

## Updates
### The usual “just do it” one-liner
```
sudo apt-get update && sudo apt-get -y full-upgrade && sudo apt-get -y autoremove
```

### More non-interactive (good for scripts / cron)
This avoids most “restart services?” / config prompts by telling dpkg to keep the existing config and not open any UI prompts:
```
sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  full-upgrade && \
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
```
