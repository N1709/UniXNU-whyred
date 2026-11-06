# whyred bring-up notes

Reference record for values that are not obvious from the tracked files. These
are facts from the vendor device tree and the earlier whyred XNU work, not build
results.

## Identity

- Device: Xiaomi Redmi Note 5 / Note 5 AI, codename `whyred`.
- SoC: SDM636, `qcom,msm-id = <345 0x0>` (`sdm636.dtsi`).
- Vendor source: `Whyred-Dev/android_kernel_xiaomi_sdm660`, `lineage-15.1`,
  `d85fa37dba33a7ad7a4f5435930cae06df18f7db`.
- Target OS: iPad7,1 / iPadOS 17.7.11 / 21H461, 4 KiB pages, arm64.

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
- Firmware port handoff, `HANDOFF.md`: **100%** as a plan; the port is **0%**.
- Driver tree scaffold, `drivers/` with five hardware contracts: **100%** as
  documentation; driver code is **0%**.
- Hardware boot, firmware, storage, display, input, GPU, network, audio and
  power: **0%**.

## Next

1. Port Mu-Silicium UEFI to whyred using `HANDOFF.md` and fill `[firmware]`.
2. Boot with one CPU and capture the serial console.
3. Add read-only eMMC enumeration.
4. Publish the firmware framebuffer.
5. Only then port the DSX touch driver.

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
    --os-profile profiles/os/ipados-17.7.11-21H461/profile.toml \
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
  `XnuPrelink c645d76`, `DarwinBoot 3c75734`) and 59 architecture patches.
- `porting-record.py check`: `whyred: 13 structured areas checked`.
- `unixnu fetch`: exit 0, wrote `unixnu.lock`; `unixnu tree` resolves the
  assembled tree at `out/whyred/ipados-17.7.11-21H461/whyred/tree`.
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

