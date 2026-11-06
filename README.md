# UniXNU-whyred

Xiaomi Redmi Note 5 / Note 5 AI (whyred), Qualcomm SDM636, 4x Cortex-A73 +
4x Cortex-A53 (Kryo 260, ARMv8.0), 3/4/6 GB RAM.

This is a **format 2 UniXNU device repository**. It selects the ARM64 profile,
the local `sdm660` SoC layer and the unmodified **iPad7,1 / iPadOS 17.7.11 /
21H461** image. It is not a copy of the previous `ios-whyred2` shim and it does
not carry the UniXNU core checkout.

> **Safety boundary:** boot with `fastboot boot` only. Never flash boot, modem,
> persist or recovery, and never format `userdata`. The user stages the root
> image inside `userdata`; this repository does not write it.

## Status

`100%` means the item is complete in this repository, not that it boots on
hardware. Firmware and drivers are the open work.

| # | Step | State | Evidence |
| --- | --- | --- | --- |
| 1 | Official repository layout | **100%** | `board.toml`, `feeds.toml`, `unixnu.lock`, `configs/`, `dts/`, `soc/`, `porting.toml`, workflows, packaging script |
| 2 | Board identity and profiles | **100%** | whyred / SDM636 / `ipados-17.7.11-21H461`, `[components] include`, `schema_version = 2` |
| 3 | SoC layer (CPU, PSCI, GICv3, timer) | **100%** | `soc/sdm660/dts/sdm660.dtsi`, validated with `dtc` and `make-adt.py` |
| 4 | RAM and splash reservations | **100%** | `dts/whyred.dts`: `0x80000000` + 2 GiB, splash `0x9d400000` + 36 MiB |
| 5 | userdata geometry | **100%** | GPT first LBA `0x2b8c00`, last `0x1d7d6ff`, 4 KiB LBAs |
| 6 | Packaging inputs and defconfig | **100%** | `configs/whyred_defconfig`, `[package]`, `[payload]`, `[payload.adt]` |
| 7 | Porting record | **100%** | `porting.toml`, 13 areas, `porting-record.py check`, `scripts/check-whyred.sh` |
| 8 | Firmware (Mu-Silicium UEFI) | **0%** | no whyred port yet; base, values and blockers fixed in `HANDOFF.md` |
| 9 | Storage (eMMC / SDHCI) | **0%** | controller documented, no driver |
| 10 | Display | **0%** | splash reserved, no GOP or panel driver |
| 11 | Input (Synaptics DSX) | **0%** | I2C/IRQ documented, old PDT work recorded |
| 12 | GPU (Adreno 509) | **0%** | no Adreno 5xx driver |
| 13 | Network / audio / power | **0%** | hardware documented, no components |
| 14 | Hardware boot | **0%** | blocked on firmware |

## Hardware

| Item | Value | Source |
| --- | --- | --- |
| SoC | SDM636, `qcom,msm-id = <345 0x0>` | `sdm636.dtsi` |
| CPUs | A73 MPIDR `0x100-0x103`, A53 MPIDR `0x0-0x3` | `sdm660_whyred.dtsi` |
| GIC | GICD `0x17a00000` + 64 KiB, GICR `0x17b00000` + 1 MiB | `sdm660_whyred.dtsi` |
| Timer | 19.2 MHz, PPI 1/2/3/0 | `sdm660_whyred.dtsi` |
| RAM | low bank `0x80000000` + 2 GiB | vendor DT / device reads |
| Splash | `0x9d400000` + 36 MiB | `sdm660_whyred.dtsi` |
| eMMC | `sdhc_1 @ 0xc0c4000`, IRQ 110/112 | `sdm660_whyred.dtsi` |
| userdata | first LBA `0x2b8c00`, 109643 MiB, 4 KiB | previous XNU storage read |
| Display | 1080x2160 MDP/DSI | vendor panel entries |
| Touch | Synaptics DSX `0x20`, BLSP1 QUP1 `0x0c175000`, IRQ GPIO 67 | vendor DT / old recovery test |
| GPU | Adreno 509, `qcom,chipid = 0x05000900` | vendor DT |

The vendor device-tree provenance is pinned in `feeds.toml`:
`Whyred-Dev/android_kernel_xiaomi_sdm660`, `lineage-15.1`,
`d85fa37dba33a7ad7a4f5435930cae06df18f7db`.

Selected components (`board.toml` `[components] include`): `ArmDTPlatform`,
`ArmCpu`, `SoftwareAES`, `XnuPrelink`, `DarwinBoot`. The resolver adds their
dependencies in build order.

## Build

From the UniXNU checkout, with this repository next to it:

```sh
./unixnu defconfig whyred_defconfig -D ../UniXNU-whyred
./unixnu fetch -D ../UniXNU-whyred
./unixnu status --json -D ../UniXNU-whyred
./unixnu tree -D ../UniXNU-whyred
python3 scripts/porting-record.py check --device ../UniXNU-whyred
scripts/check-whyred.sh
```

`scripts/check-whyred.sh` runs the same checks offline against the committed
pins: `dtc`, `make-adt.py`, `defconfig`, `status`, `tree` and the porting
record. Set `CHECK_FETCH=1` to include `unixnu fetch`.

Compile the hardware tree and generate an ADT without the full build:

```sh
dtc -I dts -O dtb -i ../UniXNU-whyred/soc/sdm660/dts \
    -o /tmp/whyred.dtb ../UniXNU-whyred/dts/whyred.dts
python3 scripts/make-adt.py --dtb /tmp/whyred.dtb \
    --os-profile profiles/os/ipados-17.7.11-21H461/profile.toml \
    --board ../UniXNU-whyred/board.toml \
    --unique-chip-id 0000000000000636 --data-ramdisk --trust-cache \
    --output /tmp/whyred.adt
```

Packaging becomes available after a whyred firmware checkout exists:

```sh
scripts/package.sh --check --os 17
scripts/package.sh --os 17 --uefi ../uefi-whyred
```

## Open work

1. Port Mu-Silicium UEFI to whyred using `HANDOFF.md`; fill `[firmware]` and
   `proprietary-files.txt`.
2. Bring up the eMMC/SDHCI block device and the `userdata` GPT windows
   (`drivers/WhyredSdhci`, `drivers/WhyredBlock`).
3. Publish the firmware framebuffer, then the native panel and backlight
   (`drivers/WhyredDisplay`, `drivers/WhyredPower`).
4. Port the recovered Synaptics DSX facts into a format 2 input driver
   (`drivers/WhyredTouch`).
5. Keep the GPU, WCN3990 and audio out of the first boot.

The local `soc/sdm660` layer moves to `UniXNU-sdm660-common` without a board
change beyond `feeds.toml` and its pin.

## Guides

- [Firmware handoff](HANDOFF.md)
- [Driver tree](drivers/README.md)
- [Porting](https://unixnu.com/porting/)
- [Device repository](https://unixnu.com/porting/device-repository)
- [Device tree](https://unixnu.com/porting/device-tree)
- [Component catalog](https://unixnu.com/reference/components)
- [Records](https://unixnu.com/porting/records)
