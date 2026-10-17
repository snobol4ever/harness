#!/usr/bin/env python3
"""build_stno_map.py — build stno -> (file, lineno, text) map from a SNOBOL4 source file.

Processes -INCLUDE directives inline (same as SPITBOL) to produce a JSON map.
Rules matching SPITBOL's stno counting:
  - Comment lines (first non-space char is '*') -> skip (no stno)
  - Directive lines (start with '-') -> skip (no stno)
  - All other lines (including blank lines) -> increment stno

Usage:
    python3 build_stno_map.py <file.sno> [include_dir ...] > stno_map.json
    python3 build_stno_map.py <file.sno> --out stno_map.json [include_dir ...]

Output JSON: {"1": ["file.sno", 8, "START"], "2": ["global.inc", 5, "..."], ...}
"""

import json
import os
import sys


def parse_file(path, include_dirs, stno_map, visited=None):
    if visited is None:
        visited = set()
    real = os.path.realpath(path)
    if real in visited:
        return  # guard against recursive includes
    visited.add(real)

    src_dir = os.path.dirname(os.path.abspath(path))
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except OSError as e:
        print(f'[stno_map] WARNING: cannot open {path}: {e}', file=sys.stderr)
        return

    stno = stno_map['_stno']
    fname = os.path.basename(path)

    for lineno, line in enumerate(lines, 1):
        text = line.rstrip('\n')
        stripped = text.lstrip()

        # Comment line — no stno, no action
        if stripped.startswith('*'):
            continue

        # -INCLUDE directive — recurse, no stno for the directive itself
        if text.startswith('-INCLUDE') or (stripped.startswith('-') and 'INCLUDE' in stripped[:12]):
            # Extract filename from -INCLUDE 'name' or -INCLUDE "name"
            import re
            m = re.search(r"""['"](.*?)['"]""", text)
            if m:
                inc_name = m.group(1)
                # Search: source dir first, then include_dirs
                for d in [src_dir] + list(include_dirs):
                    candidate = os.path.join(d, inc_name)
                    if os.path.isfile(candidate):
                        # Save/restore stno via shared dict
                        stno_map['_stno'] = stno
                        parse_file(candidate, include_dirs, stno_map, visited)
                        stno = stno_map['_stno']
                        break
            continue

        # Any other directive line — skip, no stno
        if text.startswith('-'):
            continue

        # Regular line (including blank) — increment stno
        stno += 1
        stno_map[str(stno)] = [fname, lineno, text]

    stno_map['_stno'] = stno


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)

    out_path = None
    if '--out' in args:
        i = args.index('--out')
        out_path = args[i + 1]
        args = args[:i] + args[i+2:]

    sno_file = args[0]
    include_dirs = args[1:]

    stno_map = {'_stno': 0}
    parse_file(sno_file, include_dirs, stno_map)
    del stno_map['_stno']

    result = json.dumps(stno_map, ensure_ascii=False)
    if out_path:
        with open(out_path, 'w') as f:
            f.write(result)
        print(f'[stno_map] wrote {len(stno_map)} entries to {out_path}', file=sys.stderr)
    else:
        print(result)


if __name__ == '__main__':
    main()
