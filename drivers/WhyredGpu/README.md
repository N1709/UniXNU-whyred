# WhyredGpu

State: **adapted source**. `native/WhyredGpu.cpp` (with `GpuRegs.h` and
`GpuCore.h`) is the native UniXNU Adreno clock/identify driver, ported from
`qine233/UniXNU-clover` (commit `4c5652e`, BSD-2-Clause-Patent,
`native/LICENSE`). It is not a build input yet.

## Hardware contract

- GPU: Adreno 509, `qcom,chipid = 0x05000900`.
- GPUCC at `0x05065000`; GX/CX GDSCRs and the `gfx3d` branch as transcribed in
  `GpuRegs.h`.
- The chip ID is read at GPU base `+0x10200`, gated on CX-on, GX-on and
  `gfx3d` enabled.

## Whyred changes applied

| Constant | clover (a512) | whyred (a509) |
| --- | --- | --- |
| `kGpuChipidValue` | `0x05010200` | `0x05000900` |
| GPUCC base | `0x05065000` | unchanged |

## First milestone

Read the GPUCC state firmware left, poll CX/GX until they settle, then read the
chip ID once and match `0x05000900`. Do not write a power state the driver
cannot undo.

## Still open

Adreno 509 firmware (`a5xx`) and the ringbuffer/`IOAccelerator` path are not
started. This file only identifies the core.
