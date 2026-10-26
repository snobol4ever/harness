#!/usr/bin/env python3
"""util_planner_link_headers.py OBJDIR PLANNER_OBJS_LIST OUT -- the distinct headers under src/emitter/ or src/templates/ that the dependency files (.d) written beside the planner's
objects name (cwd = the SCRIP root, where the .d paths are relative). Writes them one per line to OUT and prints the count. Used by
test_gate_planner_objects_leave_no_emitter_symbol_undefined.sh (its emitter_headers reading); the paths are normalised first because a .d line can name src/planner/../emitter/x.h."""
import os
import sys

objdir, lst, out = sys.argv[1], sys.argv[2], sys.argv[3]
seen = set()
for o in open(lst).read().split():
    d = os.path.join(objdir, os.path.splitext(os.path.basename(o))[0] + '.d')
    if not os.path.exists(d):
        continue
    for tok in open(d).read().replace('\\\n', ' ').split()[1:]:
        if tok.endswith(':'):
            continue
        p = os.path.normpath(tok)
        if os.path.isabs(p):
            p = os.path.relpath(p)
        if p.startswith('src/emitter/') or p.startswith('src/templates/'):
            seen.add(p)
open(out, 'w').write('\n'.join(sorted(seen)) + ('\n' if seen else ''))
print(len(seen))
