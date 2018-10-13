qemu-system-aarch64 \
  -kernel debian_bootpart/vmlinuz-4.14.0-3-arm64 \
  -initrd debian_bootpart/initrd.img-4.14.0-3-arm64 \
  -m 1024 -M virt \
  -cpu cortex-a53 \
  -serial stdio \
  -append "rw root=/dev/vda2 console=ttyAMA0 loglevel=8 rootwait fsck.repair=yes memtest=1" \
  -drive file=2018-01-08-raspberry-pi-3-buster-PREVIEW.img,format=raw,if=sd,id=hd-root \
  -device virtio-blk-device,drive=hd-root \
 -netdev user,id=net0,hostfwd=tcp::5022-:22 \
 -device virtio-net-device,netdev=net0 \
 -no-reboot
  # \
#  -append "rw console=ttyAMA0 root=/dev/mmcblk0p2 elevator=deadline fsck.repair=yes net.ifnames=0 rootwait" \
#  -append "rw console=ttyAMA0 loglevel=0  root=/dev/mmcblk0p2 fsck.repair=yes net.ifnames=0 rootwait memtest=1" \
#  -append "rw earlycon=pl011,0x3f201000 console=ttyAMA0 loglevel=8 root=/dev/mmcblk0p2 fsck.repair=yes net.ifnames=0 rootwait memtest=1" \
