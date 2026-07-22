#!/bin/bash

read -p "Are you sure you want to resize pve-root (make sure there is no containers or vms)? (y/n): " -n 1 reply

case $reply in
    [Yy]* )
        echo "Resizing..."

        lvremove /dev/pve/data -y

        lvresize -L 500G /dev/pve/root

        resize2fs /dev/pve/root

        lvcreate -l 100%FREE --thinpool data pve

        ;;
    * )
        echo "Action aborted."
        exit 1
        ;;
esac

