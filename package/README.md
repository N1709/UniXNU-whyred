# Board package

`package/` becomes `kits/whyred` in the assembled tree. It is intentionally
empty of build code: no board driver is selected yet.

Board drivers are staged in `../drivers/`, one directory per driver with the
hardware contract and the next milestone. A driver that must ship inside the
boot kit moves here once it has a `Kit.toml` recipe; reusable drivers move to
their own component repository and are selected through `board.toml`
`[components] include`.

Planned board code, in bring-up order:

1. eMMC/SDHCI block device and the `userdata` GPT windows.
2. Firmware framebuffer presentation, then the native MDP/DSI panel and WLED
   backlight.
3. Synaptics DSX touch input on BLSP1 QUP1.
4. PM660/PM660L rails needed by eMMC, display and touch.

Reusable drivers belong in component repositories. Add a `Kit.toml` and archive
build recipes here only when the code is whyred-specific.
