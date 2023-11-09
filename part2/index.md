# Build a minimal kernel module in Rust

## Add Rust source code

Goto `samples/rust` directory in the `linux` repo. 

Add a `rust_helloworld.rs` with following content:

```rust
// SPDX-License-Identifier: GPL-2.0
//! Rust minimal sample.

use kernel::prelude::*;

module! {
  type: RustHelloWorld,
  name: "rust_helloworld",
  author: "whocare",
  description: "hello world module in rust",
  license: "GPL",
}

struct RustHelloWorld {}

impl kernel::Module for RustHelloWorld {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("Hello World from Rust module");
        Ok(RustHelloWorld {})
    }
}
```

## Edit Makefile and Kconfig

1. `samples/rust/Makefile`:

```diff
@@ -1,6 +1,7 @@
 # SPDX-License-Identifier: GPL-2.0

 obj-$(CONFIG_SAMPLE_RUST_MINIMAL)              += rust_minimal.o
+obj-$(CONFIG_SAMPLE_RUST_HELLOWORLD)           += rust_helloworld.o
 obj-$(CONFIG_SAMPLE_RUST_PRINT)                        += rust_print.o

 subdir-$(CONFIG_SAMPLE_RUST_HOSTPROGS)         += hostprogs
```

2. `samples/rust/Kconfig`:

```diff
@@ -20,6 +20,16 @@ config SAMPLE_RUST_MINIMAL

          If unsure, say N.

+config SAMPLE_RUST_HELLOWORLD
+  tristate "Print Helloworld in Rust"
+  help
+    This option builds the Rust HelloWorld module sample.
+
+    To compile this as a module, choose M here:
+    the module will be called rust_helloworld.
+
+    If unsure, say N.
+
 config SAMPLE_RUST_PRINT
        tristate "Printing macros"
        help
```

## Enable the module in config

In `linux` directory, run `make LLVM=1 O=build menuconfig`. We need to enable:

```
Kernel hacking
  -> Sample Kernel code
    -> Rust samples
       -> <*>Print Helloworld in Rust (NEW)
```

## Build the module

```shell
# CWD=linux/build
make LLVM=1 -j$(nproc)
```

The built object will be at:

```
> file samples/rust/rust_helloworld.ko
samples/rust/rust_helloworld.ko: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), BuildID[sha1]=672dcd8bd88dc95de11546ed43f255ec0b009692, not stripped
```

## Create an initrd with the module

As in part1, we need `busybox`:

```shell
# CWD=part2
curl https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox > busybox
```

In the initrd [configutration file](qemu-initramfs.desc), we need to include the `.ko` file at the root of initrd.

```diff
+file    /rust_helloworld.ko   ../linux/build/samples/rust/rust_helloworld.ko   0755 0 0 
```

In the [`init`](qemu-init.sh) program, we can insert the module into kernel:

```diff
 busybox echo "init from a minimal initrd!"
+busybox insmod rust_helloworld.ko
 busybox poweroff -f
```

Now we can create the initrd:

```shell
# CWD=part2
../linux/build/usr/gen_init_cpio qemu-initramfs.desc > qemu-initramfs.img
```

## Run in QEMU

Using the same `qemu` command as in part 1:

```shell
# CWD=part2
qemu-system-x86_64 \
  -kernel ../linux/build/arch/x86_64/boot/bzImage \
  -initrd qemu-initramfs.img
  -nographic \
  -append "console=ttyS0" \
```

The output will be like:

```
...
[    2.386356] Run /init as init process
init from a minimal initrd!
[    2.446467] busybox (48) used greatest stack depth: 14216 bytes left
[    2.461029] rust_helloworld: Hello World from Rust module
[    2.462473] busybox (49) used greatest stack depth: 14072 bytes left
[    2.798879] input: ImExPS/2 Generic Explorer Mouse as /devices/platform/i8042/serio1/input/input3
[    2.971418] ACPI: PM: Preparing to enter system sleep state S5
[    2.972207] reboot: Power down
```

The line of `rust_helloworld: Hello World from Rust module` marked a success for us!
