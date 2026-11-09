# UniXNU-whyred

Xiaomi Redmi Note 5 / Note 5 AI (whyred), Qualcomm SDM636, 4x Cortex-A73 +
4x Cortex-A53 (Kryo 260, ARMv8.0), 3/4/6 GB RAM.

This is a **format 2 UniXNU device repository**. It selects the ARM64 profile,
the local `sdm660` SoC layer and the unmodified **iPhone X (iPhone10,3) / iOS 16.7.16 /
20H392** image. It is not a copy of the previous `ios-whyred2` shim and it does
not carry the UniXNU core checkout.

> **Safety boundary:** boot with `fastboot boot` only. Never flash boot, modem,
> persist or recovery, and never format `userdata`. The user stages the root
> image inside `userdata`; this repository does not write it.

## Status

`100%` means the item is complete in this repository, not that it boots on
hardware. The first device boot is still the open work.

| # | Step | State | Evidence |
| --- | --- | --- | --- |
| 1 | Official repository layout | **100%** | `board.toml`, `feeds.toml`, `unixnu.lock`, `configs/`, `dts/`, `soc/`, `porting.toml`, workflows, packaging script |
| 2 | Board identity and profiles | **100%** | whyred / SDM636 / `ios-16.7.16-20H392`, `[components] include`, `schema_version = 2` |
| 3 | SoC layer (CPU, PSCI, GICv3, timer) | **100%** | `soc/sdm660/dts/sdm660.dtsi`, validated with `dtc` and `make-adt.py` |
| 4 | RAM and splash reservations | **100%** | `dts/whyred.dts`: `0x80000000` + 2 GiB, splash `0x9d400000` + 36 MiB |
| 5 | userdata geometry | **100%** | GPT first LBA `0x2b8c00`, last `0x1d7d6ff`, 4 KiB LBAs |
| 6 | Packaging inputs and defconfig | **100%** | `configs/whyred_defconfig`, `[package]`, `[payload]`, `[payload.adt]` |
| 7 | Porting record | **100%** | `porting.toml`, 13 areas, `porting-record.py check`, `scripts/check-whyred.sh` |
| 8 | Firmware (Mu-Silicium UEFI) | **100%** | `N1709/uefi-whyred`; DEBUG FD `0x300000` bytes builds; not booted on hardware |
| 9 | Driver sources (SDM660 clover family) | **100%** | all 11 clover drivers adapted under `drivers/Whyred*/native/`; not build inputs |
| 10 | Storage (eMMC / SDHCI) | **100%** | `WhyredSdhci` + `WhyredBlock` sources adapted; controller, GPT CRC32, write fence & `BlockCore.h` models host-verified |
| 11 | Display | **100%** | `WhyredDisplay` native GOP presenter & legacy display adapted; 1080x2160 FB & test pattern host-verified |
| 12 | Input (Synaptics DSX) | **100%** | `WhyredInput` unified Synaptics DSX (RMI4/RMI5) & Novatek IC probing, F12 multi-touch & QUP transport host-verified |
| 13 | GPU (Adreno 509) | **25%** | clock/chip-ID driver adapted to `0x05000900`; GDSC/GPUCC & A509 identity host-verified |
| 14 | Network / audio / power | **20%** | `WhyredDsp`, `WhyredPower`, `WhyredPMGR`, `WhyredKeyStore` adapted; WCN3990 and WCD9335 pending |
| 15 | Hardware boot | **0%** | firmware builds, no device log yet |

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
record. It first installs the vendored `profiles/os/ios-16.7.16-20H392` into
the UniXNU checkout, because that profile is not in the UniXNU repository. Set
`CHECK_FETCH=1` to include `unixnu fetch`.

Compile the hardware tree and generate an ADT without the full build:

```sh
dtc -I dts -O dtb -i ../UniXNU-whyred/soc/sdm660/dts \
    -o /tmp/whyred.dtb ../UniXNU-whyred/dts/whyred.dts
python3 scripts/make-adt.py --dtb /tmp/whyred.dtb \
    --os-profile profiles/os/ios-16.7.16-20H392/profile.toml \
    --board ../UniXNU-whyred/board.toml \
    --unique-chip-id 0000000000000636 --data-ramdisk --trust-cache \
    --output /tmp/whyred.adt
```

Packaging uses the published `N1709/uefi-whyred` checkout:

```sh
scripts/package.sh --check --os ios-16.7.16-20H392
scripts/package.sh --os ios-16.7.16-20H392 --uefi ../uefi-whyred
```

The full profile name is required: `--os 16` does not resolve the iOS profile.
The `package` workflow runs the same two commands with the firmware checkout
beside the device repository and publishes `Mu-whyred.img`.

## Open work

1. Run the full `unixnu build` and the first `fastboot boot`; capture the
   UART2 log at `0x0c170000`, 115200 8n1.
2. Bring up the eMMC/SDHCI block device and the `userdata` GPT windows from
   `drivers/WhyredSdhci/native` and `drivers/WhyredBlock/native`.
3. Publish the firmware framebuffer, then the native panel and backlight
   (`drivers/WhyredDisplay`, `drivers/WhyredPower`).
4. Bring up unified Synaptics RMI4/RMI5 and Novatek touch detection and wire `drivers/WhyredHidInput`.
5. Keep the GPU, WCN3990 and audio read-only until storage and display work.

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
