#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_ref_pins_oracle_internal_state.sh -- NO .ref PINS THE ORACLE'S OWN INTERNAL ACCOUNTING.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-08
#
# ⛔⭐⭐ A REF THAT PINS THE ORACLE'S ALLOCATOR COUNTERS CANNOT BE MATCHED BY BEING CORRECT. It can only be
# matched by TRANSCRIBING SPITBOL's internal state -- `memory used (bytes) 11416`, `memory left (bytes)
# 1037152`, `REGENERATIONS`, `execution time msec` -- numbers that are real, per-program allocator state
# (measured across the 22: 11408, 11416, 15824, 15904, 52208, ... all different) and that no other
# implementation produces by being right. A program graded against one of these is not a bug we can win.
#
# ⛔ THE FRAME THIS CORRECTS WAS THE CEO'S OWN, AND ELEVEN SEATS READ IT AS THE NIGHT'S PREMISE (ceo
# 2026-09-08, correcting itself): "85 package reds, EVERY ONE a program SPITBOL runs clean and we do not."
# For this class the premise is INVERTED -- it is a program SPITBOL *fails*, and we are graded against a
# transcript of the failure. hq_R proved the cost rather than asserting it: it took `rewind1`, which was a
# REAL defect (REWIND on a unit with no OPENed file must raise ERROR 174; _REWIND_ fell back to stdin for
# unit 5), probed it four ways against sbl, cured it, landed it -- AND THE BOARD DID NOT MOVE. FAIL became
# REJECT and 66/93 stood. ⭐ A CORRECT CURE ON A DEAD-PINNED PROGRAM CANNOT FLIP IT, which is the most
# expensive way to learn that a red is not yours, and this gate exists so nobody pays it twice.
#
# ⛔⭐⭐ THE TEMPTING CURE IS THE WRONG ONE, AND IT IS WRONG IN THE DANGEROUS DIRECTION. The obvious move is
# to NORMALISE these four lines out of both sides. DO NOT. SCRIP prints NOTHING to stdout for these
# programs, so a strip broad enough to remove the oracle's accounting also reduces the pin to nothing --
# and nothing matches nothing. All 22 would flip GREEN while the compiler still emits no report at all: a
# full, plausible, entirely false green, manufactured by the very check meant to make grading fair.
# hq_P measured exactly this risk on the sibling gimpel class. THE STANDARD'S RULE APPLIES HERE VERBATIM
# (GOAL-TEST-SUITE-CONSISTENCY.md): a stripper that can turn nothing into a match is not a normalisation,
# it is a laundry.
# ✅ THE RIGHT CURE IS RECLASSIFICATION, NOT NORMALISATION: what the oracle refuses, or only its own
# implementation can produce, is OUTSIDE THE BASELINE -- named per program, out of the denominator, with
# the oracle's own text, in the suite's OUTSIDE_SPITBOL_BASELINE.tsv (ceo CEO-390/391). That is hq_B's
# re-cut. This gate's job is only to make the population visible and stop it growing.
#
# ⛔⭐⭐ THE FLOOR IS 23, NOT 22, AND THE 23rd IS THE FINDING. The ceo, hq_B and my own first census all read
# 22 -- all of them in csnobol4_suite. This gate found a 23rd ON ITS FIRST RUN, inside
# corpus/tests/snobol4/ALL.ref: THE SNOBOL4 RUNGS, the board that answers Lon's 100% question. Three of its
# entries carry SPITBOL's allocator counters in their refs -- 1900 simple_output_64, 1902 simple_output_62,
# 1910 user_function_arbno_rpos_1 -- and all three are marked XFAIL, which is the tell: they were marked
# expected-red because they could never pass, and they could never pass because the ref pins state we cannot
# produce. ⛔ SO THREE OF THE RUNGS'S 27 XFAIL ARE NOT WINNABLE BUGS AT ALL, and a seat curing toward them
# is doing hq_R's rewind1 over again. They need reclassification, not a cure.
# ⭐ WHY EVERY EARLIER CENSUS MISSED IT, and it is a trap worth more than the count: ALL.ref carries non-UTF-8
# bytes, so grep calls it BINARY. `grep -rl` still reports it (that is how this gate saw it) but `grep -n`
# prints "Binary file matches" instead of the lines -- so a human verifying the hit by grepping the file
# sees NOTHING and concludes the tool was wrong. I nearly retracted this finding as a false positive on
# exactly that reading. Use `grep -a` on any corpus ref before believing an absence.
#
# ⛔ A RATCHET, AND THE FLOOR ONLY FALLS. 23 exist today, 22 in csnobol4_suite and 1 in the snobol4 rungs
# -- verified here and
# independently by hq_B -- in NO other package (gimpel 0 after tonight's cure, aisnobol 0, dotnet 0,
# snoflake 0, testpgms 0, and zero across every icon and prolog package). Green on arrival, so it can be
# wired blocking; what it prevents is a 23rd ref being minted against an oracle's death.
# EXIT: 0 at or below the floor · 1 the count GREW · 2 REFUSED (no corpus, or zero refs found to scan).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="test_gate_no_ref_pins_oracle_internal_state"
gate_parse_args "$@"

S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
C="$S4E/corpus"
[ -d "$C" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no corpus at $C"; gate_stamp; exit 2; }

# ⛔ ORACLE-INTERNAL ACCOUNTING ONLY -- lines whose VALUE is a fact about the oracle's process, never about
# the program's meaning. Deliberately NOT "any line with a number": a gate broader than its rule gets
# switched off by the first person it blocks for a good reason.
RX='memory used \(bytes\)|memory left \(bytes\)|^REGENERATIONS|execution time msec'

# ⛔ CAPTURE FIRST, THEN TEST. `grep -rl ... | wc -l` in a pipeline hides grep's own status (CLAUDE.md's
# measured trap: rc reported for the LAST command, not the one that matters).
scanned=$(find "$C" -name '*.ref' -type f 2>/dev/null | wc -l)
[ "$scanned" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: found ZERO .ref files under $C -- the corpus layout moved and this gate cannot grade that; zero refs is not zero violations"; gate_stamp; exit 2; }
hits=$(grep -rlE "$RX" --include='*.ref' "$C" 2>/dev/null | sed "s|^$C/||" | sort)
n=$(printf '%s' "$hits" | grep -c . || true)
GATE_EXAMINED="$scanned .ref file(s)"

PIN="${PIN_ORACLE_INTERNAL_REFS:-23}"
echo "REFS PINNING ORACLE-INTERNAL STATE: $n (floor $PIN) over $scanned .ref files"
if [ "$n" -gt 0 ]; then
  printf '%s\n' "$hits" | sed 's/^/   /' | head -30
  printf '%s\n' "$hits" | awk -F/ '{print $1"/"$2"/"$3}' | sort | uniq -c | sed 's/^/   by suite: /'
fi
bad=0
if [ "$n" -gt "$PIN" ]; then
  echo "⛔ GREW: $n refs pin the oracle's own accounting, above the pinned $PIN."
  echo "   A ref carrying 'memory used (bytes) N' can only be matched by transcribing SPITBOL's allocator"
  echo "   state. Curing the program cannot flip it (hq_R proved this on rewind1: a real defect, correctly"
  echo "   cured and landed, and the board did not move)."
  echo "   ⛔ DO NOT normalise these lines away -- SCRIP prints nothing here, so the strip empties both sides"
  echo "      and flips them all GREEN while the compiler still emits no report (the laundry rule)."
  echo "   ✅ Reclassify: name it in the suite's OUTSIDE_SPITBOL_BASELINE.tsv, out of the denominator, with"
  echo "      the oracle's own text (ceo CEO-390/391)."
  bad=1
fi
[ "$n" -lt "$PIN" ] && echo "⭐ FELL — re-pin in this commit: PIN_ORACLE_INTERNAL_REFS=$n (floors only fall)"
gate_verdict "$bad" "ref population pinning oracle-internal state above its floor"
