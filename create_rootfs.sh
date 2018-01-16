#!/bin/bash
mkdir -p /data/rootfs
cd /data/rootfs
mkdir bin etc dev dev/pts lib usr proc sys tmp
mkdir -p usr/lib64 usr/bin usr/local/bin
touch etc/resolv.conf
cp /etc/nsswitch.conf etc/nsswitch.conf
echo root:x:0:0:root:/root:/bin/bash > etc/passwd
echo root:x:0: > etc/group
ln -s lib lib64
ln -s bin sbin
cp /sbin/busybox bin
busybox --install -s bin
cp /lib64/ld-linux-x86-64.so.2 lib64
cp /lib64/lib{c,dl,attr,pthread,m,z,resolv}.so* lib64/
