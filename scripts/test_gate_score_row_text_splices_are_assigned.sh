#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_text_splices_are_assigned.sh -- STATIC GATE (hq_T, on coo's measurement 2026-09-08).
# ⛔⭐ THE DEFECT: a runner splices ${VAR:+ ... } into the --text it hands util_score_row.py, and never assigns
# VAR.  test_snobol4_gimpel_suite.sh did exactly that with INV_LINE -- it called inventory_line for its stdout and
# threw it away -- so the vendor text carried no PACKAGE_INVENTORY clause, the writer REFUSED rc=2 on EVERY run,
# and that row could only ever be set by hand.  Three seats hit it the same evening (hq_C, the cto, the coo).
# ⭐ WHY IT SURVIVED, and this is the reusable half: `${VAR:+...}` is SILENT ON AN UNSET VARIABLE BY DESIGN.  The
# one construct that would have named the missing piece is the construct that guarantees nothing is named -- it
# expands to the empty string and the line stays well-formed.  The refusal that DID fire named the missing CLAUSE,
# which is one level away from the missing ASSIGNMENT, and three readers stopped at the level they were shown.
# ⛔ IT ASSERTS A STATIC PROPERTY AND RUNS NOTHING: no build, no suite, no oracle.  A gate that had to run the
# suite to find this would cost twenty minutes to learn something `grep` can prove in under a second.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -d "$HERE" ] || { echo "⛔ GATE REFUSES (rc=2): cannot resolve the scripts directory."; exit 2; }
python3 - "$HERE" <<'PY'
import re, sys, pathlib
d = pathlib.Path(sys.argv[1])
files = sorted(d.glob("*.sh"))
if not files:
    print("⛔ GATE REFUSES (rc=2): no *.sh under %s -- graded nothing." % d); sys.exit(2)
# a script is in scope only if it actually writes a leaderboard row; everything else may splice what it likes.
# ⛔ EXCLUDE THIS FILE. It names util_score_row.py in its own diagnostics, so without this it grades ITSELF into
# scope -- harmless to the verdict (it passes no --text) but it makes the REFUSAL arms lie about which shape they
# met, and a refusal that misnames its own cause is the thing this whole family of gates exists against.
scope = [f for f in files if f.name != "test_gate_score_row_text_splices_are_assigned.sh"
         and "util_score_row.py" in f.read_text(errors="replace")]
if not scope:
    print("⛔ GATE REFUSES (rc=2): no script under %s calls util_score_row.py -- the writer moved and this gate is grading nothing." % d); sys.exit(2)
SPLICE = re.compile(r'\$\{([A-Za-z_][A-Za-z0-9_]*):\+')
bad, graded, spliced = [], 0, 0
for f in scope:
    txt = f.read_text(errors="replace")
    # only the --text argument matters: that string is what the writer parses and refuses over.
    texts = [m.group(0) for m in re.finditer(r'--text\s+"(?:[^"\\]|\\.)*"', txt)]
    if not texts: continue
    graded += 1
    for t in texts:
        for var in set(SPLICE.findall(t)):
            spliced += 1
            # assigned anywhere in this file: at a line start (indented too -- a function body's own assignment, the coo 2026-10-10:
            # lib_container_package_runner.sh's `  inv="$(inventory_line ...)"` read as never assigned), after a separator, or via
            # export/local/read.
            if re.search(r'(?m)(^\s*|[;&|(]\s*|^\s*(export|local|declare|typeset)\s+)%s=' % re.escape(var), txt): continue
            if re.search(r'(?m)^\s*(read|for)\b[^\n]*\b%s\b' % re.escape(var), txt): continue
            bad.append("  %s: --text splices ${%s:+...} and this file never assigns %s.  The splice is SILENT on an unset "
                       "variable, so the clause simply vanishes and util_score_row.py refuses the write on every run -- "
                       "the row can then only be set by hand.  Cure: capture the value into %s where it is produced "
                       "(the sibling runners' two lines), or delete the splice." % (f.name, var, var, var))
if graded == 0:
    print("⛔ GATE REFUSES (rc=2): found row-writing scripts but none passes a --text argument -- graded zero."); sys.exit(2)
if bad:
    print("⛔ GATE FAIL: %d unassigned splice(s) in the --text of a leaderboard row writer:" % len(bad))
    print("\n".join(sorted(bad))); sys.exit(1)
print("✅ GATE OK: %d splice(s) across %d row-writing script(s) are all assigned in their own file." % (spliced, graded))
PY
