#!/usr/bin/env bash
# ../harness/scripts/test_gate_score_inventory_clauses_never_vanish.sh -- NO PACKAGE EVER LOSES ITS PACKAGE_INVENTORY
# CLAUSE FROM SCORE.md, BY ANY PATH.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-08
#
# ⛔⭐⭐ THE FAILURE IS INVISIBLE, WHICH IS THE WHOLE REASON THIS EXISTS. util_score_row.py's
# inventory_clauses() keeps the LAST `PACKAGE_INVENTORY package=X shipped= graded= ungraded= ungradable=`
# clause per package and feeds the September-10 progress readers their GRADED POPULATION. A dropped clause
# therefore DOES NOT READ AS MISSING: the package silently stops contributing a population, and the
# percentage above it still prints, confidently and wrongly. Absence and correctness look identical.
#
# TWO OCCURRENCES, TWO CANDIDATE PATHS, AND NEITHER REPORTER OVERCLAIMED (this is why it is a gate and not
# a fix): hq_C measured `package=gimpel` present at .github 932016de and absent immediately after its row
# closed, with every other package in the SAME cell intact -- then read origin and RETRACTED its own
# diagnosis, because hq_V had independently pushed 1540781a describing the identical shape on snoflake and
# attributing it to a CONFLICT RESOLUTION. One occurrence each, and hq_C's had been through several
# conflicted rebases of SCORE.md before anyone looked. ⭐ Two mechanisms that produce one symptom cannot be
# told apart by the symptom -- so this gate does not try. It asserts the OUTCOME, and it is blind to route.
#
# ⭐ WHY A PINNED FLOOR AND NOT A BEFORE/AFTER DIFF. The in-process guard in util_score_row.py
# (_write_score_md) already refuses a write that drops a key -- but it can only see writes THROUGH that
# tool, and the one path actually confirmed tonight was a git rebase, which never runs it. A floor in a
# gate is route-independent: hand edit, conflicted merge, `done` hook, or a future writer nobody has
# written yet all land the same way.
#
# ⛔ THE FLOOR ONLY EVER GROWS. A package appearing is normal and re-pins here. A package DISAPPEARING is
# the defect, and raising the floor to make this gate pass is the one edit that voids it -- if a package is
# genuinely retired, that is a ruling, and the ruling removes it from this list in the same commit that
# removes it from the corpus.
# EXIT: 0 every pinned package still carries a clause · 1 one or more vanished · 2 REFUSED (no SCORE.md).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="test_gate_score_inventory_clauses_never_vanish"
gate_parse_args "$@"

S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCORE="$S4E/.github/SCORE.md"
[ -f "$SCORE" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no SCORE.md at $SCORE -- nothing to measure"; gate_stamp; exit 2; }

# ⛔ THE PINNED SET -- measured 2026-09-08 by hq_T at .github 79aa7dda. Grows only.
PINNED="arizona csnobol4 dotnet fpc gimpel gnu_prolog ipl pat snoflake_suite spitbol_testpgms"

present=$(grep -oE 'PACKAGE_INVENTORY[[:space:]]+package=[A-Za-z0-9_./-]+' "$SCORE" | sed 's/.*package=//' | sort -u)
# ⛔ ZERO CLAUSES IS A REFUSAL, NOT A CLEAN RUN -- an empty haystack would report every pinned package
# missing, which is a different (and louder) fact than the one this gate grades, and it usually means the
# grep or the file shape moved rather than that ten packages vanished at once.
n_present=$(printf '%s\n' "$present" | grep -c . || true)
[ "$n_present" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: SCORE.md carries ZERO PACKAGE_INVENTORY clauses -- the file or the clause format moved; this gate cannot grade that and will not report it as ten losses"; gate_stamp; exit 2; }

missing=""
for p in $PINNED; do
  printf '%s\n' "$present" | grep -qx "$p" || missing="$missing $p"
done
GATE_EXAMINED="$n_present package clause(s) against $(printf '%s' "$PINNED" | wc -w) pinned"

echo "INVENTORY CLAUSES present: $(printf '%s' "$present" | tr '\n' ' ')"
n_missing=$(printf '%s' "$missing" | wc -w)
if [ "$n_missing" -gt 0 ]; then
  echo "⛔ VANISHED:$missing"
  echo "   A package with no PACKAGE_INVENTORY clause does not read as missing -- inventory_clauses() simply"
  echo "   has no entry for it, so it contributes NO graded population and the percentage above it still prints."
  echo "   Cure: re-run the runner that measured it and land that board line. Do NOT re-type the digits --"
  echo "   a clause restored by hand is a number nobody measured, stamped current by the run that restored it."
fi
extra=""
for p in $present; do
  printf '%s\n' $PINNED | grep -qx "$p" || extra="$extra $p"
done
[ -n "$extra" ] && echo "⭐ NEW package(s) present and not yet pinned:$extra -- re-pin PINNED in this commit (the floor only grows)."
gate_verdict "$n_missing" "pinned package(s) whose PACKAGE_INVENTORY clause has vanished from SCORE.md"
