#!/bin/sh
mount -t proc none /proc
$@
umount /proc
