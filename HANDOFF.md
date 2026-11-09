# Firmware handoff: whyred UEFI port

Status: **shipped as a build**. The firmware lives at
[N1709/uefi-whyred](https://github.com/N1709/uefi-whyred); the DEBUG FD is
`0x300000` bytes and `unixnu build` packs it into one `boot.img`. Hardware boot
is still unverified. The rest of this file keeps the values and the reasoning,
so later changes can be checked against the original plan.

## Current result

- `Platforms/Xiaomi/whyredPkg` builds vendor-free: `SimpleFbDxe` over the ABL
  framebuffer, `WhyredBootMemoryDxe`, UniXNU RamDisk and DarwinBoot.
- `[firmware.defines] ENABLE_SECUREBOOT = "0"` is required: SiliciumPkg tests
  the value in C preprocessor expressions.
- `SmbiosDxe` and `SmBiosTableDxe` are listed in `Whyred.fdf` only. Listing
  them in `DXE.inc` as well makes GenFv fail with a duplicate `FILE_GUID`.
- The device repository builds one image: `BootShim` + FD + DTB in the kernel
  field, `payload.img` in the ramdisk field.

## Base

Fork `UniXNU/uefi-sheng` (it is a Mu-Silicium tree with the UniXNU integration
already in a platform package) and keep the `main` or `sheng` history. Pinned
base at the time of writing: `66421cb7bb5694843aec8de1ca3d1de4c20cca38`.

Why not start from upstream Mu-Silicium: `Platforms/Xiaomi/lavenderPkg` (SDM660,
the closest board) has no UniXNU, DarwinBoot, RamDisk or FAT integration. Copy
both sources:

- `Platforms/Xiaomi/lavenderPkg` → `Platforms/Xiaomi/whyredPkg` for the SDM660
  memory map, DSC/FDF skeleton and DeviceBuild.py.
- `Platforms/Xiaomi/shengPkg/Include/DXE.inc` and `sheng.dsc` for the UniXNU
  module list and library classes.

## Values for `whyred.dsc`

| Item | Value | Source |
| --- | --- | --- |
| `PLATFORM_NAME` | `whyred` | board name |
| `PLATFORM_GUID` | new UUID, not lavender's `DAA08544-...` | required |
| `OUTPUT_DIRECTORY` | `Build/whyredPkg` | convention |
| `FLASH_DEFINITION` | `whyredPkg/whyred.fdf` | convention |
| `PcdSystemMemoryBase` | `0x80000000` | vendor DT, mainline `sdm630.dtsi`, live whyred FDT |
| `PcdCPUCoresStackBase` | `0x9FF90000` | lavender map; above the whyred splash end `0x9F800000` |
| `PcdCPUCorePrimaryStackSize` | `0x40000` | same |
| SMBIOS model | `Redmi Note 5` | board |
| SMBIOS retail model | `whyred` | board |
| SMBIOS retail SKU | `Redmi_Note_5_whyred` | board |
| FrameBufferWidth | `1080` | vendor panel entries |
| FrameBufferHeight | `2160` | vendor panel entries |
| FrameBufferColorDepth | `32` | vendor |
| `PcdPlatformType` | `LA` | SDM660 |

Keep lavender's `Library/MemoryMapLib/MemoryMapLib.c` unchanged for the first
build: its regions already match whyred (`Kernel 0x80000000+0x05800000`,
`SMEM 0x86000000`, `DXE Heap 0x94000000`, `Display 0x9D400000+0x02400000`,
`FV/USB FD/stack` at `0x9F800000..0x9FFFF000`). Verify every entry against the
live bootloader memory map before trusting it.

## `Resources/Configs/whyred.toml`

Start from lavender's file; the FD placement is the important part:

```toml
[boot_shim]
requires_kernel_header = true

[uefi_fd]
base = 0x9FC00000
size = 0x300000

[boot_image_kernel]
kernel_compression = "gzip"
append_dtb = true

[boot_image]
header_version = 1
```

`0x9FC00000 + 0x300000` ends below the UEFI stack at `0x9FF90000` and above the
whyred splash reservation (`0x9D400000 + 0x02400000`). Do not move it until the
bootloader memory map is read from the device.

## `Resources/DTBs/whyred.dts`

Reuse the board description that is already validated in this repository:

- `dts/whyred.dts` plus `soc/sdm660/dts/sdm660.dtsi` compile to a 2788-byte DTB.
- It carries the 8 CPUs, PSCI, GICv3, 19.2 MHz timer, eMMC, UART, 2 GiB low
  DRAM and the `0x9D400000 + 36 MiB` splash reservation.
- `scripts/check-whyred.sh` regenerates and checks it.

Copy the two sources or the compiled DTB into the firmware repository, and
record the source commit. Keep the firmware DTB and `board.toml` memory values
identical; they are the same hardware contract.

## UniXNU integration

Add to `whyredPkg/Include/DXE.inc` (after the vendor DXE block):

```text
INF UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf
INF DarwinBootPkg/Driver/DarwinBoot.inf
INF MdeModulePkg/Universal/Disk/DiskIoDxe/DiskIoDxe.inf
INF MdeModulePkg/Universal/Disk/PartitionDxe/PartitionDxe.inf
INF FatPkg/EnhancedFatDxe/Fat.inf
INF MdeModulePkg/Universal/Disk/UnicodeCollation/EnglishDxe/EnglishDxe.inf
```

Add to `whyredPkg/whyred.dsc` `[Components]`:

```text
UniXNUPkg/Application/UniXNU/UniXNU.inf
UniXNUPkg/Driver/UniXNUDxe/UniXNUDxe.inf
UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf
DarwinBootPkg/Driver/DarwinBoot.inf
```

and to `[LibraryClasses]`:

```text
UniXNULib|UniXNUPkg/Library/UniXNULib/UniXNULib.inf
FdtLib|MdePkg/Library/BaseFdtLib/BaseFdtLib.inf
```

Include the same modules with `INF <path>` in `whyred.fdf`.

## Display and input: the real blocker

Lavender's `USE_CUSTOM_DISPLAY_DRIVER = 1` points at
`Binaries/lavender/QcomPkg/Drivers/DisplayDxe/DisplayDxe.inf`. That is a
closed vendor DXE for lavender's panel and cannot drive whyred's
`td4310`/`nt36672` panel.

For whyred, in order of preference:

1. Provide a whyred vendor `DisplayDxe` (and the I2C/TLMM/PMIC DXEs it needs)
   from the stock whyred firmware, staged through `proprietary-files.txt`.
2. Or use a generic GOP driver over the framebuffer that ABL already leaves at
   `0x9D400000`, with `USE_CUSTOM_DISPLAY_DRIVER = 0`.
3. Serial-only is a valid first milestone: UniXNU needs GOP for the menu, but
   the firmware and XNU handoff can be proven on UART `0x0C170000` first.

Never reuse lavender `Binaries/` for peripheral drivers without checking the
panel and PMIC wiring.

## Build and publish

The repository is published and `[firmware]` already names its real `dsc`, `fd`,
`packages`, submodules and preflight. From the UniXNU checkout:

```sh
./unixnu build firmware --uefi ../uefi-whyred -D ../UniXNU-whyred \
  --edk2 out/feeds/mu_basecore-8f10084c --target DEBUG -j 8
```

The output is `Build/whyredPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd`. The full
one-image build (kernel, package, firmware, payload, boot image) is:

```sh
./unixnu build -D ../UniXNU-whyred --uefi ../uefi-whyred \
  --edk2 out/feeds/mu_basecore-8f10084c -j 8
```

or `scripts/package.sh --os ios-16.7.16-20H392 --uefi ../uefi-whyred`. Both leave the single
`out/whyred/ios-16.7.16-20H392/whyred/boot/boot.img`. The GitHub workflow
copies it to `Mu-whyred.img`.

The standalone `build_uefi.py` cannot build the UniXNU modules: it does not add
`{tree}/package` and `{tree}/drivers/DarwinBoot` to `PACKAGES_PATH`. Use
`unixnu build firmware`.

## Verification checklist

1. FD base and size match `Resources/Configs/whyred.toml` and `[firmware]`.
2. The FD contains `UniXNU.inf`, `UniXNUDxe.inf`, `UniXNURamDiskDxe.inf`,
   `DarwinBoot.inf`, `DiskIoDxe`, `PartitionDxe` and `Fat`.
3. Serial console at `0x0C170000`, 115200 8n1, prints the SEC/PEI/DXE log.
4. `UNIXNURAMDISK: initrd block device` appears with success.
5. The payload FAT contains `EFI/UniXNU/unixnu.toml` and the entry list shows.
6. DarwinBoot hands a GOP framebuffer to XNU and the ADT matches `board.toml`.
7. Boot with `fastboot boot` only. Never flash boot, modem, persist or recovery,
   and never format `userdata`.

Record each result in `porting.toml` under `firmware`, `display` and
`diagnostics`, with the serial log path and the exact firmware commit.
