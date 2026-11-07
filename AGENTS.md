# whyred agent guide

This repository owns the Xiaomi Redmi Note 5 (whyred) board DTS, peripheral
wiring, component selection, partition geometry and packaging inputs. It does
not own the UniXNU core, the OS image or a shared SoC layer.

## Read first

| Task | Required reading |
| --- | --- |
| Every change | `UniXNU/docs/porting/device-repository.md`, `records.md`, `UniXNU/components.toml` |
| Hardware | `UniXNU/docs/porting/device-tree.md`, `soc-support.md`, `soc/sdm660/README.md` |
| Storage | `UniXNU/docs/porting/ufs.md` (the storage concepts apply; whyred is eMMC, not UFS) |
| Display / input | `UniXNU/docs/porting/display.md`, `input.md` |
| Firmware | `UniXNU/docs/porting/uefi-firmware.md` |
| Verification | `UniXNU/docs/porting/bring-up.md`, `log-capture.md` |

## Rules

- Boot with `fastboot boot` only. Never flash boot, modem, persist or recovery,
  and never format `userdata`.
- Keep the vendor device-tree provenance pinned in `feeds.toml`; verify every
  address against that revision before changing `soc/sdm660` or `dts/whyred.dts`.
- Shared controllers belong in `soc/sdm660`; board RAM, reservations, product
  identity and enabled peripherals belong in `dts/whyred.dts`.
- Use canonical component IDs from `UniXNU/components.toml`. Reusable drivers
  belong in component repositories; board-only code belongs in `package/`.
- Stage board drivers in `drivers/<Name>/` with the hardware contract and the
  next milestone. They are not build inputs until promoted to a component or a
  `package/` kit recipe; see `drivers/README.md`.
- Update the matching `porting.toml` area (findings or evidence) with every code
  change. Keep the README status table honest: `100%` means complete in this
  repository, not verified on hardware.

## Checks

```sh
./unixnu defconfig whyred_defconfig -D ../UniXNU-whyred
./unixnu status --json -D ../UniXNU-whyred
python3 scripts/porting-record.py check --device ../UniXNU-whyred
scripts/check-whyred.sh
```

Run these from the UniXNU checkout. `scripts/package.sh` is identical in every
device repository: change `board.toml`, never that script.

## Current boundary

`[firmware]` points at the published `N1709/uefi-whyred` tree, which builds a
`0x300000`-byte FD; `scripts/package.sh` can finish and leaves one `boot.img`.
The firmware has not run on the phone yet. `drivers/` holds the earlier whyred
XNU sources (`WhyredSdhci.c`, `WhyredTouch.c`) and `drivers/Whyred*/native/`
holds the native UniXNU drivers adapted from the SDM660 clover repository;
neither is a build input. The next milestone is the first `fastboot boot` log,
followed by read-only eMMC enumeration.
