#!/usr/bin/env python3
"""Compile dts/whyred.dts into the build tree for the boot image.

Run by "unixnu build firmware" as a [firmware] preflight script: the working
directory is the assembled build tree, so the output lands at
<tree>/dts/whyred.dtb, which is what [bootimg] dtb names.

usage (the driver sets both variables):
    UNIXNU_DEVICE=<device repo> python3 scripts/build-whyred-dtb.py
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    device = Path(os.environ.get('UNIXNU_DEVICE') or Path(__file__).resolve().parent.parent)
    dtc = shutil.which('dtc')
    if not dtc:
        sys.exit('build-whyred-dtb: dtc not found on PATH')

    source = device / 'dts/whyred.dts'
    include = device / 'soc/sdm660/dts'
    output = Path.cwd() / 'dts/whyred.dtb'
    output.parent.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        [dtc, '-I', 'dts', '-O', 'dtb', '-i', str(include), '-o', str(output), str(source)],
        text=True, capture_output=True)
    if result.returncode != 0:
        sys.exit(f'build-whyred-dtb: dtc failed:\n{result.stderr}')
    if result.stderr.strip():
        sys.exit(f'build-whyred-dtb: dtc warnings:\n{result.stderr}')
    if not output.is_file() or output.stat().st_size == 0:
        sys.exit(f'build-whyred-dtb: {output} was not written')
    print(f'build-whyred-dtb: {output} ({output.stat().st_size} bytes)')


if __name__ == '__main__':
    main()
