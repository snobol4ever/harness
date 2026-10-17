#!/usr/bin/env bash
# test_gate_a_rungs_with_xfails_never_reads_done.sh
# (coo 2026-09-08, ceo CEO-416, on Lon's FACT RULE of 2026-09-03: "there is no such thing now as
#  XFAIL. We are shooting for 100%.")
#
# ⛔ AN XFAIL COUNTS AS A FAIL, SO A RUNGS CARRYING ONE IS NOT DONE HOWEVER ITS FRACTION READS.
# THE DEFECT, and the coo walked into it before the ruling: the SNOBOL4 rungs row read 1894/1894
# FAIL=0 and the banner printed it ✅ done, while 27 known-red entries sat OUTSIDE BOTH SIDES of that
# fraction. Dropping a red from the numerator AND the denominator renders it as if it did not exist --
# wrong in the flattering direction, on the row Lon's 100% question gets answered from. Three seats
# rendered that row four different ways in one evening and every one of them printed "done".
#
# ⭐ THIS GATE IS DELIBERATELY INDEPENDENT OF WHICH FRACTION THE ROW CARRIES. The convention question
# (1871/1898 vs 1898/1898 vs 1894/1894) is the ceo's to settle and was still open when this landed;
# what is NOT open is that a suite with a live xfail must never render as finished. So the arms assert
# the DONE VERDICT, never the numbers -- a gate that pinned the fraction would have to be rewritten by
# whichever way the ruling went, and would have been wrong in the meantime.
#
# HERMETIC: scratch SUITES.tsv + corpus tree under mktemp, via S4E_SUITES_TSV. The real records are
# never opened for writing, asserted by arm 4.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH="$HERE/../../.github"
B="$GH/scripts/util_suite_banner.py"
[ -f "$B" ] || { echo "⛔ REFUSE(rc=2): $B missing -- cannot measure, which is never green"; exit 2; }
grep -q 'def xfail_by_lang' "$B" || { echo "⛔ REFUSE(rc=2): util_suite_banner.py no longer defines xfail_by_lang -- this gate grades a rule that is gone, which must never read green"; exit 2; }
. "$HERE/lib_suites_tsv.sh" || exit 2; REAL="$(suites_real_mark)"

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# The banner resolves the corpus as ../corpus/tests/<lang> relative to the TSV's directory.
mkdir -p "$W/gh" "$W/corpus/tests/xl"
head -2 "$SUITES_TSV_REAL" > "$W/gh/SUITES.tsv"
printf 'xl-rungs\tXlM\t🧪\txl\t2026-09-01\t10\t10\t2026-09-08\t10\t10\tdeadbeef1\t\n' >> "$W/gh/SUITES.tsv"
# ⛔ THE OBSERVATION SURFACE MOVED 2026-09-13, THE RULE DID NOT. This read the BANNER's printed line
# (--line --plain, line 2) until Lon deleted the banner that day -- "Delete whatever produced that. I want it
# gone." banner() and grid() went with it, a bare run now prints nothing, and THIS GATE WENT RED FOR EVERY
# SEAT rather than refusing: it was grading a reading, not the rule. The rule -- a rung suite carrying an xfail
# never renders as done -- is untouched and still worth a gate, so it now reads the SUITE TABLE row (--md),
# which carries the same three states from the same xfail_by_lang(): "done", "N xfail=fail", "xfail
# unreadable". A deleted instrument retires the READING, never the RULE.
run_banner() { S4E_SUITES_TSV="$W/gh/SUITES.tsv" python3 "$B" --md 2>&1 | grep '| XlM |'; }

RED=0; ARMS=0
arm() { ARMS=$((ARMS+1)); if [ "$2" = yes ]; then echo "  ✓ $1"; else echo "  ⛔ $1"; RED=$((RED+1)); fi; }

echo "== test_gate_a_rungs_with_xfails_never_reads_done =="
echo "   population: one synthetic 10/10 rungs row × 3 corpus states (no xfail, one xfail, unreadable) + hermeticity"

# ARM 1 — CONTROL: a 10/10 rungs with NO xfail must read done. Without this the rule could be
# "never say done", which passes arm 2 while destroying the banner.
printf 'name\n' > "$W/corpus/tests/xl/ALL.csv"
out="$(run_banner)"; case "$out" in *done*) ok=yes;; *) ok=no;; esac
arm "arm 1 (control): a rung suite at 10/10 with zero xfail DOES read done" "$ok"

# ARM 2 — THE INVARIANT: one xfail, same 10/10 fraction, must NOT read done.
printf 'seq,name,x,xfail\n1,p1,y,1\n' > "$W/corpus/tests/xl/ALL.csv"
out="$(run_banner)"; case "$out" in *done*) ok=no;; *xfail*) ok=yes;; *) ok=no;; esac
arm "arm 2 (the rule): the SAME 10/10 row with one xfail does NOT read done, and says xfail" "$ok"

# ARM 3 — NEVER A SILENT ZERO: an unreadable corpus must not be treated as "no xfails".
rm -rf "$W/corpus/tests/xl"
out="$(run_banner)"; case "$out" in *unreadable*) ok=yes;; *) ok=no;; esac
arm "arm 3: an UNREADABLE corpus reads 'xfail unreadable', never a silent zero that prints done" "$ok"

# ARM 4 — HERMETIC.
suites_real_untouched "$REAL" && ok=yes || ok=no
arm "arm 4: the real SUITES.tsv is byte-identical after this run" "$ok"

echo "-- population: $ARMS arms over 3 corpus states, $RED red"
[ "$RED" -eq 0 ] || { echo "⛔ GATE RED: $RED of $ARMS arms"; exit 1; }
echo "✅ GATE OK: $ARMS/$ARMS arms -- a rung suite carrying an xfail never renders as done, and an unreadable count never renders as zero"
