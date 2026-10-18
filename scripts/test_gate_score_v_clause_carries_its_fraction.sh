#!/usr/bin/env bash
# test_gate_score_v_clause_carries_its_fraction.sh -- the invariant gate for the V-cell CLAUSE
# TRUNCATION class (row score-v-clause-truncation-publishes-a-graded-package-as-ungraded, hq_T
# 2026-09-05; standing rule recorded as ceo CEO-297, "IN A PACKAGE CLAUSE, THE FRACTION LEADS").
#
# WHAT IT PROTECTS. The PROGRESS percent reads the September-10 grid's V column only, and
# util_score_row.py's counted_fractions() reads each package BY CLAUSE: from the package's name to
# the first ` · `, ` -- ` or `; ` after it. A clause with no countable fraction inside that window
# scores ZERO OF THE PACKAGE'S WHOLE POPULATION, visible only under `progress --verbose` -- so a
# cell that is merely WRITTEN WELL (the leaderboard doctrine invites provenance and explanation in a
# cell) publishes a confidently wrong headline the moment that explanation lands BEFORE the number.
#
# MEASURED WITNESS (hq_T, 2026-09-05 18:26-18:34 CDT): folding a fresh INRIA reading into the prolog
# V cell, an em-dash landed before the number, INRIA read NOT YET RUN-GRADED at zero of 445, and the
# board published pl 12% when the truth was 60% (ALL 13% vs 22%) for eight minutes. Same class as
# the snoflake incident already recorded in util_score_row.py (103/180 published as 0/180). Two more
# instances were live when this row was minted and are reconciled by this same landing: prolog `gnu`
# (measured in prose -- "9 of 10 runnable" -- never a slash-fraction, and stale against a fresh
# re-confirmation) and pascal `PAT` (the grid clause flatly asserted "NOT VENDORED, NO RUNNER" while
# the standardized display carried a clean, current 298/427 · 284/427). A fourth, snobol4 `csnobol4`,
# surfaced only once the instrument existed: a real, both-tables-agreed 60/119 · 59/119 sat one
# middot past `total=119`, and PROGRESS_COUNTED's declared populations had not caught up to 119
# either. A fifth, icon `ipl`, was found and cured independently by hq_T in the same window (fold
# icon 96de7361) -- this gate proves it stayed cured, not that it fixed it.
#
# THE INSTRUMENT ITSELF is util_score_row.py's clause_fraction_audit()/`clause-check` subcommand: for
# every package PROGRESS_COUNTED lists, it asks whether counted_fractions' narrow clause window
# genuinely found nothing, or whether a countable `pass/total` fraction exists for that package
# EITHER wider in the same grid cell (past the separator the narrow reader stops at) OR in the
# package's standardized-display twin -- the three-way discipline this project uses everywhere else
# (lib_gate.sh's own three exit codes; counted_fractions' own FOUND/UNREADABLE/ABSENT split) applied
# to this one question: is a zero here GENUINE (stays quiet, no conviction) or a zero the clause
# window was BLINDSIDED into (convicted, named, quoted, with the percent the language would read once
# the clause carries what already exists elsewhere)? ⛔ It REFUSES rc=2 -- die()'s own contract, the
# same one find_grid/find_table use everywhere -- when it cannot read the September-10 grid's row for
# a language PROGRESS_COUNTED lists, rather than reporting CLEAN over a partial read (the vacuous-gate
# class cmd_agree's own header names).
#
# Usage: bash ../harness/scripts/test_gate_score_v_clause_carries_its_fraction.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

HELPER="$HERE/util_score_row.py"
gate_require "$HELPER" "the one leaderboard helper util_score_row.py"
gate_require "$ROOT/../.github/SCORE.md" "the ONE LEADERBOARD .github/SCORE.md"

violations=0
examined=0

# ARM 1 -- the live board, graded exactly as PROGRESS reads it: every package PROGRESS_COUNTED
# lists, checked for a fraction hiding past the clause window it currently reads by.
examined=$((examined + 1))
out="$(python3 "$HELPER" clause-check 2>&1)"; rc=$?
echo "$out" | sed 's/^/    /'
case "$rc" in
    0) ;;
    1) violations=$((violations + 1)) ;;
    2) echo "GATE UNPROVEN(2) [test_gate_score_v_clause_carries_its_fraction]: clause-check could not read the grid or display -- see refusal above, this is NOT a pass"
       gate_stamp
       exit 2 ;;
    *) echo "GATE FAIL: util_score_row.py clause-check exited $rc (expected 0, 1 or 2)"
       violations=$((violations + 1)) ;;
esac

# ARM 2 -- the instrument itself must actually be selective, not a gate that only ever prints CLEAN.
# Proven on a SCRATCH grid text, never the real board: a hand-built cell whose narrow clause reads
# zero while its wide window (past a middot) and its display twin each carry a findable fraction must
# convict both, and a genuinely-nowhere-graded package must stay quiet. This is the same discipline
# test_gate_score_row_rewrites_in_place.sh applies to cmd_write -- a helper proven only against
# whatever the live board happens to contain today has never been proven at all.
examined=$((examined + 1))
selftest_out="$(python3 - "$HELPER" <<'PYEOF'
import sys
sys.path.insert(0, __import__("os").path.dirname(sys.argv[1]))
import util_score_row as u

PC = {"t": [("alpha", r"alpha", (50,)), ("beta", r"beta", (9,)), ("gamma", r"gamma", (7,))]}
u.PROGRESS_COUNTED = PC

# alpha: narrow clause genuinely empty, but a real 40/50 sits past a middot -- CONVICT.
grid_v = "alpha explanation first, no digit before the separator here · 40/50 (m3,m4) · beta 9/9 both modes · gamma reads honestly zero, nothing anywhere for it"
disp_v = "ALPHA: nothing parseable here either; BETA: 9/9; GAMMA: still nothing"
convs = u.clause_fraction_audit("t", grid_v, disp_v)
names = sorted(c["package"] for c in convs)
ok = True
if names != ["alpha"]:
    print("SELFTEST FAIL: expected only alpha convicted on the grid-wide fraction, got %r" % names); ok = False
else:
    print("SELFTEST: alpha correctly CONVICTED on a fraction past its own clause's separator")
    print("SELFTEST: beta correctly stayed CLEAN (FOUND within its narrow clause, nothing to convict)")

# gamma: narrow clause empty AND nothing findable anywhere -- must stay quiet (genuine zero).
grid_v2 = "gamma reads honestly zero, nothing anywhere for it · alpha 1/50 fine here"
convs2 = u.clause_fraction_audit("t", grid_v2, "")
if any(c["package"] == "gamma" for c in convs2):
    print("SELFTEST FAIL: gamma was convicted with no fraction anywhere -- a genuine zero must stay quiet"); ok = False
else:
    print("SELFTEST: gamma correctly stayed QUIET (no fraction anywhere, a genuine zero)")

# delta: only the DISPLAY twin carries the fraction (the pascal PAT shape) -- CONVICT via that source.
PC2 = {"t2": [("delta", r"delta", (12,))]}
u.PROGRESS_COUNTED = PC2
grid_v3 = "delta: NOT VENDORED, NO RUNNER, nothing to see here"
disp_v3 = "DELTA: the real board -- 11/12 both modes, current"
convs3 = u.clause_fraction_audit("t2", grid_v3, disp_v3)
if len(convs3) == 1 and convs3[0]["source"] == "display twin" and convs3[0]["found_pnum"] == 11 and convs3[0]["found_den"] == 12:
    print("SELFTEST: delta correctly CONVICTED via its display twin (11/12), the grid alone had nothing")
else:
    print("SELFTEST FAIL: delta (display-twin-only fraction) was not convicted as expected: %r" % convs3); ok = False

print("SELFTEST OVERALL:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PYEOF
)"
selftest_rc=$?
echo "$selftest_out" | sed 's/^/    /'
if [ "$selftest_rc" -ne 0 ]; then
    echo "GATE FAIL: clause_fraction_audit's own selftest failed -- see SELFTEST lines above"
    violations=$((violations + 1))
fi
for want in "alpha correctly CONVICTED on a fraction past its own clause's separator" \
            "beta correctly stayed CLEAN" \
            "gamma correctly stayed QUIET (no fraction anywhere, a genuine zero)" \
            "delta correctly CONVICTED via its display twin"; do
    examined=$((examined + 1))
    case "$selftest_out" in
        *"$want"*) ;;
        *) echo "GATE FAIL: the selftest never proved: $want"; violations=$((violations + 1)) ;;
    esac
done

# ARM 3 -- THE REAL INCIDENT, not a synthetic stand-in: hq_T's own NEXT block for this row asks for
# the broken/cured commit pair as "the regression test this gate deserves". The cited hash
# (d534fb34) resolves in neither repo -- likely mistyped, since the fix landed as an uncommitted
# local edit before its own commit -- so this uses `e71d3210` (the commit that first folded INRIA
# into the grid, em-dash and all: `INRIA ISO 13211-1 -- THE Prolog denominator ...: bindings
# 310/445`) as BROKEN and `8b0c2dd9` (the very next commit, "put the fraction FIRST") as CURED. Same
# incident, same cell, adjacent commits, real history.
examined=$((examined + 1))
GH="$ROOT/../.github"
if [ -d "$GH/.git" ] && git -C "$GH" cat-file -e e71d3210 2>/dev/null && git -C "$GH" cat-file -e 8b0c2dd9 2>/dev/null; then
    hist_out="$(python3 - "$HELPER" "$GH" <<'PYEOF'
import sys, subprocess
sys.path.insert(0, __import__("os").path.dirname(sys.argv[1]))
import util_score_row as u
GH = sys.argv[2]

def cell_at(rev):
    text = subprocess.run(["git", "show", "%s:SCORE.md" % rev], cwd=GH, capture_output=True, text=True).stdout
    lines = text.split("\n")
    _gh, grid, _ = u.find_grid(lines)
    _dh, disp, _ = u.find_table(lines)
    gv = grid["prolog"][u.GRID_COLUMNS["V"][0]]
    dv = disp["prolog"][1][u.COLUMNS["vendor"][0]] if "prolog" in disp else ""
    return gv, dv

ok = True
broken_gv, broken_dv = cell_at("e71d3210")
broken_convs = u.clause_fraction_audit("prolog", broken_gv, broken_dv)
if any(c["package"] == "INRIA" and c["found_pnum"] == 310 and c["found_den"] == 445 for c in broken_convs):
    print("SELFTEST: the REAL e71d3210 incident (em-dash before the INRIA fraction) is correctly CONVICTED (310/445 found past the clause)")
else:
    print("SELFTEST FAIL: e71d3210's INRIA em-dash truncation was NOT convicted: %r" % broken_convs); ok = False

cured_gv, cured_dv = cell_at("8b0c2dd9")
cured_convs = u.clause_fraction_audit("prolog", cured_gv, cured_dv)
if any(c["package"] == "INRIA" for c in cured_convs):
    print("SELFTEST FAIL: 8b0c2dd9's cured INRIA clause was convicted anyway: %r" % cured_convs); ok = False
else:
    print("SELFTEST: the REAL 8b0c2dd9 cure (fraction moved first) correctly reads CLEAN for INRIA")

print("SELFTEST OVERALL:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PYEOF
)"
    hist_rc=$?
    echo "$hist_out" | sed 's/^/    /'
    if [ "$hist_rc" -ne 0 ]; then
        echo "GATE FAIL: the real-incident regression pair (e71d3210/8b0c2dd9) did not behave as expected -- see SELFTEST lines above"
        violations=$((violations + 1))
    fi
    for want in "e71d3210 incident (em-dash before the INRIA fraction) is correctly CONVICTED" \
                "8b0c2dd9 cure (fraction moved first) correctly reads CLEAN"; do
        examined=$((examined + 1))
        case "$hist_out" in
            *"$want"*) ;;
            *) echo "GATE FAIL: the real-incident regression never proved: $want"; violations=$((violations + 1)) ;;
        esac
    done
else
    echo "    ⚠ e71d3210/8b0c2dd9 not both present in $GH -- skipping the real-incident regression pair (synthetic ARM 2 still covers the mechanism; a shallow clone is the usual cause, not a defect)"
fi

GATE_EXAMINED="$examined arms (1 live-board audit + 4 synthetic-selftest properties + the real e71d3210/8b0c2dd9 incident pair)"
gate_verdict "$violations" "a PROGRESS_COUNTED package's V-cell clause reads zero while a countable fraction for it exists in the grid's wider cell or its display twin"
