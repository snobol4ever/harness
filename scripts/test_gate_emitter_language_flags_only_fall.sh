#!/usr/bin/env bash
# test_gate_emitter_language_flags_only_fall.sh -- LANGUAGE IDENTITY STOPS AT LOWER, AS A RATCHET (ceo CEO-1836; Lon 2026-10-18 14:0x
# CDT, in-chat to the ceo, verbatim: "How much of the emitter is language specific? Did you know that is not allowed past the lower
# stage. Will you fix that?"). The law (RULES.md, Language identity stops at lower; test_gate_emit_no_lang.sh) bans the OLD
# identifiers -- g_lang, LANG_, IR_LANG_ -- and that gate reads green; the language came back past lower under NEW names: graph
# flags the lowerer sets for one language and the emitter and templates then branch on. Measured at SCRIP 2d7ed9a37: 141 reads of
# six such flags in src/emitter and src/templates (icn_cells_graph 69, zframe_graph 30, emit_pl_frame 23, icn_retain 7,
# zls_g_pl_frame 7, pl_frame 5), 292 of the 655 language-named code lines in emit.cpp alone.
#
# THIS GATE counts every live CODE read of a banned flag (comments and string literals stripped) under src/emitter and
# src/templates, per flag, against FLOOR below. RED when any flag reads above its floor (a new language branch past lower);
# GREEN at or below. A floor may only FALL: the landing that removes reads lowers the floor in the same push. The campaign that
# takes every floor to 0 replaces each flag with the behaviour fact it stands for, set by LOWER as IR (ARCH-ZETA-ONE-COORDINATE.md
# section 7); when a flag reads 0 it moves to test_gate_emit_no_lang.sh's banned list and leaves this table.
# rc 0 green, rc 1 a flag above its floor, rc 2 cannot measure (no SCRIP beside harness, or fewer than 100 source files).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
python3 - "$SCRIP" <<'PYEOF'
import re, sys, glob, os
root = sys.argv[1]
FLOOR = {"icn_cells_graph": 68, "zframe_graph": 30, "emit_pl_frame": 23, "icn_retain": 7, "zls_g_pl_frame": 7, "pl_frame": 5}
files = []
for pat in ("src/emitter/*.cpp", "src/emitter/*.h", "src/templates/**/*.cpp", "src/templates/**/*.h", "src/templates/**/*.inc"):
    files += glob.glob(os.path.join(root, pat), recursive=True)
if len(files) < 100:
    print("REFUSE(2): examined %d emitter/template files, fewer than 100 -- an empty tree must not read as clean" % len(files)); sys.exit(2)
def strip(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S); s = re.sub(r"//[^\n]*", "", s); return re.sub(r'"(\\.|[^"\\])*"', '""', s)
count = {k: 0 for k in FLOOR}
where = {k: {} for k in FLOOR}
for f in files:
    s = strip(open(f, encoding="utf-8", errors="replace").read())
    for k in FLOOR:
        n = len(re.findall(r"\b%s\b" % k, s))
        if n: count[k] += n; where[k][os.path.relpath(f, root)] = n
red = 0
for k in FLOOR:
    over = count[k] > FLOOR[k]
    red |= over
    top = ", ".join("%s %d" % (p, n) for p, n in sorted(where[k].items(), key=lambda x: -x[1])[:3])
    print("EMIT_LANG_FLAG flag=%s reads=%d floor=%d%s  [%s]" % (k, count[k], FLOOR[k], " ABOVE-FLOOR" if over else "", top))
total = sum(count.values())
print("EMIT_LANG_FLAG_TOTAL reads=%d floor=%d files=%d" % (total, sum(FLOOR.values()), len(files)))
if red:
    print("GATE RED [emitter_language_flags_only_fall]: a language flag is read in a new place past lower -- branch on an IR fact the lowerer sets, never on the language that produced the graph"); sys.exit(1)
print("GATE OK [emitter_language_flags_only_fall]: no language flag gained a reader; lower a floor in the landing that removes reads")
PYEOF
