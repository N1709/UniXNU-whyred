# Driver sources

Board-specific driver work for whyred, one directory per driver, following the
driver tree used by the clover port. Each directory carries a README with the
hardware contract, the verified facts and the next milestone.

These are **staged sources**, not yet build inputs. In format 2 the resolver
selects drivers from `UniXNU/components.toml` and the board's
`[components] include`; a new driver becomes selectable when it is published as
a component repository and added to the catalog. Until then, code that must ship
inside the boot kit goes to `package/`, which becomes `kits/whyred` in the
assembled tree. Keep both in sync when a driver is promoted.

| Driver | Role | State |
| --- | --- | --- |
| `WhyredSdhci` | eMMC host at `0xc0c4000` | staged source (`WhyredSdhci.c`) |
| `WhyredBlock` | `IOBlockStorageDevice` and the `userdata` GPT windows | planned |
| `WhyredDisplay` | GOP handoff, then MDP/DSI panel | planned |
| `WhyredTouch` | Synaptics DSX on BLSP1 QUP1 | staged source (`WhyredTouch.c`) |
| `WhyredPower` | PM660/PM660L rails needed by storage, display and touch | planned |

Staged sources come from the earlier whyred XNU port and are cleaned of that
project's naming before they land here. They document what already ran on the
phone; they do not enter the build until the promotion checklist is done.

`reference/clover/` holds six native UniXNU drivers from the SDM660 clover
repository (BSD-2-Clause-Patent, pinned commit). They are the model for the
same hardware blocks and are never built in place; see its README for the
constant-by-constant whyred delta.

Reusable drivers belong in their own component repository. A directory here is
whyred-specific wiring: addresses, panel, touch controller, rail names and the
board's own timing data.

## Promotion checklist

1. Move the directory to a new `UniXNU-<Driver>` repository; keep this README as
   the board contract.
2. Add the component to `UniXNU/components.toml` with its canonical ID,
   dependencies, repository and revision.
3. Add the ID to `board.toml` `[components] include`.
4. Remove the staged copy here, or keep it as a `local.toml` override during
   development.
5. Record the change in `porting.toml` and rerun `scripts/check-whyred.sh`.
