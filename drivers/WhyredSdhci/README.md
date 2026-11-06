# WhyredSdhci

State: **planned**. No driver code yet.

## Hardware contract

- Controller: `sdhc_1` at `0xc0c4000`, `hc_mem` and `cmdq_mem` each `0x1000`.
- Interrupts: 110 and 112.
- Bus: 8-bit eMMC.
- Card-side geometry used by the port: `userdata` starts at 4 KiB LBA
  `0x2b8c00` and ends at `0x1d7d6ff` (109643 MiB); the backup GPT follows the
  entry.
- The vendor SDHCI register and MSM glue sources are pinned in
  `refs/whyred-android/sdhci.h`, `sdhci.c` and `sdhci-msm.c`.

## Why this driver first

The firmware boots from this card, so the host is known to be running and the
card is known to be in transfer state when the kernel starts. The first
milestone writes nothing:

1. Map the host window read-only.
2. Read the SDHCI version, capabilities, clock control, power control and
   interrupt status.
3. Read the MSM vendor registers at both candidate offsets (MCI present and
   MCI removed) and print both, so the layout is measured rather than assumed.
4. Issue no command, set no clock, touch no reset line and clear no interrupt.

That read-only report decides the next step. A boot-capable mode follows only
after the report matches the card and the firmware state.

## Safety

No write to the card while proving the host. Writes stay inside the `userdata`
GPT entry, and the backup GPT is never touched.
