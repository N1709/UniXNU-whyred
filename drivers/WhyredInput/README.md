# WhyredInput

State: **adapted source**. `native/WhyredInput.cpp` is the native UniXNU touch
probe, ported from the clover `CloverInput` driver
(`qine233/UniXNU-clover`, commit `4c5652e`, BSD-2-Clause-Patent,
`native/LICENSE`). It is not a build input yet.

## Hardware contract

- Touch controller: Synaptics DSX (RMI4) at I2C `0x20`. Some units run a
  Novatek part that answers `0x62` in bootloader mode and `0x01` after firmware
  load; the probe covers all three addresses.
- Bus: BLSP1 QUP1 at `0xc175000`, GIC SPI 95 (`INTID 127`).
- Pins: SDA GPIO 2, SCL GPIO 3 (TLMM SOUTH tile, `0x03000000`); reset GPIO 66,
  IRQ GPIO 67 (TLMM NORTH tile, `0x03900000`).
- Rail: `vcc_i2c` is `pm660_l11`; it also powers the I2C pull-ups.
- whyred has no external pull resistors on the bus.

## Whyred constants already applied

| Constant | clover | whyred |
| --- | --- | --- |
| `kQupPhys` | `0x0c177000` | `0x0c175000` |
| `kQupIntid` | `129` (SPI 97) | `127` (SPI 95) |
| SDA/SCL | GPIO 10/11 | GPIO 2/3 |
| reset / IRQ | GPIO 66/67 | GPIO 66/67 |
| candidates | Goodix `0x5d`/`0x14`, FocalTech `0x38` | Synaptics `0x20`, Novatek `0x62`/`0x01` |

The transport and pin plumbing are whyred's now. The candidate protocol tables
still carry the clover parts; the Synaptics RMI4 path from
`../WhyredTouch/WhyredTouch.c` is the reference for the next step.

## First milestone

Enable the rail, probe `0x20`, read the PDT once, and log the page description
without writing configuration. Touch reporting comes after the read path is
stable.
