# WhyredPower

State: **planned**. No driver code yet.

## Role

Provide the PM660/PM660L rails that storage, display and touch need. This is
not a general PMIC driver; it starts with the rails the bring-up order actually
requires.

## Hardware contract

- PMIC pair: PM660 + PM660L, SPMI at `0x800f000`.
- `vcc_i2c` is `pm660_l11` and also powers the touch I2C pull-ups.
- Backlight: PM660L WLED.
- The old touch test showed that unbinding the touch device dropped `vcc_i2c`
  and made the bus read `0xff`; a rail that is assumed on is not evidence.

## First milestone

Read the PMIC arbiter identity and the enable/voltage state of the rails used by
eMMC, display and touch. Write nothing until the read reporting is correct.

## Open work

Map the remaining rails against the vendor DT and the previous device dumps,
then decide which rail writes XNU is allowed to perform (the PMIC arbiter
ownership bits decide this, not the command encoding).
