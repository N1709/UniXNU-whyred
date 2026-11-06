# WhyredTouch

State: **planned**. No driver code yet. The previous whyred XNU work reached real
multi-touch and its facts are recorded here.

## Hardware contract

- Controller: Synaptics DSX at I2C address `0x20`.
- Bus: BLSP1 QUP1 at `0xc175000`.
- Interrupt: GPIO 67.
- Rail: `vcc_i2c` is `pm660_l11`; it also powers the I2C pull-ups.

## Verified from the previous port

- `/dev/input/event2` captured `ABS_MT_POSITION_X 0x1e9`,
  `ABS_MT_POSITION_Y 0x78a` and `BTN_TOUCH` down/up.
- The full PDT decoded as F34, F01 and F12, with F12 data base `0x06`.
- Unbinding the touch device disabled `vcc_i2c` and the pull-ups; reads then
  floated at `0xff`. Keep the rail on for the whole test.

## Open question

A same-register read stream returned the PDT instead of repeating the entry.
The reason is not known; the new driver must not assume the controller is
returning stale data until that is explained.

## First milestone

Enable the rail, probe `0x20`, read the PDT once, and log the page description
without writing configuration. Touch reporting comes after the read path is
stable.
