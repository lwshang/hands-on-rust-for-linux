# Build an out-of-tree driver for e1000

For this task, we will use a [fork](https://github.com/fujita/linux/tree/rust-e1000) of linux kernel.

It has more modules with Rust support than the official Rust-for-Linux repo.

The Rust e1000 driver is at this [repo](https://github.com/yuoo655/e1000-driver).

The repo is almost complete. We only need to fill in some logic at the places marked with "checkpoint".

## Disable the builtin e1000 driver

Since we checkout another branch in linux, we should redo the config from beginning:

```shell
# CWD=linux
make LLVM=1 O=build defconfig
make LLVM=1 O=build menuconfig
```

In the config TUI, type `/` to enter search mode. Then search `e1000`, it'll show the location of the driver option.

Once find the option, type `N` to exclude the driver from kernel.

Don't forget to enable Rust support as in Part1. Then build the kernel as before.

```shell
# CWD=linux/build
make LLVM=1 -j$(nproc)
```

## Build the out-of-tree driver module

Once complete all checkpoints in `e1000-driver` project, we can build it.

```shell
# CWD=e1000-driver/src/linux
make
```

The module will be generated in `e1000-driver/src` directory:

```
> file e1000_for_linux.ko
e1000_for_linux.ko: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV)
```

## Prepare the initrd

This time we will try a different approach. We clone the `busybox` repo and build a root file system directly.

```shell
# CWD=busybox
make defconfig
make menuconfig
```

Enable following option:
```
Settings
    -> Build static binary (no shared libs)
```

Then build and install to a temporary directory:

```shell
# CWD=busybox
make install
```

It will create a `_install` dir which has the `busybox` executable in the correct location and all softlinks are setup.

The rest steps can be seen in the [run.sh](run.sh) script.

## Setup network for host and guest

Since we are developing a netcard driver, we need to establish connection from host to guest.

This [blog post](https://www.jianshu.com/p/9b68e9ea5849) is very helpful. I won't repeat here.

For the host, I put all commands in the [host_network.sh](host_network.sh) script.

```shell
# CWD=part3
bash host_network.sh
```

For the guest, the network setup is included in the `init` program which can be seen in [run.sh](run.sh).

```shell
ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
ifconfig eth0 192.168.100.224 netmask 255.255.255.0 broadcast 192.168.100.255 up
```

## Run in QEMU

The final qemu command is at the end of [run.sh](run.sh).

```shell
qemu-system-x86_64 \
  -netdev tap,ifname=tap0,id=tap0,script=no,downscript=no \
  -device e1000,netdev=tap0 \
  -kernel $kernel_image \
  -append "console=ttyS0" \
  -nographic \
  -initrd $rootfs_img
```

The first two flags are necessary for the network setting.

The output will be like:

```
...
[    2.087802] Run /init as init process
[    2.112736] mount (71) used greatest stack depth: 13872 bytes left
[    2.137340] e1000_for_linux: loading out-of-tree module taints kernel.
[    2.145143] rust_e1000dev: Rust e1000 device driver (init)
[    2.145674] rust_e1000dev: PCI Driver probing Some(1)
...
[    2.386528] rust_e1000dev: PCI MappedResource addr: 0xffffb19dc01c0000, len: 131072, irq: 11
[    2.389654] rust_e1000dev: get stats64
[    2.392001] insmod (75) used greatest stack depth: 11104 bytes left
[    2.417430] rust_e1000dev: Ethernet E1000 open
[    2.417642] rust_e1000dev: New E1000 device @ 0xffffb19dc01c0000
[    2.417933] rust_e1000dev: Allocated vaddr: 0xffff92b2c1bb1000, paddr: 0x1bb1000
[    2.418495] rust_e1000dev: Allocated vaddr: 0xffff92b2c1bd2000, paddr: 0x1bd2000
[    2.419240] rust_e1000dev: Allocated vaddr: 0xffff92b2c2000000, paddr: 0x2000000
[    2.419758] rust_e1000dev: Allocated vaddr: 0xffff92b2c2080000, paddr: 0x2080000
[    2.420152] rust_e1000dev: e1000 CTL: 0x140240, Status: 0x80080783
[    2.420319] rust_e1000dev: e1000_init has been completed
[    2.420502] rust_e1000dev: e1000 device is initialized
[    2.421536] rust_e1000dev: handle_irq
[    2.421676] rust_e1000dev: irq::Handler E1000_ICR = 0x4
[    2.422326] rust_e1000dev: NapiPoller poll
[    2.422511] rust_e1000dev: e1000_recv
[    2.422511]
[    2.422545] rust_e1000dev: None packets were received
[    2.423722] rust_e1000dev: get stats64
[    2.425018] IPv6: ADDRCONF(NETDEV_CHANGE): eth0: link becomes ready
[    2.426291] rust_e1000dev: get stats64
[    2.432925] rust_e1000dev: start xmit
[    2.433200] rust_e1000dev: SkBuff length: 90, head data len: 90, get size: 90
[    2.433424] rust_e1000dev: Read E1000_TDT = 0x0
[    2.433498] rust_e1000dev: >>>>>>>>> TX PKT 90
...
```

When we run `ping 192.168.100.224` in the host, the guest will show more correspongding logs on its console.

## Define a kernel function and call it from the Rust module

### Create a header file in linux include directory

Add `linux/include/linux/demo.h` file with following contents:

```C
#ifndef _DEMO_H_
#define _DEMO_H_

#include <linux/printk.h>

static inline void demo_print(void)
{
	pr_info("Hello from demo!\n");
}

#endif /* _DEMO_H_ */
```

### Include the header in `bindings_helper.h`

Modify `linux/rust/bindings/bindings_helper.h`:

```diff
 #include <linux/cdev.h>
 #include <linux/clk.h>
+#include <linux/demo.h>
 #include <linux/errname.h>
 #include <linux/file.h>
```

### Add binding with `rust_helper_` prefix

Modify `linux/rust/helpers.c`:

```diff
 #include <linux/clk.h>
+#include <linux/demo.h>
 #include <linux/errname.h>
```

```diff
 EXPORT_SYMBOL_GPL(rust_helper_ndelay);

+void rust_helper_demo_print(void) {
+       demo_print();
+}
+EXPORT_SYMBOL_GPL(rust_helper_demo_print);
+
 /*
```

### Call it in the Rust module

Modify the `init` method in `e1000-driver/src/e1000_for_linux.rs`:

```diff
     fn init(name: &'static CStr, module: &'static ThisModule) -> Result<Self> {
         pr_info!("Rust e1000 device driver (init)\n");

+        unsafe { bindings::demo_print() };
+
         let dev = driver::Registration::<pci::Adapter<E1000Driver>>::new_pinned(name, module)?;
         Ok(RustE1000dev { dev })
     }
```

### Check the result in QEMU

Make the kernel and the Rust module as previous steps. Then we rerun QEMU to check the result.

The output will be like:

```
[    2.077796] Run /init as init process
[    2.102144] mount (71) used greatest stack depth: 13872 bytes left
[    2.127484] e1000_for_linux: loading out-of-tree module taints kernel.
[    2.135006] rust_e1000dev: Rust e1000 device driver (init)
[    2.135299] Hello from demo!
[    2.135650] rust_e1000dev: PCI Driver probing Some(1)
```

The message in `demo_print` function is printed as expected.
