#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${FPC_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/pascal/fpc_tests}" || exit 2
# test_pascal_fpc_suite.sh -- Phase 3 of row `fpc-tests-vendor-script-run`: grades the vendored
# subset of Free Pascal's own test suite (corpus/packages/pascal/fpc_tests/, 181 .pas/.ref pairs)
# both SCRIP modes against refs captured from the ruled fpc -Miso oracle (util_census_fpc_tests.sh
# found 298 files SCRIP's front end compiles at all under the full 7618-file FPCSource/tests/ tree;
# of those, 55 are from FPC's own tbf/webtbf "expected to fail" categories -- SCRIP wrongly accepted
# them, a front-end leniency finding reported separately, never vendored as normal suite entries; of
# the remaining 243, 181 vendored clean under -Miso and 62 could not (about a third of THOSE are a
# known, named mode limitation: -Miso is pure ISO 7185 and rejects the `string` identifier, a
# Borland/Delphi-lineage extension SCRIP itself supports -- flagged as a real, open mode question,
# not silently worked around by picking a different mode unilaterally; see this row's own NEXT/LEDGER).
#
# ⚠️ test_gate_pascal_m4.sh's own row (pascal-m4-intermittent-segv-layout-sensitive) measured GENUINE
# run-to-run non-determinism on Pascal m4 output (5 consecutive runs, same tree, same binary, 5
# different pass counts) -- inherited risk, not introduced here. Do not read one run's m4 number as
# exact; the board line names its own run so a caller can re-run and compare.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_flag_gate.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_flag_gate.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_progress.sh unloadable"; exit 2; }
[ $# -eq 0 ] || flaggate_reject "$1" "(none -- set FPC_SUITE_RUN_TIMEOUT / FPC_SUITE_VERBOSE via environment instead)"
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
SUITE="${FPC_SUITE:-$S4E/corpus/packages/pascal/fpc_tests}"   # line 2 sets it to this default, so the guard judges the suite graded here
WANTRC="${WANTRC:-$SUITE/ALL.wantrc}"
RUN_TIMEOUT="${FPC_SUITE_RUN_TIMEOUT:-10}"
VERBOSE="${FPC_SUITE_VERBOSE:-0}"
# ⭐ A DECLARED RUN TIMEOUT, BESIDE THE DATA (hq_pascal 2026-10-04, the heap/stack declaration's shape, Lon's rule that a test unit carries its own run
# arguments): ALL.timeout.tsv names, per program, the seconds its run needs where the shipped default is not enough, with the measurement as the reason.
# A name absent from the file runs at RUN_TIMEOUT. The file is a RECORD, printed with its reasons on every run, never a mask: a name that is not in the
# suite REFUSES the board, so a stale row cannot sit there. FIRST ROW: webtbs_tw15203 (2^30 calls; fpc's own suite marks it %norun).
# ⭐⭐ A CORRECTED REF, BESIDE THE DATA -- WHERE THE ORACLE CANNOT GRADE THE PROGRAM (Lon, in chat 2026-10-05: "A feature the oracle does not have can not be graded by the oracle. And a bug in the oracle causes a test to not be graded by that oracle." Two classes, one mechanism: an oracle DEFECT, and an oracle that LACKS the feature. Verbatim on test_tisobuf3: "I ordered
# test_tisobuf3 to be PASSING ... You must enhance the test suite system to handle the case where we have a feature or a non-bug." and "Do not copy the
# bug. We will be better."). ALL.corrected.tsv names, per program, a ref CORRECTED against the ISO 7185 text because the oracle's own output is a defect
# of the oracle (reason: the oracle's issue or the clause), and <name>.ref.corrected holds the correct output. The program is graded, in the denominator,
# against the corrected ref; PASS means SCRIP prints the CORRECT output -- never the oracle's bug. The oracle's own .ref stays beside it as the record.
# THE LIST IS A RECORD, NOT A MASK: every row is printed with its reason on every run; a name not in the suite, a missing .ref.corrected, or a corrected
# ref IDENTICAL to the oracle's .ref (the oracle was fixed, so the row is stale) REFUSES the board. Expected exit codes still come from ALL.wantrc.
CORRECTED_TSV="$SUITE/ALL.corrected.tsv"; declare -A CORR_SET=()
if [ -f "$CORRECTED_TSV" ]; then
    while IFS=$'\t' read -r _cn _cr; do case "$_cn" in ''|'#'*) continue;; esac
        [ -f "$SUITE/$_cn.pas" ] || { echo "⛔ REFUSED-TO-GRADE: ALL.corrected.tsv names $_cn, which is not in $SUITE"; exit 2; }
        [ -f "$SUITE/$_cn.ref.corrected" ] || { echo "⛔ REFUSED-TO-GRADE: ALL.corrected.tsv names $_cn but $_cn.ref.corrected is missing"; exit 2; }
        if cmp -s "$SUITE/$_cn.ref" "$SUITE/$_cn.ref.corrected"; then echo "⛔ REFUSED-TO-GRADE: $_cn.ref.corrected equals the oracle's $_cn.ref -- the oracle no longer errs there; delete the stale row"; exit 2; fi
        CORR_SET[$_cn]=1; echo "-- corrected ref (oracle defect, graded against the ISO-correct output): $_cn ($_cr)"; done < "$CORRECTED_TSV"
fi
TIMEOUT_TSV="$SUITE/ALL.timeout.tsv"; declare -A TMO_OF=()
if [ -f "$TIMEOUT_TSV" ]; then
    while IFS=$'\t' read -r _tn _ts _tr; do case "$_tn" in ''|'#'*) continue;; esac
        [ -f "$SUITE/$_tn.pas" ] || { echo "⛔ REFUSED-TO-GRADE: ALL.timeout.tsv names $_tn, which is not in $SUITE"; exit 2; }
        case "$_ts" in ''|*[!0-9]*) echo "⛔ REFUSED-TO-GRADE: ALL.timeout.tsv gives $_tn the non-numeric timeout '$_ts'"; exit 2;; esac
        TMO_OF[$_tn]="$_ts"; echo "-- declared run timeout: $_tn ${_ts}s ($_tr)"; done < "$TIMEOUT_TSV"
fi
# ⛔⭐ ISO IS THE ORACLE, SO A PROGRAM ISO REFUSES IS GRADED AS AN EXPECTED REFUSAL (Lon 2026-09-23, in-chat to the ceo, verbatim:
# "use ISO as oracle", CEO-1225; the grading ruled by the ceo as CEO-1228). This suite's refs were cut from fpc -Miso, and where fpc -Miso
# and ISO 7185 disagree ISO wins. ISO_EXPECTED_REFUSALS.tsv beside the package names each program fpc -Miso runs but ISO 7185 refuses,
# with its ISO clause and the measurement; such a program is graded exactly as a PAT rejection test is: PASS in a mode when that mode
# refuses it WITH an ISO 7185 diagnostic, and an acceptance, or a refusal without the ISO diagnostic, is red. The denominator stays the
# whole shipped suite; the fpc-cut .ref of a listed program is never compared, because the oracle's verdict on it is the refusal.
REFUSAL_TSV="$SUITE/ISO_EXPECTED_REFUSALS.tsv"; declare -A REFUSE_SET=()
if [ -f "$REFUSAL_TSV" ]; then
    while IFS=$'\t' read -r _rn _rrest; do case "$_rn" in ''|'#'*) continue;; esac; REFUSE_SET[${_rn%.pas}]=1; done < "$REFUSAL_TSV"
fi
NREF=0

[ -d "$SUITE" ]  || { echo "⛔ REFUSED-TO-GRADE: $SUITE missing"; exit 2; }
[ -x "$SCRIP" ]  || { echo "⛔ REFUSED-TO-GRADE: scrip not built"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_pascal_fpc_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_SO" ]  || { echo "⛔ REFUSED-TO-GRADE: $RT_SO missing (m4 link needs it)"; exit 2; }

TMP="$(mktemp -d /tmp/fpc_suite_XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED-TO-GRADE: lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$TMP/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSED-TO-GRADE: a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
cd "$TMP"   # rungs harness convention (test_gate_em_beauty_subsystems_mode4.sh): graded programs run
            # against a scratch cwd, never the invoker's -- some vendored fpc tests (tisobuf1/tisoread)
            # write scratch files relative to cwd and were leaking them into the caller's directory

mapfile -t PAIRS < <(cd "$SUITE" && ls *.pas 2>/dev/null | sed 's/\.pas$//' | sort)
TOTAL=${#PAIRS[@]}
[ "$TOTAL" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE: zero .pas/.ref pairs in $SUITE"; exit 2; }

M3_PASS=0; M3_FAIL=0; M4_PASS=0; M4_FAIL=0; REJECT=0
# ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06): this suite's leaderboard row states the programs green in
# EVERY graded mode -- never m4 alone (what it published until now), never m3 alone, and never
# min(M3_PASS,M4_PASS), which is not a count of any set of programs: one program red only in m3 and another
# red only in m4 leave min() a program too high. Accumulated per program below, where both verdicts are in hand.
BOTH_PASS=0
M3_FAIL_NAMES=(); M4_FAIL_NAMES=(); REJECT_NAMES=()
PROG_ROWS="$TMP/progress.tsv"; : >"$PROG_ROWS"

echo "=== FPC vendored-suite grade ($TOTAL pairs, $SUITE) ==="

. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one part or a request's entries, rows as each test ends
for name in "${PAIRS[@]}"; do
    rr_admits "$name" || continue; rr_yield "$name" && break; rr_flush "$PROG_ROWS"
    export S4E_TIMEOUT_KEY="$name"
    pas="$SUITE/$name.pas"; ref="$SUITE/$name.ref"
    inp="$SUITE/$name.in"; [ -f "$inp" ] || inp=/dev/null
    if [ -n "${REFUSE_SET[$name]:-}" ]; then
        NREF=$((NREF+1)); m3ok=0
        _t0="$(progress_clock)"
        _e3="$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$SCRIP" --run "$pas" <"$inp" 2>&1 >/dev/null)"; _r3=$?
        S3="$(progress_secs_since "$_t0")"; _t0="$(progress_clock)"   # each mode's own wall for its row (CEO-1676 (c))
        if [ "$_r3" -ne 0 ] && [ "$_r3" -lt 124 ] && printf '%s' "$_e3" | grep -q 'ISO 7185'; then
            M3_PASS=$((M3_PASS+1)); m3ok=1; printf 'package\tfpc\tpascal\t%s\tm3\tPASS\t%s\texpected-refusal-iso-7185\n' "$name" "$S3" >>"$PROG_ROWS"
        else
            M3_FAIL=$((M3_FAIL+1)); M3_FAIL_NAMES+=("$name(expected-refusal)")
            printf 'package\tfpc\tpascal\t%s\tm3\tFAIL\t%s\texpected-refusal-not-refused-with-an-iso-diagnostic(rc=%s)\n' "$name" "$S3" "$_r3" >>"$PROG_ROWS"
        fi
        _e4="$(cd "$TMP" && "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$SCRIP" --compile "$pas" --out="$TMP/$name.s" </dev/null 2>&1 >/dev/null)"; _r4=$?
        if [ "$_r4" = 0 ] && gcc -no-pie "$TMP/$name.s" -L "${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$TMP/$name.bin" 2>/dev/null; then
            _e4="$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$TMP/$name.bin" <"$inp" 2>&1 >/dev/null)"; _r4=$?
        fi
        S4="$(progress_secs_since "$_t0")"
        if [ "$_r4" -ne 0 ] && [ "$_r4" -lt 124 ] && printf '%s' "$_e4" | grep -q 'ISO 7185'; then
            M4_PASS=$((M4_PASS+1)); [ "$m3ok" -eq 1 ] && BOTH_PASS=$((BOTH_PASS+1))
            printf 'package\tfpc\tpascal\t%s\tm4\tPASS\t%s\texpected-refusal-iso-7185\n' "$name" "$S4" >>"$PROG_ROWS"
        else
            M4_FAIL=$((M4_FAIL+1)); M4_FAIL_NAMES+=("$name(expected-refusal)")
            printf 'package\tfpc\tpascal\t%s\tm4\tFAIL\t%s\texpected-refusal-not-refused-with-an-iso-diagnostic(rc=%s)\n' "$name" "$S4" "$_r4" >>"$PROG_ROWS"
        fi
        continue
    fi
    if [ ! -f "$ref" ]; then
        REJECT=$((REJECT+1)); REJECT_NAMES+=("$name (no .ref)")
        # ⭐ RECORDED, NOT DROPPED: a shipped .pas with no .ref is owed work (REF_NOT_CUT), and THE PACKAGE
        # LOCKDOWN is precisely the rule that such a program must appear somewhere as ungraded rather than
        # silently vanish from the table the census reads.
        for m in m3 m4; do printf 'package\tfpc\tpascal\t%s\t%s\tUNGRADED\t0\tno-ref-cut\n' "$name" "$m" >>"$PROG_ROWS"; done
        continue
    fi
    exp="$(cat "$ref")"
    [ -n "${CORR_SET[$name]:-}" ] && exp="$(cat "$SUITE/$name.ref.corrected")"
    T_RUN="${TMO_OF[$name]:-$RUN_TIMEOUT}"

    m3ok=0
    # ⛔⭐⭐ THE OUTPUT ALONE IS NOT THE VERDICT -- rc IS GRADED BESIDE IT (hq_pascal 2026-09-16, INSTRUMENT
    # CHANGE in the CEO-749 shape, the cure shape handed over by hq_icon). 106 of this suite's 181 refs are
    # EMPTY, and this arm compared stdout only, so a program that DIED before printing anything answered the
    # question "did stdout stay empty" CORRECTLY and scored PASS. MEASURED: 44 entries passed while exiting
    # non-zero; fpc compiles all 44 and runs 37 of them to completion with rc=0. The pass was real and the
    # proposition it proved was not the one this board's header claims.
    # ⛔ THE EXPECTED rc IS CUT FROM THE ORACLE, NEVER FROM US: corpus/packages/pascal/fpc_tests/ALL.wantrc
    # carries fpc's own exit status for every entry that is not 0, same filename and format as the Icon
    # rungs'. An entry absent from that file expects 0. A line there is the oracle's answer, not a waiver.
    _t0="$(progress_clock)"
    m3out=$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$T_RUN" "$SCRIP" --run "$pas" < "$inp" 2>/dev/null); m3rc=$?
    S3="$(progress_secs_since "$_t0")"
    wantrc=$(awk -F'\t' -v n="$name" '$1==n{print $2; exit}' "$WANTRC" 2>/dev/null); [ -n "$wantrc" ] || wantrc=0
    if [ "$m3out" = "$exp" ] && [ "$m3rc" = "$wantrc" ]; then
        M3_PASS=$((M3_PASS+1)); m3ok=1
        printf 'package\tfpc\tpascal\t%s\tm3\tPASS\t%s\t\n' "$name" "$S3" >>"$PROG_ROWS"
        [ "$VERBOSE" -eq 1 ] && echo "  m3 PASS $name"
    else
        M3_FAIL=$((M3_FAIL+1)); M3_FAIL_NAMES+=("$name")
        if [ "$m3out" = "$exp" ]; then _d3="exit-code-differs(got=$m3rc want=$wantrc)"; else _d3="output-differs-from-ref"; fi
        [ "$m3rc" = 124 ] && _d3="timeout-at-${T_RUN}s"
        printf 'package\tfpc\tpascal\t%s\tm3\tFAIL\t%s\t%s\n' "$name" "$S3" "$_d3" >>"$PROG_ROWS"
        [ "$VERBOSE" -eq 1 ] && echo "  m3 FAIL $name"
    fi

    m4bin="$TMP/${name}.bin"; m4s="$TMP/${name}.s"; _t0="$(progress_clock)"
    if "$TIMEOUT_RETRY" "$T_RUN" "$SCRIP" --compile "$pas" --out="$m4s" < /dev/null 2>/dev/null \
        && gcc -no-pie "$m4s" -L "${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$m4bin" 2>/dev/null; then
        m4out=$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$T_RUN" "$m4bin" < "$inp" 2>/dev/null); m4rc=$?
        S4="$(progress_secs_since "$_t0")"
        if [ "$m4out" = "$exp" ] && [ "$m4rc" = "$wantrc" ]; then
            M4_PASS=$((M4_PASS+1)); [ "$m3ok" -eq 1 ] && BOTH_PASS=$((BOTH_PASS+1))
            printf 'package\tfpc\tpascal\t%s\tm4\tPASS\t%s\t\n' "$name" "$S4" >>"$PROG_ROWS"
            [ "$VERBOSE" -eq 1 ] && echo "  m4 PASS $name"
        else
            M4_FAIL=$((M4_FAIL+1)); M4_FAIL_NAMES+=("$name")
            if [ "$m4out" = "$exp" ]; then _d4="exit-code-differs(got=$m4rc want=$wantrc)"; else _d4="output-differs-from-ref"; fi
            [ "$m4rc" = 124 ] && _d4="timeout-at-${T_RUN}s"
            printf 'package\tfpc\tpascal\t%s\tm4\tFAIL\t%s\t%s\n' "$name" "$S4" "$_d4" >>"$PROG_ROWS"
            [ "$VERBOSE" -eq 1 ] && echo "  m4 FAIL $name"
        fi
    else
        S4="$(progress_secs_since "$_t0")"
        M4_FAIL=$((M4_FAIL+1)); M4_FAIL_NAMES+=("$name (build/link failed)")
        printf 'package\tfpc\tpascal\t%s\tm4\tFAIL\t%s\tbuild-or-link-failed\n' "$name" "$S4" >>"$PROG_ROWS"
        [ "$VERBOSE" -eq 1 ] && echo "  m4 FAIL $name (build/link failed)"
    fi
done

echo ""
if [ "$REJECT" -gt 0 ]; then
    echo "-- pairs missing a .ref (instrument issue, not a grading result): $REJECT --"
    for n in "${REJECT_NAMES[@]}"; do echo "   $n"; done
fi
if [ "$VERBOSE" -ne 1 ] && [ "$M3_FAIL" -gt 0 ]; then
    echo "-- m3 FAIL ($M3_FAIL): ${M3_FAIL_NAMES[*]:0:10}$([ "$M3_FAIL" -gt 10 ] && echo ' ...')"
fi
if [ "$VERBOSE" -ne 1 ] && [ "$M4_FAIL" -gt 0 ]; then
    echo "-- m4 FAIL ($M4_FAIL): ${M4_FAIL_NAMES[*]:0:10}$([ "$M4_FAIL" -gt 10 ] && echo ' ...')"
fi

[ "$NREF" -gt 0 ] && echo "-- $NREF program(s) graded as EXPECTED REFUSALS (ISO_EXPECTED_REFUSALS.tsv: fpc -Miso runs them, ISO 7185 refuses them; CEO-1228)"
echo ""
echo "FPC_SUITE_BOARD total=$TOTAL both_pass=$BOTH_PASS m3_pass=$M3_PASS m3_fail=$M3_FAIL m4_pass=$M4_PASS m4_fail=$M4_FAIL reject=$REJECT expected_refusals=$NREF"
# ⭐ THE PACKAGE LOCKDOWN inventory line, via the shared body (lib_inventory.sh) -- never a second copy
# of the arithmetic. REJECT here is "shipped .pas with no .ref yet" -- real owed work (REF_NOT_CUT), not
# an oracle ruling -- so a nonzero REJECT with no UNGRADED.tsv beside $SUITE correctly REFUSES below
# rather than being silently folded into ungradable the way the old ad hoc line did.
FPC_GRADED=$((TOTAL - REJECT))
INV_PACKAGE=fpc; INV_DIR="$SUITE"; INV_EXT=".pas"
if ! rr_selected; then   # a part of the package; the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$FPC_GRADED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
# ⛔⭐ THE SUITE ROW'S PAIR IS DECLARED, NEVER PARSED (hq_T 2026-09-06, ceo CEO-363; the coo had to set
# this row BY HAND after a clean run because util_score_row correctly REFUSED to guess). The --text below
# carries THREE fractions over the same denominator (the AND, m3 and m4), and there is no fact of the matter
# about which one a text parse should take -- so the writer refuses rather than picking, and the runner
# declares its headline pair.
# ⛔⭐ THE RULING CAME, AND IT IS NEITHER ARM: ceo-372, 2026-09-06, on hq_T's ask. This row was wired to m4
# (because SUITES.tsv carried m4), then to m3 by hq_V at 20:5x when the coo hand-set the published row to the
# m3 numbers -- each rewiring correctly avoiding the phantom regression the other would have published, and
# hq_V closed with "The ceo is asked to rule; either way it stays one line." This is that line. The pair is
# THE AND PER PROGRAM: "a program red in m3 and another red in m4 both count against the row; never m3 alone,
# never m4 alone, never the min of two counts (which hides a program red in each)."
# ⭐ hq_V's SECOND, STANDING REASON IS ANSWERED RATHER THAN OVERRULED. m4 here really is run-to-run
# non-deterministic (this file's header: five runs, one tree, five pass counts), and a row wired to a number
# that moves without the code moving really does manufacture phantom movement in the table Lon reads. The
# ceo's ruling puts that where it belongs: "a mode whose count varies run to run is a DEFECT ROW in that lane
# -- a nondeterministic compile is the xfail shape with a runner's excuse in front of it -- never a reason to
# publish the steadier mode." The wobble is now the Pascal lane's row (pascal-m4-intermittent-segv-layout-
# sensitive), not a thing the leaderboard steers around by choosing an arm.
# ✅ AND THE ROW IS LIVE -- REOPENED BY THE ceo AT 21:05 (CEO-379, .github 3879c3d3): rank 0, assignee hq_V,
# FREE. It had been filed in QUEUE.done.tsv, unassigned, absent from QUEUE.tsv, while the defect it names was in
# that night's board (m3 130 vs m4 116) and in this file's own header (5 runs, 5 counts, one tree) -- measured
# 2026-09-06 22:5x and asked up rather than reopened from this lane. ⭐ THE ceo's REASON IS THE REUSABLE PART:
# the row's DONE-WHEN graded the GATE's population and was honestly met there, while the CLASS lives on this
# suite's population -- one member cured, the class red. A DONE-WHEN met on a narrower population than the class
# it names closes a row that nothing has fixed (shape 2 of HOW A CRITERION LIES, from the closing side).
# hq_V re-scopes the criterion (five suite runs on one clean tree read ONE m4 count) and proves it red once.
# ⭐ Recorded here because a comment that cites a row as live is a PREMISE, and an unmeasured premise is
# shape 4 -- which is why it was checked instead of cited.
# ⛔ THE NUMBER DROPS FROM $M3_PASS (m3, as published) TO $BOTH_PASS -- 130 to 116 of 181, measured this
# sitting -- AND THAT IS A CRITERION CHANGE, NOT A REGRESSION. The commit landing it says so in those words.
#
# ⛔⭐ THE FACT RULE'S OTHER HALF (CEO-319, /home/resources/progress/README.md): every suite run APPENDS its
# per-program rows in the same sitting it rewrites its cell. MEASURED by hq_V at its opening, 2026-09-06:
# of 497 pascal rows in that table every one was pascal-rungs -- ZERO from fpc or pat, so a Pascal PACKAGE
# flip was invisible to the measure OCTET is run on. One bulk call, not 362. Non-fatal, never silent.
#
# ⛔ APPEND BEFORE WRITE, NOT AFTER (hq_pascal 2026-09-23): the write below's own db_crosscheck (CEO-750)
# REFUSES unless this suite's per-program rows are ALREADY on the progress DB for this exact tree -- so
# appending them after the write can never satisfy the write it is meant to unblock. Measured live: on
# SCRIP d7a3c06fc this order refused every single time ("no progress rows for suite 'fpc' on tree
# d7a3c06fc") despite the append succeeding moments later, 362-for-362, on the very next line.
if [ -s "$PROG_ROWS" ]; then
    if ! progress_append_rows_tsv "$PROG_ROWS"; then
        echo "⚠ PROGRESS DB NOT UPDATED -- the score write below cannot cross-check and will refuse (reason above)" >&2
    fi
fi
rr_selected && { rr_end fpc; exit 0; }   # a part or a request writes its rows and no suite row (CEO-1802)
# ⭐ THE ROW'S CRITERION IS STAMPED WHEN IT MOVES: the banner renders the LAST OUTSIDE=N token of SUITES.tsv column 12, and this row
# carried OUTSIDE=15 for one run under the CEO-749 reading, so the first run under CEO-1228 records OUTSIDE=0 with its reason.
_cc="${S4E_CRITERION_CHANGED:-}"
_lastout="$(awk -F'\t' '$1=="fpc"{print $12; exit}' "$(. "$HERE/lib_suites_tsv.sh"; suites_tsv "$S4E")" 2>/dev/null | grep -oE 'OUTSIDE=[0-9]+' | tail -1 | cut -d= -f2)"
if [ -z "$_cc" ] && [ -n "$_lastout" ] && [ "$_lastout" != 0 ]; then
    _cc="$(date +%F):CEO-1228-programs-iso-7185-refuses-and-fpc-Miso-runs-are-graded-as-expected-refusals-$NREF-named-in-ISO_EXPECTED_REFUSALS.tsv-denominator-$TOTAL-OUTSIDE=0"
fi
python3 "$HERE/util_score_row.py" write --lang pascal --column vendor --suite fpc --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --suite-pass "$BOTH_PASS" --suite-total "$TOTAL" \
    --measurer "${S4E_SEAT:-}" --text "both-modes $BOTH_PASS/$TOTAL · m3 $M3_PASS/$TOTAL · m4 $M4_PASS/$TOTAL (m3_fail=$M3_FAIL m4_fail=$M4_FAIL reject=$REJECT expected_refusals=$NREF${INV_LINE:+ · $INV_LINE (\`test_pascal_fpc_suite.sh\`)})" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"

# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): M3_FAIL/M4_FAIL/REJECT all read 0 over TOTAL=0 too (empty discovery) --
# refuse before the vacuous-clean verdict below can be reached.
"$HERE/util_require_population.sh" --gate test_pascal_fpc_suite "$TOTAL" 1 "pascal witnesses" || exit 2
[ "$M3_FAIL" -eq 0 ] && [ "$M4_FAIL" -eq 0 ] && [ "$REJECT" -eq 0 ]
