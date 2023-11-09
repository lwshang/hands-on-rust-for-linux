#!/bin/sh

busybox echo "init from a minimal initrd!"
busybox insmod rust_helloworld.ko
busybox poweroff -f
