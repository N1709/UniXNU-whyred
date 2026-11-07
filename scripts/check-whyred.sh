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
CONFIG="ios-16.7.16-20H392/whyred"

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
    --os-profile "$UNIXNU/profiles/os/ios-16.7.16-20H392/profile.toml" \
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
for source in \
    drivers/WhyredSdhci/WhyredSdhci.c drivers/WhyredTouch/WhyredTouch.c \
    drivers/WhyredSdhci/native/WhyredSdhci.cpp \
    drivers/WhyredBlock/native/WhyredBlock.cpp \
    drivers/WhyredInput/native/WhyredInput.cpp \
    drivers/WhyredPower/native/WhyredPower.cpp \
    drivers/WhyredPMGR/native/WhyredPMGR.cpp \
    drivers/WhyredDisplay/native/NativeGOPPresenter.cpp \
    drivers/WhyredDsp/native/WhyredDsp.cpp \
    drivers/WhyredGpu/native/WhyredGpu.cpp \
    drivers/WhyredHidInput/native/NativeHidInput.cpp \
    drivers/WhyredKeyStore/native/NativeKeyStoreEvents.cpp \
    drivers/WhyredArmCpu/native/ArmCpu.cpp; do
    [ -s "$DEVICE/$source" ] || fail "staged source missing: $source"
done
# Reject the retired project name and its spacing/punctuation variants. The
# bracket keeps this pattern from matching its own text.
if grep -rqiE "h[a]k[ _.-]?ios|h[a]ck[ _.-]?ios|h[a]ki[ _.-]?os" "$DEVICE" --exclude-dir=.git --exclude-dir=.cache; then
    fail "retired project name found in the repository"
fi
pass "staged drivers"

# 7. Host storage logic checks (WhyredBlock + WhyredSdhci).
clang++ -Wall -Wextra -Werror -std=c++17 \
    -o "$OUT/whyred_block_test" "$DEVICE/drivers/WhyredBlock/native/tests/whyred_block_host.cpp" \
    || fail "compile whyred_block_test"
"$OUT/whyred_block_test" >/dev/null || fail "run whyred_block_test"

clang++ -Wall -Wextra -Werror -std=c++17 -I"$DEVICE/drivers/WhyredSdhci/native" \
    -o "$OUT/whyred_sdhci_test" "$DEVICE/drivers/WhyredSdhci/native/tests/whyred_sdhci_host.cpp" \
    || fail "compile whyred_sdhci_test"
"$OUT/whyred_sdhci_test" >/dev/null || fail "run whyred_sdhci_test"
pass "storage host model (WhyredBlock + WhyredSdhci)"

# 8. Host display logic check (WhyredDisplay).
clang++ -Wall -Wextra -Werror -std=c++17 -I"$DEVICE/drivers/WhyredDisplay/native" \
    -o "$OUT/whyred_display_test" "$DEVICE/drivers/WhyredDisplay/native/tests/whyred_display_host.cpp" \
    || fail "compile whyred_display_test"
"$OUT/whyred_display_test" >/dev/null || fail "run whyred_display_test"
pass "display host model (WhyredDisplay)"

# 9. Host input logic check (WhyredInput: Synaptics RMI4 + Novatek).
clang++ -Wall -Wextra -Werror -std=c++17 -I"$DEVICE/drivers/WhyredInput/native" \
    -o "$OUT/whyred_input_test" "$DEVICE/drivers/WhyredInput/native/tests/whyred_input_host.cpp" \
    || fail "compile whyred_input_test"
"$OUT/whyred_input_test" >/dev/null || fail "run whyred_input_test"
pass "input host model (WhyredInput)"

# 10. Host GPU logic check (WhyredGpu: Adreno 509 clock / chip ID model).
clang++ -Wall -Wextra -Werror -std=c++17 -I"$DEVICE/drivers/WhyredGpu/native" \
    -o "$OUT/whyred_gpu_test" "$DEVICE/drivers/WhyredGpu/native/tests/whyred_gpu_host.cpp" \
    || fail "compile whyred_gpu_test"
"$OUT/whyred_gpu_test" >/dev/null || fail "run whyred_gpu_test"
pass "gpu host model (WhyredGpu)"

# 11. Record checker.
python3 "$UNIXNU/scripts/porting-record.py" check --device "$DEVICE" \
    || fail "porting-record.py check"

printf '== all whyred host checks passed ==\n'
