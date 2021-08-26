#!/bin/bash
set -e
# Simply running three mount commands: The existing drives will be mounted and it's impossible two are available at the same time: NUCs have NVMEs (nvmeX), Proxmox-VMs have SSDs (vdaX/sdaX).
mount -o defaults,nofail /dev/vda1 /home/master/netboot
mount -o defaults,nofail /dev/sda1 /home/master/netboot
mount -o defaults,nofail /dev/nvme0n1p1 /home/master/netboot

# Create folders to avoid issues when syncing.
mkdir -p /home/master/netboot/assets/prod /home/master/netboot/assets/dev /home/master/netboot/assets/kernels /home/master/netboot/assets/caching-server
