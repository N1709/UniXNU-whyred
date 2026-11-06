# SDM660/SDM636 SoC layer

Shared hardware description for Qualcomm Snapdragon 660/636 (Kryo 260,
ARMv8.0) boards.

## Scope

- `soc.toml`: family metadata and the shared component set.
- `dts/sdm660.dtsi`: CPU topology, PSCI, GICv3, ARM generic timer, eMMC
  controller and BLSP1 debug UART.
- `configs/sdm660.config`: family kernel configuration (empty for now).
- `patches/xnu/series`: family XNU patches (empty for now).

The board DTS owns RAM, reserved memory, product identity and which
peripherals are enabled.

## Hardware source

Values are taken from the whyred vendor kernel device tree:

- `Whyred-Dev/android_kernel_xiaomi_sdm660`, branch `lineage-15.1`,
  commit `d85fa37dba33a7ad7a4f5435930cae06df18f7db`
- `arch/arm64/boot/dts/qcom/sdm660_whyred.dtsi`
- `arch/arm64/boot/dts/qcom/sdm636.dtsi` (`qcom,msm-id = <345 0x0>`)

## Published form

This directory is selected by the device's `feeds.toml` as a local
`kind = "soc"` source until `UniXNU-sdm660-common` is published. Moving it to a
shared repository requires no board change beyond the feed entry and pin.
