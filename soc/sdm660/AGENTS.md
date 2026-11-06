# SDM660/SDM636 SoC agent guide

This directory carries only resources shared by SDM660/SDM636 boards:

- CPU clusters, PSCI, GICv3, generic timer;
- shared controllers with fixed addresses and interrupts;
- family kernel configuration and XNU patches.

Board RAM, reserved memory, product identity, display, touch, GPU, modem and
power sequencing belong in the board repository. Reusable drivers belong in
their component repositories.

Read `UniXNU/docs/porting/soc-support.md` and `device-tree.md` before changing
this layer. Verify every address against the vendor DTS revision recorded in
`soc.toml`, then compile the board DTS with `dtc` and generate an ADT with
`scripts/make-adt.py`.
