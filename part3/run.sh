#!/bin/sh
busybox_folder="../busybox"
kernel_image="../linux/build/arch/x86/boot/bzImage"
work_dir=$PWD
rootfs="rootfs"
rootfs_img=$PWD"/rootfs_img"

if [ ! -d $rootfs ]; then
    mkdir $rootfs
fi
cp $busybox_folder/_install/*  $rootfs/ -rf
cp ../e1000-driver/src/e1000_for_linux.ko $work_dir/$rootfs/
cd $rootfs
mkdir -p proc sys dev etc tmp 

cat > init << EOL
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t tmpfs none /tmp
mknod -m 666 /dev/ttyS0 c 4 64

insmod e1000_for_linux.ko
ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
ifconfig eth0 192.168.100.224 netmask 255.255.255.0 broadcast 192.168.100.255 up

setsid cttyhack /bin/sh
exec /bin/sh
EOL

chmod +x init

find . -print0 | cpio --null -ov --format=newc > $rootfs_img

cd $work_dir

qemu-system-x86_64 \
  -netdev tap,ifname=tap0,id=tap0,script=no,downscript=no \
  -device e1000,netdev=tap0 \
  -kernel $kernel_image \
  -append "console=ttyS0" \
  -nographic \
  -initrd $rootfs_img
