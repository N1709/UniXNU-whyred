#!/usr/bin/env python3
"""Check every patch in this repository for a hunk header that lies.

`arm64-nonapple-kpc-stub.patch` declared `+1,183` while carrying 189 added
lines. `git apply` reads exactly the declared count and silently ignores the
rest, so the file appeared in the tree, compiled, and was missing only the last
symbol it was added for: the link then reported `_kpc_pc_capture` undefined
with no hint that six patch lines had been dropped. A wrong count is therefore
worse than a corrupt patch, because the tree looks right.

Every hunk must state the number of context, removed and added lines that
follow it. Run from the repository root, or pass the directories to scan.
"""
import re
import sys
from pathlib import Path

HUNK = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')


def check(path):
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    problems = []
    index = 0
    while index < len(lines):
        match = HUNK.match(lines[index])
        if not match:
            index += 1
            continue
        old = int(match.group(2) or 1)
        new = int(match.group(4) or 1)
        seen_old = seen_new = 0
        cursor = index + 1
        while cursor < len(lines):
            line = lines[cursor]
            if (line.startswith('@@') or line.startswith('diff --git') or
                    (line.startswith('--- ') and cursor + 1 < len(lines) and
                     lines[cursor + 1].startswith('+++ '))):
                break
            if line.startswith('+'):
                seen_new += 1
            elif line.startswith('-'):
                seen_old += 1
            elif line.startswith(' ') or line == '':
                seen_old += 1
                seen_new += 1
            else:
                break
            cursor += 1
        if (seen_old, seen_new) != (old, new):
            problems.append(
                f'{path}:{index + 1}: header says -{old} +{new}, body has '
                f'-{seen_old} +{seen_new}')
        index = cursor
    return problems


def main(argv):
    default = Path(__file__).resolve().parents[1] / 'patches'
    roots = [Path(argument) for argument in argv[1:]] or [default]
    files = sorted({path for root in roots
                    for path in (root.rglob('*.patch') if root.is_dir()
                                 else [root])})
    if not files:
        raise SystemExit('check-patches: no patches found')
    problems = [problem for path in files for problem in check(path)]
    for problem in problems:
        print(problem)
    if problems:
        raise SystemExit('check-patches: a hunk header does not match its body; '
                         'git apply would silently drop the extra lines')
    print(f'check-patches: {len(files)} patches, every hunk count exact')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
