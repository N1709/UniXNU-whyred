# clover driver references

Verbatim copies of six drivers from
[qine233/UniXNU-clover](https://github.com/qine233/UniXNU-clover) at commit
`4c5652e` (BSD-2-Clause-Patent, see `LICENSE`). clover is a UniXNU device
repository for an SDM660 board, so its native UniXNU drivers are the closest
official implementations to whyred's SDM636.

They are **references, not build inputs**. The board-specific constants inside
them still describe clover. Every file keeps its original name and comments so
the provenance stays readable; when a driver is promoted to `Whyred*`, the
constants below are the ones to re-check first.

| clover driver | whyred target | Shared | Must change for whyred |
| --- | --- | --- | --- |
| `CloverSdhci` | `drivers/WhyredSdhci` | SDCC1 at `0xc0c4000`, polled SDHCI takeover, read-only first mode | `userdata` first/last LBA; clover's `system` log area; boot-arg name |
| `CloverBlock` | `drivers/WhyredBlock` | `IOBlockStorageDevice` over the SDHCI window, GPT parsing, read-only fence | userdata extent and any clover partition index |
| `CloverPower` | `drivers/WhyredPower` | PM660/PM660L register knowledge, regulator arbitration shape | rails actually wired on whyred (display, touch `pm660_l11`, eMMC) |
| `CloverInput` | `drivers/WhyredTouch` | GENI/QUP I2C + TLMM GPIO plumbing, HID device shape | bus `0xc175000` (clover `0xc177000`), GPIO 2/3 (clover 10/11), GIC SPI 95 (clover 97), Synaptics `0x20` |
| `CloverPMGR` | new `WhyredPMGR` | SDM660 clock/reset sequencing, driver scheduling | whyred GCC/RPM nodes and the driver chain this board needs |
| `NativeMobileDisplay` | `drivers/WhyredDisplay` | GOP presenter / `IOMobileFramebuffer` ABI, legacy display request handling | panel geometry `1080x2160` (clover is 2560x1600) and whyred DSI/MDP nodes |

## Why keep them here

- They show the shape a working UniXNU device driver takes: C entry point,
  `build-arm-driver.py` compilation, and the `board.toml` preflight hook.
- `drivers/WhyredTouch/WhyredTouch.c` and `drivers/WhyredSdhci/WhyredSdhci.c`
  are the earlier whyred XNU drivers. The clover sources are the native-UniXNU
  alternative for the same hardware blocks; compare before writing new code.

## Promotion rule

Copy a driver out of this directory into `drivers/Whyred<Name>/`, rename the
class and boot-argument prefix, replace every clover constant with a whyred one
checked against `dts/whyred.dts` and `soc/sdm660`, add the build recipe, then
record the change in `porting.toml`. Do not build straight from this directory.
