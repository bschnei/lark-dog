#!/bin/bash
set -euxo pipefail

# google_compute_disk resource name
DISK_NAME=photos

# local filesystem mount point
MNT_DIR=/home/ben/originals

# if the mount point already exist, do nothing
if [[ -d "$MNT_DIR" ]]; then
        exit
else
        # create the mount point and manually mount the persistent disk
        mkdir -p $MNT_DIR
        sudo mount -o discard,defaults /dev/disk/by-id/google-$DISK_NAME $MNT_DIR

        # change ownership so photoprism can read/write
        sudo chown ben:ben $MNT_DIR

        # add fstab entry for auto mount on boot
        echo UUID=`sudo blkid -s UUID -o value /dev/disk/by-id/google-$DISK_NAME` $MNT_DIR ext4 discard,defaults,nofail 0 2 | sudo tee -a /etc/fstab
fi
