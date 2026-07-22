#!/bin/bash

read -p "Are you sure you want to resize pve-root to 500gb (node must have no containers or vms)? (y/n): " -n 1 reply

case $reply in
    [Yy]* )
        echo "Resizing..."

        lvremove /dev/pve/data -y

        lvresize -L 500G /dev/pve/root

        resize2fs /dev/pve/root

        lvcreate -l 100%FREE --thinpool data pve

        lsblk

        ;;
    * )
        echo "Action aborted."
        exit 1
        ;;
esac

