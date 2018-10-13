qemu-system-arm \
   -kernel raspbian_bootpart/kernel-qemu-4.14.50-stretch \
   -dtb raspbian_bootpart/versatile-pb.dtb \
   -m 256 -M versatilepb -cpu arm1176 \
   -serial stdio \
   -append "rw console=ttyAMA0 root=PARTUUID=ee25660b-02 rootfstype=ext4  loglevel=8 rootwait fsck.repair=yes memtest=1" \
   -drive file=2018-10-09-raspbian-stretch-lite.img,format=raw \
   -redir tcp:5022::22  \
   -no-reboot

# kernel and dtb from https://github.com/dhruvvyas90/qemu-rpi-kernel
# raspbian image from https://downloads.raspberrypi.org/raspbian_lite_latest

# Raspbian Stretch Lite
# Minimal image based on Debian Stretch
# Version: October 2018
# Release date: 2018-10-09
# Kernel version: 4.14
# Release notes: Link

# console=ttyAMA0 echos the graphic window to the terminal

 
