#!/bin/bash
set -e

mkdir -p work dist
cd work

wget -q https://alpinelinux.org
wget -q https://alpinelinux.org

xorriso -osirrox on -indev alpine-virt-3.20.3-x86.iso -extract /boot boot_files

mkdir rootfs
tar -xzf alpine-minirootfs-3.20.3-x86.tar.gz -C rootfs

cp /etc/resolv.conf rootfs/etc/resolv.conf
mount -t proc /proc rootfs/proc
mount --rbind /sys rootfs/sys
mount --rbind /dev rootfs/dev

chroot rootfs /bin/sh -c "
    apk update
    apk add alpine-base openrc linux-virt mkinitfs
    apk add xorg-server xf86-video-vesa xf86-input-evdev xinit
    apk add fluxbox xterm pcmanfm mousepad netsurf font-dejavu
    
    echo 'tty1::respawn:/bin/login -f root' >> /etc/inittab
    echo 'if [ -z \"\$DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then startx; fi' > /root/.profile
    echo 'exec fluxbox' > /root/.xinitrc
    
    rc-update add devfs sysinit
    rc-update add dmesg sysinit
    rc-update add mdev sysinit
    rc-update add networking boot
    
    echo 'auto lo' > /etc/network/interfaces
    echo 'iface lo inet loopback' >> /etc/network/interfaces
    echo 'auto eth0' > /etc/network/interfaces
    echo 'iface eth0 inet dhcp' >> /etc/network/interfaces
"

umount -l rootfs/proc rootfs/sys rootfs/dev

mkdir -p iso/boot/grub
cp boot_files/vmlinuz-virt iso/boot/vmlinuz
cd rootfs
find . | cpio -H newc -o | gzip > ../iso/boot/initramfs.gz
cd ..

cat << 'EOF' > iso/boot/grub/grub.cfg
set timeout=1
set default=0
menuentry "My Web PC" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.gz
}
EOF

grub-mkrescue -o ../dist/os.iso iso
