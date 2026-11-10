#!/usr/bin/env python3
"""Record every XNU compile as <object>.json, then run the compiler.

XNU's makedefs set

    KCC  = $(CCACHE) $(CC)

and leave CCACHE to the build that drives it. The archive builders in this
repository (build-mockfs-fixture.py, build-libpthread-kernel.py, the storage and
AES bindings) do not read the whole compile_commands.json: each one re-runs a
single compile from the record that sits next to that object, with the exact
flags the kernel used. Nothing in the UniXNU revision this board pins writes
those records, so the bootstrap pass stopped at the link with vfs_conf.o
referencing mockfs and no archive builder able to compile the mockfs fixture.

CMake-style compile_commands.json entries are the format those builders read:
directory, file and the full argument vector as one transaction, so the
record is written next to the object before the compiler runs.

Usage (the kernel build does this itself through the imported CCACHE variable):

    CCACHE=/path/to/compile-records.py bash scripts/build-xnu-4k-baseline.sh
"""
import json
import os
import sys

SOURCE_SUFFIXES = ('.c', '.cc', '.cpp', '.cxx', '.m', '.mm')


def source_argument(args):
    """The compiled translation unit: the last non-option argument with a C suffix."""
    found = None
    skip = False
    for value in args:
        if skip:
            skip = False
            continue
        if value in ('-o', '-MF', '-MT', '-MQ', '-include', '-imacros', '-isystem',
                     '-I', '-D', '-U'):
            skip = True
            continue
        if value.startswith('-'):
            continue
        if value.endswith(SOURCE_SUFFIXES):
            found = value
    return found


def object_argument(args, source):
    """The output path, made explicit when the invocation leaves it implicit."""
    for index, value in enumerate(args):
        if value == '-o' and index + 1 < len(args):
            return args[index + 1], args
        if value.startswith('-o') and len(value) > 2:
            return value[2:], args
    name = os.path.basename(source)
    name = name[:name.rfind('.')] + '.o'
    return name, args + ['-o', name]


def main(argv):
    if len(argv) < 2:
        raise SystemExit('usage: compile-records.py COMPILER [ARGS...]')
    compiler = argv[1]
    args = argv[2:]
    if '-c' not in args:
        os.execv(compiler, [compiler] + args)
    source = source_argument(args)
    if source is None:
        os.execv(compiler, [compiler] + args)
    target, args = object_argument(args, source)
    if not os.path.isabs(target):
        target = os.path.join(os.getcwd(), target)
    record = {
        'directory': os.getcwd(),
        'file': source,
        'arguments': [compiler] + args,
    }
    os.makedirs(os.path.dirname(target) or '.', exist_ok=True)
    with open(target + '.json', 'w', encoding='utf-8') as stream:
        json.dump(record, stream)
        stream.write('\n')
    os.execv(compiler, [compiler] + args)


if __name__ == '__main__':
    main(sys.argv)
