# whyred bring-up notes

Reference record for values that are not obvious from the tracked files. These
are facts from the vendor device tree and the earlier whyred XNU work, not build
results.

## Identity

- Device: Xiaomi Redmi Note 5 / Note 5 AI, codename `whyred`.
- SoC: SDM636, `qcom,msm-id = <345 0x0>` (`sdm636.dtsi`).
- Vendor source: `Whyred-Dev/android_kernel_xiaomi_sdm660`, `lineage-15.1`,
  `d85fa37dba33a7ad7a4f5435930cae06df18f7db`.
- Target OS: iPhone X (iPhone10,3, `d22ap`) / iOS 16.7.16 / 20H392, 4 KiB pages, arm64.

## Memory

- Low DRAM: `0x80000000` + 2 GiB. Present on 3/4/6 GB variants.
- Cross-checked with mainline `sdm630.dtsi` (`memory@80000000`) and the previous
  live whyred FDT (`<0x80000000 2G>` + `<0x1_00000000 0xfcc00000>`). ABL loads
  the kernel image at `0x80080000`; a published Proxmox/EDK2 note that claims a
  `0x40000000` base is wrong.
- High DRAM: starts at `0x100000000`; the 6 GB unit has about `0xfcc00000`
  there. Not described for the first boot.
- Splash: `0x9d400000` + 36 MiB (`cont_splash_mem`).
- First owned window: 1 GiB (`payload.adt.owned_memory_size = 0x40000000`),
  following the safe clover model.

## CPU and interrupts

- A73 cluster: MPIDR `0x100`, `0x101`, `0x102`, `0x103` (P).
- A53 cluster: MPIDR `0x0`, `0x1`, `0x2`, `0x3` (E).
- PSCI 1.0, `method = "smc"`.
- GICv3: GICD `0x17a00000` + `0x10000`, GICR `0x17b00000` + `0x100000`
  (8 x 128 KiB), stride `0x20000`, `#interrupt-cells = <3>`.
- Generic timer: 19.2 MHz, PPI 1/2/3/0, flags `0xf08`.
- ArmCpu uses `/arm-io/intc`; the compatible must be exactly `arm,gic-v3` and
  the node must have two (address, size) register pairs.

## Storage

- eMMC controller: `sdhc_1 @ 0xc0c4000`, `hc_mem` `0x1000`, `cmdq_mem` `0x1000`,
  IRQ 110/112, 8-bit.
- `userdata`: 4 KiB LBA `0x2b8c00` through `0x1d7d6ff` (109643 MiB).
- Previous XNU read: `"userdata" first block 0x2b8c00, 109643 MiB`.
- The backup GPT follows `userdata`; keep writes inside the entry.

## Display, input, GPU, network, power

- Display: 1080x2160 MDP/DSI; vendor panel candidates include
  `td4310_tianma`, `nt36672_tianma`, `nt36672_huaxing`, `td4310_shenchao`.
- Touch: Synaptics DSX at I2C `0x20`, BLSP1 QUP1 `0x0c175000`, IRQ GPIO 67.
  The old recovery test captured real multi-touch on `/dev/input/event2`
  (`ABS_MT_POSITION_X 0x1e9`, `ABS_MT_POSITION_Y 0x78a`, `BTN_TOUCH`), and
  decoded F34/F01/F12 with F12 data base `0x06`. The same-register read stream
  returned the PDT instead of repeating the entry; that question stays open.
- `vcc_i2c` is `pm660_l11`; unbinding the touch device disabled it and the I2C
  pull-ups, after which reads floated at `0xff`.
- GPU: Adreno 509, `qcom,chipid = 0x05000900`. No Adreno 5xx driver.
- Network: WCN3990 combo (`qca,wcn3990` for Bluetooth in the vendor DT).
- Power: PM660 + PM660L, WLED backlight.

## Completed in this repository

- Format 2 board, feeds, SoC layer, board DTS, defconfig, payload and package
  settings: **100%** as tracked files.
- Source pins in `unixnu.lock`: **100%**.
- Porting record with 13 areas: **100%**.
- Offline host check, `scripts/check-whyred.sh`: **100%**.
- Firmware port, `N1709/uefi-whyred`: **100%** as a build. The DEBUG FD is
  `0x300000` bytes and the workflow produces one `Mu-whyred.img`. Hardware
  boot is **0%**.
- Driver tree, `drivers/`, one directory per hardware block: **100%**.
- XNU driver sources, `WhyredSdhci.c` and `WhyredTouch.c`: **100%** as sources
  from the earlier whyred XNU port; not build inputs.
- Native drivers, `drivers/Whyred*/native/` (all 11 SDM660 UniXNU drivers from
  `qine233/UniXNU-clover`, BSD-2-Clause-Patent, commit `4c5652e`):
  **100%** as sources; constants applied for whyred are listed per driver.
  Covers Sdhci, Block, Display, Input, HidInput, Power, PMGR, Dsp, Gpu,
  KeyStore and ArmCpu; `WhyredArmCpu` is a reference because the catalog
  `ArmCpu` is the build input.
- Hardware boot, storage, display, input, GPU, network, audio and power: **0%**.

## Packaging

`./unixnu build` (or `unixnu release`) produces one image,
`out/whyred/ios-16.7.16-20H392/whyred/boot/boot.img`:

- kernel field: `BootShim` + `SILICIUM_UEFI.fd` + `dts/whyred.dtb`;
- ramdisk field: `payload/payload.img` (XNU kernel, ADT, config).

`[firmware] preflight` compiles the board DTB into the tree, so the firmware and
the boot image see the same tree. The GitHub workflow copies that one file to
`Mu-whyred.img` and uploads it; it does not split the outputs.

Boot it with `fastboot boot Mu-whyred.img`. Nothing is flashed.

The iPhone X iOS 16.7.16 profile is vendored at
`profiles/os/ios-16.7.16-20H392`; `scripts/check-whyred.sh` and the package
workflow copy it into `UniXNU/profiles/os/` before resolving the board. Its
pins come from the iPhone10,3 restore image: chip `0x8015`, board `0x06`
(`d22ap`), kernelcache sha256
`2ec297bac95bcba01046fd0148e97e7e5885c05a6c18827f39f534ba375c1221`, prelink
slide `-0x1000000`, prelinked roots all present in the 20H392 kernelcache.
`early_security_init` is left out because XNU 8796 has no native security-init
patch; that mechanism exists only for XNU 10063 and 12377.

The upstream arm64 series targets XNU 10063 (iPadOS 17). Six patches do not
match the 8796 source: `apple-only-cpu-tunables`, `external-archive-dependencies`,
`native-aes-personality`, `offline-owner-systemos-mount`, `source-machine-layer`
and `zzx-pmap-sync-64bit-pa` use code or context that moved between releases.
This repository keeps adapted copies in `patches/xnu/` and the iOS 16 profile
series (`profiles/os/ios-16.7.16-20H392/patches/xnu/series`) names them directly;
the other upstream patches are referenced with `arch:`. The PGZ alignment
validation, published-freezer condition and boot-progress patches are omitted
because their 8796 counterparts do not exist (the first two) or still need
adapting (boot progress). Three more patches keep the 8796 source building
with the current toolchain:

- `new-clang-drop-removed-auto-var-init-flag` drops
  `-enable-trivial-auto-var-init-zero-knowing-it-will-be-removed-from-clang`
  from `makedefs/MakeInc.def`; the LLVM this UniXNU toolchain builds
  (`58c46bae`) removed the flag and rejects it.
- `uio-stackbuf-alignment` replaces the `uio_stackbuf_t` char array with the
  10063 `UIO_STACKBUF` macro and rounds `UIO_SIZEOF` up to 8 bytes; newer
  clang rejects an array whose element size is not a multiple of its
  alignment.
- `iig-kernel-content` adds `IORPC.kernelContent` and fills it on every entry
  path, because the current `iig` (`DriverKit-440`) generates kernel dispatch
  code that reads that field, which 8796 predates.

The adapted `source-machine-layer` also adds `nos_arm_asm nos_arm_pmap` to the
`KERNEL_BASE` definition in `config/MASTER.arm64.bcm2837`. XNU enables those
options through that group tag, not through the raw `options` lines in
`config/MASTER`; without the tag the arm64 assembly and pmap sources are dropped
and the kernel link fails with undefined symbols. `apple_amcc` stays inactive
because 8796 has no `amcc_rorgn_*.c` sources, so the entries gated on it are
skipped instead of breaking the build.

`osfmk/conf/files.arm64` also lists `osfmk/arm64/kpc.c` as
`optional kpc nos_arm_asm`, but that file only exists from 10063 onward. On
8796 the entry stays inactive while `nos_arm_asm` is off; activating the group
makes make stop with `No rule to make target .../kpc.c`. Because whyred has no
Apple PMU, `arm64-nonapple-kpc-stub.patch` adds the non-Apple stub from the
10063 file: the kpc/kperf interfaces stay linkable and report no counters. It
also defines `kpc_pc_capture`, which `kern_kpc.c` exports through the
`pc_capture_supported` sysctl; the Apple PMU normally sets it, and a phone
without PC sampling reports zero.

`pmap.h` declares `pmap_pending_preemption()` out of line when
`SCHED_HYGIENE_DEBUG && (DEBUG || DEVELOPMENT)`, but 8796 only ships the
definition in Apple's closed per-SoC pmap. The development kernel therefore
linked without it. `arm64-nonapple-pmap-stub.patch` defines it next to
`pmap_abandon_measurement()` in `osfmk/arm/pmap/pmap_misc.c` and returns the
urgent-AST check the inline version uses; it is compiled only under that same
configuration and when `XNU_MONITOR` is off.

The earlier link also missed `mockfs_mountroot`, `mockfs_vfsops` and
`mockfs_vnodeop_opv_desc`. `CONFIG_XNU_SOURCE_MOCKFS=y` turns on both the
`-DMOCKFS=1` compile of `vfs_conf.c` and the `build-mockfs-fixture.py` archive,
so a clean build links them; the undefined block came from the same run that
never reached the archive step. No mockfs stub is needed.

Only the iOS 16 profile is offered: the board has one target, and the iPadOS
profile is not part of this port.

### 2026-11-11: the bootstrap pass needs per-object compile records

Run `42787794966` reached the link and reported four symbols this board does
not define: `_kpc_pc_capture`, `_mockfs_mountroot`, `_mockfs_vfsops` and
`_mockfs_vnodeop_opv_desc`. The pmap and mockfs sources are selected, so the
fault is earlier: the pinned UniXNU `b936519` has no per-object `.o.json`
generator, `startup.o.json` never appears, and `unixnu build` therefore always
takes its bootstrap pass. That pass builds and links without the archive set,
so the mockfs fixture is never compiled and the link is expected to fail.

`scripts/compile-records.py` is the generator. XNU's `makedefs/MakeInc.def`
already says `KCC = $(CCACHE) $(CC)` and leaves `CCACHE` to the driver of the
build, so exporting `CCACHE=<script>` makes every C compile pass through the
wrapper. The wrapper records the CMake-style `{directory, file, arguments}`
entry as `<object>.json` next to the object before `execv`-ing the compiler,
and states `-o` explicitly when XNU's C rule lets clang derive the object
name; `build-mockfs-fixture.py` and `build-libpthread-kernel.py` substitute
`-o` and would otherwise write the object where the consumer does not look.
The archive builders read exactly `vfs_conf.o.json` and `prng_random.o.json`,
so the first pass now leaves both and the archive step can run.

The package workflow sets `CCACHE` to
`${{ github.workspace }}/device/scripts/compile-records.py` for the package
step. `kernel.build()` starts from `dict(os.environ)`, so the value reaches
make unchanged; no framework change and no pin bump are needed.

Run `42922819047` confirms it: `archive-07-build-mockfs-fixture.log` ends with
`3 XNU mockfs sources compiled`, so the fixture archive exists. The same run
then stopped in `archive-08-build-libpthread-kernel.log` with `22 warnings and
1 error generated`. The log only holds the last 4500 characters of the
compiler output, so the diagnostic itself was lost; the source names the
cause: `kern_support.c:670` calls `pthread_kern->proc_get_jit_entitled`, a
callback that `pthread_callbacks_s` only gained after xnu-8796. The pinned
libpthread is the iOS 17 drop, so the component is one API ahead of this
kernel in exactly that place.

`patches/libpthread/` mirrors the same fix the NX769J board carries. A device
`patches/libpthread` directory shadows UniXNU's instead of adding to it, so
`explicit-kernel-address.patch` is copied byte for byte
(`sha256 e07db8de...`) next to `xnu-8796-no-jit-entitlement.patch`
(`sha256 b558e5af...`). Both apply cleanly, in that order, to libpthread
`c0e60fb5`. The bootstrap link in the same run still lists `_kpc_pc_capture`
and the three mockfs symbols, but that link runs with `XNU_BOOTSTRAP=1`
before any archive exists; the archive step is the one that has to be clean,
and it now reaches archive 08.

The package workflow checks out UniXNU at `b936519` rather than following
upstream `main`. Upstream `main` (`d830d23`) points
`drivers/AppleKeyStoreState` at `6ff4f11`, a commit that its remote no longer
serves, so `git submodule update --init --recursive` in the deps step fails
before the kernel build. `b936519` is the revision this board's `unixnu
status`, tree and 58-patch series were verified against; update the pin once
upstream repairs the submodule.

## Next

1. Run the `package` workflow and download `Mu-whyred.img`.
2. Boot it with `fastboot boot` and capture UART2 at `0x0C170000`, 115200 8n1.
3. Add read-only eMMC enumeration from `drivers/WhyredSdhci`.
4. Publish the firmware framebuffer, then port the DSX touch driver.
5. Promote the clover native drivers one at a time into `drivers/Whyred*`.

## Publication

The repository is pushed to `N1709/UniXNU-whyred` (`main`). The `unixnu` GitHub
topic is still missing: the host has no `gh` CLI and no valid token, so the API
call cannot be made here. Add it once, either in the web UI (**About** →
**Topics**) or with an authenticated CLI:

```sh
gh repo edit N1709/UniXNU-whyred --add-topic unixnu
gh repo view N1709/UniXNU-whyred --json repositoryTopics --jq '.repositoryTopics[].name'
```

## Host verification (2026-11-07)

Commands run from the UniXNU checkout:

```sh
dtc -I dts -O dtb -i ../UniXNU-whyred/soc/sdm660/dts \
    -o /tmp/whyred.dtb ../UniXNU-whyred/dts/whyred.dts
python3 scripts/make-adt.py --dtb /tmp/whyred.dtb \
    --os-profile profiles/os/ios-16.7.16-20H392/profile.toml \
    --board ../UniXNU-whyred/board.toml \
    --unique-chip-id 0000000000000636 --data-ramdisk --trust-cache \
    --output /tmp/whyred.adt
./unixnu defconfig whyred_defconfig -D ../UniXNU-whyred
./unixnu status --json -D ../UniXNU-whyred
python3 scripts/porting-record.py check --device ../UniXNU-whyred
```

Results:

- `dtc`: no warnings, 2788-byte DTB.
- `make-adt.py`: 14776-byte ADT. `/chosen` has `dram-base 0x80000000`,
  `dram-size 0x80000000`, `chip-id 0x636`, `unique-chip-id 0x636` and
  `darwinboot-memory-size 0x40000000`. `/cpus` has 8 CPUs; `cpu0` is the A73
  at MPIDR `0x100` with state `running`, the rest are `waiting`. `/arm-io`
  ranges are `0x0, 0xc000000, 0xc00000`; `intc`, `sdhc` and `uart` registers
  subtract that base correctly.
- `unixnu defconfig`: `.config` ends with the board overrides and
  `CONFIG_XNU_NATIVE_PAN=n`.
- `unixnu status`: exit 0; resolves the five components at their catalog
  revisions (`ArmCpu 93a5030`, `ArmDTPlatform 417ff95`, `SoftwareAES 4a45326`,
  `XnuPrelink c645d76`, `DarwinBoot 3c75734`) and the iOS 16 series (58 patches).
- `porting-record.py check`: `whyred: 13 structured areas checked`.
- `unixnu fetch`: exit 0, wrote `unixnu.lock`; `unixnu tree` resolves the
  assembled tree at `out/whyred/ios-16.7.16-20H392/whyred/tree`.
- `scripts/check-whyred.sh`: reproduces all of the above offline and exits 0.

### `unixnu fetch`

`unixnu fetch` completes and writes `unixnu.lock`, which is committed. Two
checkout details had to be fixed first:

- The core repository's submodule gitlink for `drivers/ArmCpu` pointed at
  `2e11cda72740b985dedde3e32ba72b0fd64eb475`, which the component remote does
  not serve. Checking the submodule out at the catalog revision (`93a5030`) and
  staging that gitlink in the disposable core checkout let `update_submodules`
  finish. The core checkout is not part of this repository.
- `arch/arm64/boot/dts/qcom` in the vendor kernel is a symlink to
  `arch/arm/boot/dts/qcom`, so `feeds.toml` pins the real directory. Pinning
  the symlink makes the sparse checkout fail the existence check.

The lock records `xnu d8b8029`, `edk2 cfb9372`, `corecrypto-2023 11fba65`,
`libdispatch 30fe6a7`, `libplatform a00a4cc`, `libpthread c0e60fb`,
`IOStorageFamily e45fbe3`, `AvailabilityVersions 933f936` and
`whyred-android-dt d85fa37`. Component revisions stay in
`UniXNU/components.toml`.

