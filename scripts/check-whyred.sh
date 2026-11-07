#!/usr/bin/env bash
# Host-side checks for the whyred device repository.
#
# usage: scripts/check-whyred.sh [path of the UniXNU checkout]
#
# Defaults to ../UniXNU next to this repository. Set CHECK_FETCH=1 to include
# "unixnu fetch" (network access, rewrites unixnu.lock); the default run is
# offline and only reads the committed pins. Set UNIXNU_UNIQUE_CHIP_ID to use a
# real platform seed instead of the documented 0000000000000636 sample.
set -euo pipefail

DEVICE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UNIXNU=${1:-$DEVICE/../UniXNU}
UNIXNU=$(cd "$UNIXNU" && pwd)
OUT=${CHECK_OUT:-${TMPDIR:-/tmp}/whyred-check}
SEED=${UNIXNU_UNIQUE_CHIP_ID:-0000000000000636}
CONFIG="ipados-17.7.11-21H461/whyred"

mkdir -p "$OUT"

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
have() { command -v "$1" >/dev/null || fail "missing tool: $1"; }

have dtc
have python3

printf '== whyred host checks ==\n'
printf 'device %s\nunixnu %s\n' "$DEVICE" "$UNIXNU"

# 1. Board device tree compiles without warnings and keeps the documented nodes.
dtc -I dts -O dtb -i "$DEVICE/soc/sdm660/dts" \
    -o "$OUT/whyred.dtb" "$DEVICE/dts/whyred.dts" 2>"$OUT/dtc.log" \
    || fail "dtc: $(cat "$OUT/dtc.log")"
if [ -s "$OUT/dtc.log" ]; then
    fail "dtc warnings: $(cat "$OUT/dtc.log")"
fi
pass "dtc ($(stat -c %s "$OUT/whyred.dtb") bytes)"

# 2. ADT generation with the board memory, splash and CPU set.
python3 "$UNIXNU/scripts/make-adt.py" --dtb "$OUT/whyred.dtb" \
    --os-profile "$UNIXNU/profiles/os/ipados-17.7.11-21H461/profile.toml" \
    --board "$DEVICE/board.toml" \
    --unique-chip-id "$SEED" --data-ramdisk --trust-cache \
    --output "$OUT/whyred.adt" >/dev/null \
    || fail "make-adt.py"
pass "make-adt.py ($(stat -c %s "$OUT/whyred.adt") bytes)"

# 3. The resolved configuration keeps the ARMv8.0 and eMMC board overrides.
"$UNIXNU/unixnu" defconfig whyred_defconfig -D "$DEVICE" >/dev/null 2>&1 \
    || fail "unixnu defconfig"
config="$UNIXNU/out/whyred/$CONFIG/.config"
grep -qx 'CONFIG_XNU_NATIVE_PAN=n' "$config" || fail "PAN override missing"
grep -qx 'CONFIG_XNU_NATIVE_UFS=n' "$config" || fail "eMMC override missing"
pass "unixnu defconfig"

# 4. Optional source fetch, then the source and patch resolution.
if [ "${CHECK_FETCH:-0}" = 1 ]; then
    "$UNIXNU/unixnu" fetch -D "$DEVICE" >/dev/null 2>&1 || fail "unixnu fetch"
    pass "unixnu fetch"
fi
"$UNIXNU/unixnu" status --json -D "$DEVICE" >"$OUT/status.json" 2>"$OUT/status.err" \
    || fail "unixnu status: $(cat "$OUT/status.err")"
python3 - "$OUT/status.json" <<'PY'
import json
import sys

status = json.load(open(sys.argv[1]))
assert status["configured"], "device is not configured"
assert status["name"] == "whyred", status["name"]
wanted = {"ArmDTPlatform", "ArmCpu", "SoftwareAES", "XnuPrelink", "DarwinBoot"}
have = {component["id"] for component in status["components"]}
missing = wanted - have
assert not missing, f"components missing: {sorted(missing)}"
assert status["patch_order"], "no architecture patches resolved"
print(f'ok   unixnu status ({len(have)} components, {len(status["patch_order"])} patches)')
PY

# 5. The assembled tree contains the board package and the source lock.
"$UNIXNU/unixnu" tree -D "$DEVICE" >/dev/null 2>&1 || fail "unixnu tree"
[ -d "$UNIXNU/out/whyred/$CONFIG/tree/kits/whyred" ] \
    || fail "tree/kits/whyred missing"
[ -s "$DEVICE/unixnu.lock" ] || fail "unixnu.lock missing"
pass "unixnu tree"

# 6. Staged driver sources: present, and free of the old project's naming.
for source in drivers/WhyredSdhci/WhyredSdhci.c drivers/WhyredTouch/WhyredTouch.c; do
    [ -s "$DEVICE/$source" ] || fail "staged source missing: $source"
done
# Reject the retired project name and its spacing/punctuation variants. The
# bracket keeps this pattern from matching its own text.
if grep -rqiE "h[a]k[ _.-]?ios|h[a]ck[ _.-]?ios|h[a]ki[ _.-]?os" "$DEVICE" --exclude-dir=.git --exclude-dir=.cache; then
    fail "retired project name found in the repository"
fi
pass "staged drivers"

# 7. Record checker.
python3 "$UNIXNU/scripts/porting-record.py" check --device "$DEVICE" \
    || fail "porting-record.py check"

printf '== all whyred host checks passed ==\n'
