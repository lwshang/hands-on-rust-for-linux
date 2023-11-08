# Compile a kernel with Rust support and run it in QEMU

My dev-env is Ubuntu 22.04 on x86_64.

## Get source code of Linux kernel

This is the fork from `Rust-for-Linux` orgnization.

```
git clone https://github.com/Rust-for-Linux/linux -b rust-dev
```

## Install required packages

Some packages are normally required for C projects:

<details>
  <summary>Click me</summary>

```
sudo apt install \
  binutils build-essential libtool texinfo \
  gzip zip unzip patchutils curl git \
  make cmake ninja-build automake bison flex gperf \
  grep sed gawk bc \
  zlib1g-dev libexpat1-dev libmpc-dev \
  libglib2.0-dev libfdt-dev libpixman-1-dev \
  libelf-dev libssl-dev
```

</details>

Since Rust is based on LLVM, we also need to install relative packages:

<details>
  <summary>Click me</summary>

```
sudo apt install \
  clang-format clang-tidy clang-tools clang clangd \
  libc++-dev libc++1 libc++abi-dev libc++abi1 \
  libclang-dev libclang1 liblldb-dev \
  libllvm-ocaml-dev libomp-dev libomp5 \
  lld lldb llvm llvm-dev llvm-runtime llvm \
  python3-clang
```

</details>

## Set up Rust toolchain

```shell
# CWD=linux
## Rust for linux use a specific version of Rust
rustup override set $(scripts/min-tool-version.sh rustc)
rustup component add rust-src
## bindgen will be used to generate bindings from C source code
cargo install --locked --version $(scripts/min-tool-version.sh bindgen) bindgen-cli
```

Then verify with:

```shell
# CWD=linux
make rustavailable
```

It's expected to see "Rust is available!".

## Generate kernel config

```shell
# CWD=linux
## LLVM is necessary for Rust
## O=build controls where to put the generated config file
make LLVM=1 O=build defconfig
# build/.config will be generated
make LLVM=1 O=build menuconfig
```

The config TUI will show up. We need to enable:

```
General setup
    -> Rust support
```

## Build the kernel

```shell
cd build
# CWD=linux/build
make LLVM=1 -j$(nproc)
```

Using all 16 cores of my machine, it took only 3m21s to finish.

From the many build artifacts, the following ones are the most important for us:

```
> file vmlinux
vmlinux: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=da85d3bdec6b89633a92af47e420a97bfef94fd5, not stripped

> file arch/x86/boot/bzImage
arch/x86/boot/bzImage: Linux kernel x86 boot executable bzImage, version 6.6.0-rc4-gf347fa1e02df (lwshang@devenv-lwshang) #1 SMP PREEMPT_DYNAMIC Tue Nov  7 21:58:41 UTC 2023, RO-rootFS, swap_dev 0XB, Normal VGA
```

And there should be a `rust` directory containing bindings and other files.

## Create an initrd (initial RAM disk)

A Linux kernel itself is not a complete OS. There must be an inial RAM disk which contains necessary userspace files.

First, we need to download the prebuilt `busybox` which can serve as `sh`, `poweroff` and many other CLI tools.

```shell
# CWD=part1
curl https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox > busybox
```

Then, we need to have a [configutration file](qemu-initramfs.desc) for the initrd and a [`init`](qemu-init.sh) which will be executed as the init process.

Now we can create the initrd:

```shell
# CWD=part1
../linux/build/usr/gen_init_cpio qemu-initramfs.desc > qemu-initramfs.img
```

## Run in QEMU

```shell
# CWD=part1
qemu-system-x86_64 \
  -kernel ../linux/build/arch/x86_64/boot/bzImage \
  -initrd qemu-initramfs.img
  -nographic \
  -append "console=ttyS0" \
```

The output will be like:

```
...
[    2.378959] Run /init as init process
[    2.419419] tsc: Refined TSC clocksource calibration: 2994.342 MHz
[    2.420056] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x2b296411175, max_idle_ns: 440795206904 ns
[    2.421392] clocksource: Switched to clocksource tsc
init from a minimal initrd!
[    2.442322] busybox (47) used greatest stack depth: 14008 bytes left
[    2.789509] input: ImExPS/2 Generic Explorer Mouse as /devices/platform/i8042/serio1/input/input3
[    2.961272] ACPI: PM: Preparing to enter system sleep state S5
[    2.962067] reboot: Power down
```