#!/usr/bin/env bash
# test_gate_finding_claims_are_folded_before_delete.sh -- A FINDING'S MEASURED CLAIMS SURVIVE ITS DELETION
# (RULES.md line 31; Lon 2026-09-18 in-chat to the cto, verbatim: "You can use as many FINDING files as you want. I'll
# just delete them periodically. We should probably do a summarization when I delete."; ceo CEO-859/861.
# Row: finding-summarization-gate-refuses-to-delete-an-unfolded-cited-finding.)
#
# ⛔ WHAT THIS GATE DOES NOT DO, STATED FIRST BECAUSE IT IS A DESIGN DECISION AND NOT AN OMISSION: it does NOT red on the
# unfolded citer links standing in the tree today.  The gate directly above it in this directory
# (test_gate_findings_live_in_the_findings_directory.sh) was renamed FROM a gate that encoded a rule's POLARITY, and it
# went red in EVERY seat's preflight the moment the law flipped -- a fleet-wide landing block created by a law change.
# The INVARIANT here is not "no unfolded citation exists" (whose cure is another seat's writing, on their schedule); it is
# "no FINDING was DELETED while a live row still cited claims that went with it".  That is naturally zero on a clean tree
# and reds exactly when the damage is done.  The standing links are REPORTED with their count, and the report is not a
# verdict.  ⛔ AND A NATURALLY-ZERO INVARIANT IS THE EASIEST KIND OF VACUOUS GREEN, so arm 10 plants a real deletion in a
# scratch clone and requires the detector to SEE it: without arm 10, arm 9's zero would be indistinguishable from a
# detector that reads nothing.  That is the whole lesson of the ten scripts the cto re-measured at HEAD this morning --
# test_gate_ir_field_discipline scans nothing, prints HARD TOTAL = 0 / PASS, and then recommends tightening the target.
#
# Hermetic: scratch git trees under mktemp, no build, no corpus, no network.  Population printed per arm.
# rc: 0 all arms pass · 1 an arm failed · 2 the harness could not grade (no python3, no sweep, clone failed).
# FAIL_ONCE=1 points the real-tree arm at a scratch clone holding a deleted-unfolded FINDING, proving THIS GATE reds.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
# ⛔ .github IS S4E_HOME's, ELSE THE SIBLING OF THIS CHECKOUT (coo 2026-10-08, CEO-1573): from a worktree under a scratch directory,
# ROOT/.github named a directory that is not there and arm 9 refused (origin/main not resolvable); the seat's own clone resolves it.
SWEEP="$HERE/util_finding_fold_before_delete.sh"; GH="${S4E_HOME:-$ROOT}/.github"
[ -x "$SWEEP" ] || { echo "⛔ REFUSED-TO-GRADE(2): the sweep is missing or not executable: $SWEEP"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE(2): python3 not on PATH"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED-TO-GRADE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ARM $1 PASS -- $2"; }
bad() { fail=$((fail+1)); echo "  ⛔ ARM $1 FAIL -- $2"; }

# ---- fixtures ---------------------------------------------------------------------------------------------------
# The planted FINDING carries three measurement lines whose exact bytes the arms below look for; the planted citer is a
# baton of the shape the postoffice really uses.  MEASURED, not decorative: each claim line carries a digit and clears
# the 24-character floor, so the sweep's own claim rule accepts them.
NAME="FINDING-2099-01-01-fixture-planted-measurements"
mk_tree() { # $1=dir  -- a scratch .github with one FINDING and one citing task dir
  local d="$1"; mkdir -p "$d/gh/findings" "$d/tasks"
  cat > "$d/gh/findings/$NAME.md" <<'EOF'
# FINDING planted fixture
The witness dies at core.c:1987 with rc=139 after 4 collections.
Measured 212 live blocks of kind HB_ARR against 208 before the change, same tree.
The control arm reads 71/72 with OUTSIDE-BASELINE=1 on the named clean tree.
EOF
  cat > "$d/tasks/planted-row.task.md" <<EOF
# TASK planted-row
GOAL: something that cites $NAME as its evidence.
DONE-WHEN: true
## LEDGER
- [coo] the measurement is in $NAME and nowhere else, which is the defect this row exists to make impossible.
EOF
  git -C "$d/gh" init -q 2>/dev/null
  git -C "$d/gh" add -A >/dev/null 2>&1
  git -C "$d/gh" -c user.email=g@g -c user.name=g commit -qm base >/dev/null 2>&1
}
run() { "$SWEEP" --tree "$W/$1/gh" --scrip "$W/$1/nosuchscrip" --tasks "$W/$1/tasks" "${@:2}" 2>&1; }

echo "=== test_gate_finding_claims_are_folded_before_delete"

# ---- ARM 1: THE COVERAGE FLOOR ----------------------------------------------------------------------------------
mkdir -p "$W/empty/gh/findings" "$W/empty/tasks"
git -C "$W/empty/gh" init -q; : > "$W/empty/gh/README.md"
git -C "$W/empty/gh" add -A >/dev/null 2>&1; git -C "$W/empty/gh" -c user.email=g@g -c user.name=g commit -qm e >/dev/null 2>&1
out="$(run empty)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'read nothing is not a zero'; then
  ok 1 "a tree with ZERO FINDING files is rc=2, not 'OK, nothing to fold' (the coverage floor)"
else
  bad 1 "empty tree gave rc=$rc; expected rc=2 with the read-nothing refusal. Output: $out"
fi

# ---- ARM 2: FAIL-ONCE -- THE PLANTED CITED-AND-UNFOLDED DELETE ---------------------------------------------------
mk_tree "$W/a"
out="$(run a --delete "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'REFUSING THE DELETE' && printf '%s' "$out" | grep -q 'planted-row.task.md' \
   && [ -f "$W/a/gh/findings/$NAME.md" ]; then
  ok 2 "a cited-and-unfolded FINDING REFUSES rc=2, NAMES the citing row, and the file is still on disk"
else
  bad 2 "expected rc=2 naming planted-row.task.md with the file surviving; rc=$rc. Output: $out"
fi

# ---- ARM 3: PASS-ONCE -- THE SAME TREE AFTER FOLDING -------------------------------------------------------------
out="$(run a --apply "$NAME")"; rc=$?
[ "$rc" = 0 ] || bad 3a "--apply gave rc=$rc. Output: $out"
out="$(run a --delete "$NAME")"; rc=$?
if [ "$rc" = 0 ] && [ ! -f "$W/a/gh/findings/$NAME.md" ] \
   && grep -q 'The witness dies at core.c:1987 with rc=139 after 4 collections.' "$W/a/tasks/planted-row.task.md"; then
  ok 3 "after --apply the SAME tree deletes rc=0 and the measurement is in the citing baton VERBATIM"
else
  bad 3 "expected rc=0, file gone, claim verbatim in the baton; rc=$rc. Output: $out"
fi

# ---- ARM 4: AN EMPTY MARKER BUYS NOTHING -------------------------------------------------------------------------
mk_tree "$W/b"
printf '\n<!-- FOLDED-FROM: %s -->\n<!-- END-FOLDED-FROM: %s -->\n' "$NAME" "$NAME" >> "$W/b/tasks/planted-row.task.md"
out="$(run b --delete "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'THIN'; then
  ok 4 "a TERMINATED fold block with NOTHING under it still refuses the delete [THIN] -- the marker is not the fold"
else
  bad 4 "an empty fold block was accepted; rc=$rc. Output: $out"
fi

# ---- ARM 5: A PARAPHRASE IS NOT A MEASUREMENT --------------------------------------------------------------------
mk_tree "$W/c"
{ printf '\n<!-- FOLDED-FROM: %s -->\n' "$NAME"
  echo "- the witness crashes after a few collections, roughly 200 blocks, control arm broadly fine"
  echo "- see the FINDING for the 3 exact numbers"
  echo "- summarised on 2099-01-01 by a seat in a hurry"
  printf '<!-- END-FOLDED-FROM: %s -->\n' "$NAME"; } >> "$W/c/tasks/planted-row.task.md"
out="$(run c --delete "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'THIN'; then
  ok 5 "three PARAPHRASED lines do not fold a measurement -- only bytes verbatim from the FINDING count"
else
  bad 5 "a paraphrase was accepted as a fold; rc=$rc. Output: $out"
fi

# ---- ARM 6: THE UNTERMINATED BLOCK IS NEVER A GENEROUS WINDOW (CEO-860) -------------------------------------------
mk_tree "$W/d"
{ printf '\n<!-- FOLDED-FROM: %s -->\n' "$NAME"
  echo "The witness dies at core.c:1987 with rc=139 after 4 collections."
  echo "Measured 212 live blocks of kind HB_ARR against 208 before the change, same tree."
  echo "The control arm reads 71/72 with OUTSIDE-BASELINE=1 on the named clean tree."; } >> "$W/d/tasks/planted-row.task.md"
out="$(run d --delete "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'UNTERMINATED'; then
  ok 6 "an UNTERMINATED fold block is RED even though all three claims sit under it -- no line-count window (CEO-860)"
else
  bad 6 "an unterminated block was accepted or misdiagnosed; rc=$rc. Output: $out"
fi

# ---- ARM 7: A FINDING NOTHING CITES IS FREE TO GO ----------------------------------------------------------------
mk_tree "$W/e"
# ⛔ NOT `rm` THE CITER: the first cut of this arm deleted it, the scan then read ZERO files, and the sweep REFUSED
# rc=2 rather than reporting "uncited" -- which is the tool being RIGHT and the fixture being wrong.  An index built
# from nothing cannot tell an uncited FINDING from an unscanned tree, and certifying a delete off that distinction is
# exactly the vacuous green this gate exists to refuse.  So the arm leaves a live row that simply does not cite it.
cat > "$W/e/tasks/planted-row.task.md" <<'EOF2'
# TASK planted-row
GOAL: a live row that cites no FINDING at all, so the scan has 1 file to read and still finds 0 citations.
DONE-WHEN: true
EOF2
out="$(run e --delete "$NAME")"; rc=$?
if [ "$rc" = 0 ] && [ ! -f "$W/e/gh/findings/$NAME.md" ] && printf '%s' "$out" | grep -q 'citers: NONE'; then
  ok 7 "an UNCITED FINDING deletes rc=0 -- the gate is a fold check, not a blanket refusal to ever delete"
else
  bad 7 "an uncited FINDING was blocked; rc=$rc. Output: $out"
fi

# ---- ARM 11: A TRUNCATED CITATION IS STILL A CITATION -------------------------------------------------------------
# ⛔ THIS ARM EXISTS BECAUSE THE FIRST CUT OF THE SWEEP SHIPPED THE BUG IT TESTS FOR, AND THE TREE HAD A LIVE INSTANCE.
# The exact-name index read RULES.md -- which cites the cto's 2026-09-18 FINDING under a name cut short by a line wrap --
# as a NON-citer, and reported that FINDING "cited by nothing -- free to delete".  For this tool the reader's failure
# mode is a SILENT ALLOW: it does not print a wrong number, it hands back permission to destroy a measurement.  Measured
# over the live tree: 724 cited names match no path at all, and 358 of them are a proper prefix of a real deleted one.
mk_tree "$W/h"
# the ONLY citation in this row is cut off mid-name, exactly as a wrapped prose mention is
python3 - "$W/h/tasks/planted-row.task.md" "$NAME" <<'EOF2'
import sys
open(sys.argv[1], "w").write(
    "# TASK planted-row\nGOAL: cites the finding by a name a line wrap cut short.\nDONE-WHEN: true\n"
    "## LEDGER\n- [coo] the evidence is in %s...\n" % sys.argv[2][:40])
EOF2
out="$(run h --delete "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'cites it as'; then
  ok 11 "a TRUNCATED mention of the name still blocks the delete and the sweep prints the spelling it matched"
else
  bad 11 "a truncated citation was read as no citation -- the silent allow; rc=$rc. Output: $out"
fi

# ---- ARM 8: --apply NEVER WRITES AN EMPTY FOLD -------------------------------------------------------------------
mk_tree "$W/f"
printf '# FINDING with no measurements\nThis file argues a position and measures nothing at all.\n' > "$W/f/gh/findings/$NAME.md"
git -C "$W/f/gh" add -A >/dev/null 2>&1; git -C "$W/f/gh" -c user.email=g@g -c user.name=g commit -qm n >/dev/null 2>&1
out="$(run f --apply "$NAME")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'ZERO claim lines'; then
  ok 8 "--apply on a FINDING with ZERO claim lines REFUSES rc=2 rather than writing a marker over nothing"
else
  bad 8 "an empty fold would have been written; rc=$rc. Output: $out"
fi

# ---- ARM 10 (before 9, because 9's zero is only worth what 10 proves): THE DELETION DETECTOR SEES A DELETION ------
mk_tree "$W/g"
BASE="$(git -C "$W/g/gh" rev-parse HEAD)"
git -C "$W/g/gh" rm -q "findings/$NAME.md" >/dev/null 2>&1
git -C "$W/g/gh" -c user.email=g@g -c user.name=g commit -qm "delete the finding, fold nothing" >/dev/null 2>&1
out="$("$SWEEP" --tree "$W/g/gh" --scrip "$W/g/nosuchscrip" --tasks "$W/g/tasks" --deleted-since "$BASE" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'DELETIONS EXAMINED: 1' && printf '%s' "$out" | grep -q 'were DELETED with claims still cited'; then
  ok 10 "a FINDING deleted in a landing with its claims still cited is caught rc=1, recovered from history and named"
else
  bad 10 "the deletion detector did not fire; rc=$rc. Output: $out"
fi

# ---- ARM 9: THE REAL TREE ----------------------------------------------------------------------------------------
TARGET_GH="$GH"; TARGET_BASE="origin/main"
if [ -n "${FAIL_ONCE:-}" ]; then TARGET_GH="$W/g/gh"; TARGET_BASE="$BASE"; fi
if ! git -C "$TARGET_GH" rev-parse --verify -q "$TARGET_BASE" >/dev/null; then
  echo "  ⛔ ARM 9 REFUSED(2) -- $TARGET_BASE is not resolvable in $TARGET_GH; cannot grade this landing's deletions"
  echo "population: $((pass+fail)) arm(s) run, $pass pass, $fail fail"; exit 2
fi
if [ -n "${FAIL_ONCE:-}" ]; then
  out="$("$SWEEP" --tree "$TARGET_GH" --scrip "$W/g/nosuchscrip" --tasks "$W/g/tasks" --deleted-since "$TARGET_BASE" 2>&1)"; rc=$?
else
  out="$("$SWEEP" --deleted-since "$TARGET_BASE" 2>&1)"; rc=$?
fi
echo "$out" | sed -n '1,3p;$p' | sed 's/^/    /'
if [ "$rc" = 0 ]; then
  ok 9 "this landing deleted no FINDING that a live row still cites (detector proven by arm 10)"
else
  bad 9 "a FINDING was deleted with its claims still cited by a live row -- fold them IN THIS LANDING (rc=$rc)"
fi

# ---- the standing report, which is NOT a verdict ------------------------------------------------------------------
if [ -z "${FAIL_ONCE:-}" ]; then
  rep="$("$SWEEP" 2>&1 | tail -1)"
  echo "  REPORT (not a verdict, see the header): $rep"
fi

echo "population: $((pass+fail)) arm(s) run, $pass pass, $fail fail"
if [ "$fail" -gt 0 ]; then
  echo "⛔ GATE RED [finding_claims_are_folded_before_delete]: $fail arm(s) failed"; exit 1
fi
echo "GATE PASS [finding_claims_are_folded_before_delete]: $pass arm(s), the sweep is proven able to REFUSE and to PASS on the same tree"
