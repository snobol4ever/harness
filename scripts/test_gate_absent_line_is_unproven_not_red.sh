#!/bin/bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# test_gate_absent_line_is_unproven_not_red.sh -- DONE-WHEN for row
# a-refusal-reported-in-the-vocabulary-of-a-red-absent-line-read-as-unparseable (seat15, dispatched by
# hq_T, 2026-09-05).
#
# THE DEFECT: hq_C measured test_corpus_snobol4.sh KILLING 4 programs at its 120s per-program bound under
# fleet load 3.6 -- a COULD-NOT-MEASURE that script itself already reports honestly (rc=2, "⛔ GATE
# REFUSES: ... NOT graded, NOT failures"). A CONSUMER of that board greeted the resulting ABSENT summary
# line with "FAIL m3=UNPARSEABLE" -- a sentence about the COMPILER that was really a sentence about the
# MACHINE. SAME ANIMAL AS EVERY OTHER INSTRUMENT DEFECT THIS SESSION: an instrument that answers a
# narrower question than the reader thinks they asked, and never says so. THE WORK: census every consumer
# that infers a verdict from an ABSENT expected line and make each distinguish three outcomes -- present
# and green, present and red, or ABSENT (UNPROVEN, rc=2, reported with what was actually seen) -- never
# folding the third into the first or second. The board itself (test_corpus_snobol4.sh) is NOT the
# defect and is this gate's control: it already buckets a kill as NOT GRADED, NOT A FAILURE.
#
# TWO PARTS:
#   PART A (behavioural) -- exercises lib_gate.sh's gate_three_way, the shared primitive every fixed
#     consumer below now calls, against synthetic present-green / present-red / sub-refused / timed-out /
#     signalled / format-changed inputs. No compiler build required: fast, deterministic, and it is what
#     actually PROVES the primitive's contract rather than trusting its own comment.
#   PART B (structural census) -- re-discovers, FRESH every run (never a hardcoded snapshot), every
#     script under ../harness/scripts/ that actually RUNS test_corpus_snobol4.sh and captures its output, and reds
#     if any such consumer still carries a known-bad absence idiom -- so a consumer added LATER without
#     the three-way split reds HERE, on this gate, rather than on someone's next false board. It also
#     asserts each of the six call-sites landed by this row still carries its cure (a reverted fix is a
#     regression this census must catch, not silently miss).
#
# NOT censused by the automated sweep, audited by hand instead (both confirmed clean, 2026-09-05):
# util_build_score_md.py (already does exactly this -- "a pattern miss is UNPROVEN, never a guess", with
# its own SELFTEST) and util_score_row.py (never invokes a test script at all -- see its own line 20:
# "if you find yourself adding a subprocess call to a test script here, you are writing the other tool").
# Python consumers would spell the same defect differently (`.get(..., 0)`, `or 0`, ...); the mechanical,
# greppable sweep below is bash-specific by construction. Broadening it is follow-on work, not this row's
# DONE-WHEN, which scopes to "start with the arms that consume test_corpus_snobol4.sh" (the GOAL's own
# words) -- see the row's LEDGER for the exact six call-sites landed and what remains open.
#
# Exit: 0 all green · 1 measured and something failed · 2 refused to grade (prerequisite missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../../SCRIP" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
GATE_NAME=absent-line-is-unproven-not-red
[ -f "$HERE/lib_gate.sh" ] || { echo "⛔ REFUSE(2): no $HERE/lib_gate.sh -- this gate tests gate_three_way, which lives there" >&2; exit 2; }
. "$HERE/lib_gate.sh"
command -v gate_three_way >/dev/null || { echo "⛔ REFUSE(2): lib_gate.sh sourced but gate_three_way is not defined -- has it been renamed or reverted?" >&2; exit 2; }

FAIL=0
report() { if [ "$2" -eq 0 ]; then echo "✅ PASS $1 -- $3"; else echo "⛔ FAIL $1 -- $3"; FAIL=$((FAIL+1)); fi; }
ERRTMP=$(mktemp -d); trap 'rm -rf "$ERRTMP"' EXIT

echo "--- PART A: gate_three_way behavioural census (synthetic, no build required) ---"

# A1: present + green -- the ordinary case must be untouched by this helper existing.
line=$(gate_three_way "A1" 0 "mode-3 (--run): PASS=10 FAIL=0" '^mode-3 \(--run\): PASS=[0-9]+ FAIL=[0-9]+' 2>"$ERRTMP/a1"); rc=$?
if [ "$rc" -eq 0 ] && [ "$line" = "mode-3 (--run): PASS=10 FAIL=0" ]; then report present-green 0 "returns 0 and the matched line unchanged"; else report present-green 1 "rc=$rc line=[$line]"; fi

# A2: present + red -- rc=1 WITH the pattern present must still read as PRESENT (0); red-vs-green is the
# caller's own numeric judgement on the returned line, never this helper's to decide.
line=$(gate_three_way "A2" 1 "mode-3 (--run): PASS=8 FAIL=2" '^mode-3 \(--run\): PASS=[0-9]+ FAIL=[0-9]+' 2>"$ERRTMP/a2"); rc=$?
if [ "$rc" -eq 0 ] && [ "$line" = "mode-3 (--run): PASS=8 FAIL=2" ]; then report present-red-is-still-present 0 "rc=1 with a matching line reads PRESENT, not UNPROVEN"; else report present-red-is-still-present 1 "rc=$rc line=[$line]"; fi

# A3: absent via the sub-run's OWN honest refusal (rc=2) -- must win even if stale matching text is
# sitting in $out from before the refusal fired (test_corpus_snobol4.sh prints partial numbers, THEN
# may still refuse further down for an unrelated reason such as MISSING paths).
line=$(gate_three_way "A3" 2 "mode-3 (--run): PASS=10 FAIL=0 (printed before an unrelated refusal)" '^mode-3 \(--run\): PASS=[0-9]+ FAIL=[0-9]+' 2>"$ERRTMP/a3"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$line" ] && grep -qi "REFUSED" "$ERRTMP/a3"; then report absent-via-subrefusal-rc2 0 "rc=2 propagates as UNPROVEN even with matching text present"; else report absent-via-subrefusal-rc2 1 "rc=$rc line=[$line] stderr=[$(cat "$ERRTMP/a3")]"; fi

# A4: absent via an outer timeout wrapper (rc=124) -- must name TIMED OUT, never a number.
line=$(gate_three_way "A4" 124 "" '^mode-3' 2>"$ERRTMP/a4"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$line" ] && grep -qi "timed out" "$ERRTMP/a4"; then report absent-via-timeout-rc124 0 "TIMED OUT reported, not a number"; else report absent-via-timeout-rc124 1 "rc=$rc stderr=[$(cat "$ERRTMP/a4")]"; fi

# A5: absent via a signal (rc=137 = 128+SIGKILL) -- must name the signal, never a number.
line=$(gate_three_way "A5" 137 "" '^mode-3' 2>"$ERRTMP/a5"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$line" ] && grep -qi "KILLED by SIG" "$ERRTMP/a5"; then report absent-via-signal-rc137 0 "KILLED by SIGKILL reported, not a number"; else report absent-via-signal-rc137 1 "rc=$rc stderr=[$(cat "$ERRTMP/a5")]"; fi

# A6: absent via a clean exit with no summary at all (a format change, or a crash that still exits 0) --
# STILL unproven; a clean rc is not, by itself, permission to trust silence as zero.
line=$(gate_three_way "A6" 0 "scrip: internal error -- no summary printed" '^mode-3 \(--run\): PASS=[0-9]+ FAIL=[0-9]+' 2>"$ERRTMP/a6"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$line" ] && grep -qi "never printed" "$ERRTMP/a6"; then report absent-via-no-match-rc0 0 "a clean rc with no summary line is STILL unproven, never a silent pass"; else report absent-via-no-match-rc0 1 "rc=$rc line=[$line] stderr=[$(cat "$ERRTMP/a6")]"; fi

echo ""
echo "--- PART B: structural census of real consumers ---"

# THE CENSUS: the call-sites this row actually landed a cure for (six; three since 2026-10-01, when the zd gate's arm 4 was retired). A reverted or weakened cure must
# red HERE, not be silently missing from every other board.
# (test_gate_zd_omega_head_acceptance.sh's three consumers left with its arm 4, retired 2026-10-01 by the coo: the five boards that
# arm ran as a fixture are the coo's SUITE TABLE's under CEO-1342, so no reader of a sub-runner's summary line is left there.)
declare -a CENSUS_FILE=(
    test_gate_nreturn_by_name_value_broken.sh
    test_gate_snocone_returns_codegen.sh
    test_snobol4_all_modes.sh
)
declare -a CENSUS_DESC=(
    "SNOBOL4 corpus-gate arm (consumes test_corpus_snobol4.sh)"
    "SNOBOL4 corpus-gate arm (consumes test_corpus_snobol4.sh)"
    "run_suite() (consumes smoke/pat_rung/corpus runners)"
)
declare -a CENSUS_NEEDLE=(
    'gate_three_way "test_corpus_snobol4.sh"'
    'gate_three_way "test_corpus_snobol4.sh"'
    'why="TIMED OUT (rc=124)"'
)
n_censused=${#CENSUS_FILE[@]}
i=0
while [ "$i" -lt "$n_censused" ]; do
    f="${CENSUS_FILE[$i]}"; desc="${CENSUS_DESC[$i]}"; needle="${CENSUS_NEEDLE[$i]}"
    label="census-$(basename "$f" .sh)-$i"
    if [ ! -f "$HERE/$f" ]; then
        report "$label" 1 "$f ($desc): the consumer file itself is gone -- repoint or retire this census row"
    elif grep -qF "$needle" "$HERE/$f"; then
        report "$label" 0 "$f: $desc -- cure present"
    else
        report "$label" 1 "$f: $desc -- the landed cure is MISSING or was reverted (expected to find: $needle)"
    fi
    i=$((i+1))
done

# THE REGRESSION SWEEP: re-discover, fresh, every bash script that actually RUNS test_corpus_snobol4.sh
# and captures its output (a real invocation, not a comment/prose mention), and fail loudly if any of
# them -- fixed today or added tomorrow -- still carries a known-bad absence idiom. This is what makes a
# NEW consumer red HERE instead of on someone's next false board.
echo ""
echo "--- regression sweep: any CURRENT bash consumer of test_corpus_snobol4.sh with a known-bad idiom? ---"
bad=0
swept=0
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
while IFS= read -r f; do
    [ -f "$f" ] || continue
    # ⛔ EXCLUDE SELF, DELIBERATELY -- caught live on this script's own first run: this gate's OWN source
    # contains the sweep's regex as literal text ("bash ... test_corpus_snobol4.sh"), which is indistin-
    # guishable to a naive grep from a real invocation line. Exactly the "GREP THE BEHAVIOUR, NOT THE
    # TEXT" trap named in this row's own dispatch (hq_T: "a textual census matches its own documentation
    # -- one of mine counted seven aborting programs where there were six, and the seventh match was a
    # runner echoing a SCORE.md cell whose prose contained the string"). This gate is a producer of the
    # sweep, never a consumer of test_corpus_snobol4.sh's output, so it is never a legitimate match.
    [ "$f" = "$SELF" ] && continue
    grep -qE '(bash [^|;&]*test_corpus_snobol4\.sh|\$\([^)]*test_corpus_snobol4\.sh)' "$f" || continue
    swept=$((swept+1))
    if grep -qE ':-UNPARSEABLE|(PASS|FAIL)=\$\{[a-zA-Z0-9_]+:-0\}' "$f"; then
        bad=$((bad+1))
        report "regression-sweep-$(basename "$f")" 1 "known-bad absence idiom (UNPARSEABLE filler or a bare :-0 default) found in a live consumer of test_corpus_snobol4.sh"
    fi
done < <(grep -rlE '\btest_corpus_snobol4\b' "$HERE"/*.sh 2>/dev/null)
if [ "$bad" -eq 0 ]; then report regression-sweep 0 "$swept live bash consumer(s) of test_corpus_snobol4.sh swept, none carry a known-bad absence idiom"; fi

echo ""
echo "consumers censused: $n_censused"
echo "=== $([ "$FAIL" -eq 0 ] && echo ALL GREEN || echo "$FAIL CHECK(S) FAILED") ==="
[ "$FAIL" -eq 0 ]
