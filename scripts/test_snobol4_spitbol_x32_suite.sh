#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${SPITBOL_X32_SUITE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/spitbol_x32_tests}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program, as its sibling spitbol_x64 runner did, until 2026-09-26
# test_snobol4_spitbol_x32_suite.sh -- the runner for corpus/packages/snobol4/spitbol_x32_tests, row
# snobol4-the-21-spitbol-x32-tests-join-the-corpus-as-a-vendored-package-with-a-runner-and-a-suite-row-x32t-lon-2026-09-26
# (ceo CEO-1287; Lon 2026-09-26: "Place the 21 SPITBOL x32 tests in our corpus repo and make test suite entry for those."
# and "where is the X32T test suite? put that in the official list of test suites.").  Suite key x32tests, nick X32T.
#
# THE BODY IS test_snobol4_spitbol_x64_suite.sh's, BY DESIGN AND BY PARAMETER ONLY: package spitbol_x32_tests, extension
# .spt, 21 shipped, progress suite spitbol_x32, score row x32tests.  Every instrument decision that body carries -- the oracle
# decides whether and how each program is graded (self-check arm vs stream arm, read off the oracle's own output), HANG/CRASH
# checked before the stream, the mode-4 asm budget and per-step timeout, DEFERRED vs COMPILE_FAIL, the UNGRADED/NARROW/DEFERRED
# declarations re-asked both ways every run, the population pin, the inventory lockdown, the CEO-1286 denominator -- is
# documented in that file's header and is not restated here, so the two cannot drift apart in prose.
#
# THE ORACLE is sbl -bf and only sbl -bf: the x32 spitbol binary segfaults on hello world on this box (ceo CEO-1287).
# THE POPULATION is 21 .spt, converted once in the repo under CEO-571 and proven oracle-equivalent file by file
# (test_gate_spitbol_x32_case_conversion_is_oracle_equivalent.sh; the package's _PROVENANCE.md).
# Most are SPITBOL's own build-time filters and read INPUT: every program runs with /dev/null on stdin, the x64 precedent,
# so a filter's graded answer is its empty-input answer until declared stdin sidecars exist (owed, named in _PROVENANCE.md).
#
# Exit: 0 iff FAIL=0 in both modes over the graded population; rc=2 when it cannot measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
SUITE="${SPITBOL_X32_SUITE:-$ROOT/corpus/packages/snobol4/spitbol_x32_tests}"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
TIMEOUT="${TIMEOUT:-600}"; M4_ASM_MB="${SPITBOL_X32_M4_ASM_MB:-256}"; SHIPPED_EXPECT="${SPITBOL_X32_SHIPPED:-21}"
[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): suite dir missing: $SUITE"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT.  NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority.  A vendor board is exactly where a stale binary is least visible,
# because a plausible all-FAIL table is this class's normal output.
"$HERE/util_require_fresh.sh" --gate test_snobol4_spitbol_x32_suite "$SCRIP" "$RT_DIR/libscrip_rt.so" || exit 2
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
. "$HERE/lib_gate.sh"        2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_gate.sh unloadable"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh"   2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh"    2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; SBL_FLAGS="$(sbl_lang_flags)"
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): oracle absent: $SBL"; exit 2; }
sbl_assert_bf "$SBL" >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2): oracle at $SBL failed the -bf capability check"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSE(rc=2): mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
# ⛔ THE POPULATION PIN, this row's own refusal clause.  A fresh filesystem census every run, never a
# cached count, and a size that is not the vendored size refuses instead of grading.
SHIPPED=0; for f in "$SUITE"/*.spt; do [ -e "$f" ] && SHIPPED=$((SHIPPED+1)); done
if [ "$SHIPPED" != "$SHIPPED_EXPECT" ]; then
    echo "⛔ REFUSE(rc=2): globbed $SHIPPED .spt in $SUITE, expected $SHIPPED_EXPECT -- the vendored population moved."
    echo "    A third-party suite that changed size is a fact to look at, not one to average over.  Re-pin with SPITBOL_X32_SHIPPED=$SHIPPED once the change is understood and recorded in _PROVENANCE.md."
    exit 2
fi
# ⭐ EVERY RUN HAPPENS IN A SCRATCH COPY OF THE WHOLE PACKAGE, not in the vendored directory: these
# programs WRITE files (arcput, sv, save) and read data beside themselves (files, ru.txt, the two .inc
# includes), so a run in place would both dirty the corpus checkout and let one program's output become
# the next one's input.  The copy is made once and both engines run inside it.
RUN="$W/run"; mkdir -p "$RUN"; cp -R "$SUITE"/. "$RUN"/ 2>/dev/null
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(rc=2): lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$W/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSE(rc=2): a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
GRADED=0; UNGRADED_N=0; P3=0; F3=0; P4=0; F4=0; D4=0; BOTH=0; SELF=0; STREAM=0; XG_N=0; XG_LIST=""; XG_NAMES=""
FL3=""; FL4=""; UNG_LIST=""; DEFER_LIST=""; SELF_LIST=""; MASKED_TOTAL=0; MASKED_FIX=0; MASK_LINES=""
# ⭐ CEO-409 MASKS FROM THE ALL.mask BESIDE THE SUITE, through the one shim (util_apply_ceo409_mask.py, the harness's own body; CEO-432),
# wired here by ceo CEO-1351 for host's HOST() line -- the oracle's own identity, "x86-64:unix :Macro SPITBOL 15.01", which SCRIP does not
# impersonate (CEO-1344). Applied to both streams of the STREAM arm only, counted and printed; guardrail 4 is the harness's mask_majority()
# read back from the shim's .major, never restated here. No ALL.mask is the byte-identical stream (the shim's default-off arm).
stream_match() {  # stream_match <m3|m4> <rc>
    [ "$mask_major" = 1 ] && return 1
    python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/ALL.ref" "$name" "$W/$1.mn" --side=scrip < "$W/$1.out" > "$W/$1.cmp" || return 1
    gate_oracle_stdout_match "$W/o.cmp" "$W/$1.cmp" "$W/$1.err" "$2"
}
stream_note() {  # stream_note <PASS|FAIL> <rc>
    if [ "$1" = PASS ] && [ "$mask_n" -gt 0 ]; then echo "stream: byte-equal stdout vs live sbl -bf, $mask_n line(s) masked by ALL.mask, rc=$2 (oracle rc=$rcO)"
    elif [ "$1" = PASS ]; then echo "stream: byte-equal stdout vs live sbl -bf, rc=$2 (oracle rc=$rcO)"
    elif [ "$mask_major" = 1 ]; then echo "the mask covers $mask_n of $(grep -c '' "$W/o.out") oracle lines -- a majority-masked fixture is UNGRADABLE and belongs outside the baseline, named, not masked (CEO-409 guardrail 4)"
    else echo "stream: differs from live sbl -bf, rc=$2 (oracle rc=$rcO)"; fi
}
verdict_of() { if [ "$1" -eq 124 ]; then echo HANG; elif [ "$1" -ge 128 ]; then echo CRASH; else echo FAIL; fi; }
# ⭐ THE PROGRESS DATABASE (CEO-319/331, CEO-383 ruling 2): one row per program per mode, written once at
# the end through lib_progress.sh, said aloud either way, never a red board.  Recorded only for the
# canonical suite path or when S4E_PROGRESS_DB names a scratch table.
PROG_ROWS="$W/progress.tsv"; : > "$PROG_ROWS"
CANON_SUITE="$ROOT/corpus/packages/snobol4/spitbol_x32_tests"
PROG_RECORD=0; { [ "$SUITE" = "$CANON_SUITE" ] || [ -n "${S4E_PROGRESS_DB:-}" ]; } && PROG_RECORD=1
prog_row() { local o="$3"; [ "$o" = COMPILE_FAIL ] && o=FAIL; printf 'package\tspitbol_x32\tsnobol4\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$o" "$(progress_row_secs "$2")" "$4" >> "$PROG_ROWS"; }   # the progress table's vocabulary has no COMPILE_FAIL: a graded program our toolchain refused is a FAIL there, the note keeps the word (cfo 2026-09-12: the append refused the whole run's rows, so no x64 row was ever written)
verdict_lines() { grep -cE '^( pass: |\*FAIL: )' "$1" 2>/dev/null | tr -d ' '; }
pass_lines()    { grep -c '^ pass: '  "$1" 2>/dev/null | tr -d ' '; }
fail_lines()    { grep -c '^\*FAIL: ' "$1" 2>/dev/null | tr -d ' '; }
compile_m4() {  # compile_m4 <src> <out> [<compile_args>]; on failure echoes "<OUTCOME>\t<reason>", silent on success (hq_T's split: who decided)
    local sno="$1" out="$2" ca="${3:-}" rc sz
    # ⛔⭐ WHY AN INNER `bash -c` THAT DOES NOT `exec`, ON ALL FOUR RUN SITES.  bash announces a foreground
    # child killed by a signal ("Aborted", "File size limit exceeded") on the stderr of the shell that
    # WAITED on it, and half these programs abort by design of the defect under test -- so the notices
    # bury the board they are notices about.  Wrapping in `( ... ) 2>/dev/null` does NOT silence them
    # (measured): a subshell whose last command dies of a signal re-raises it, so the OUTER shell is the
    # announcer and its stderr is untouched.  An inner bash that runs the child as an ordinary command
    # is the waiter instead, and `2>/dev/null` on the timeout discards only that inner shell's own
    # diagnostics -- the child's stdout and stderr are redirected to files one level further in and
    # every byte of them survives.  rc still arrives intact (134, 153, 124).
    "$TIMEOUT_RETRY" "$TIMEOUT" bash -c 'cd "$1" || exit 2; ulimit -f "$2" 2>/dev/null; "$3" --compile $7 "$4" > "$5" 2> "$6"' _ "$RUN" "$((M4_ASM_MB * 1024))" "$SCRIP" "$sno" "$W/p.s" "$W/p.cerr" "$ca" 2>/dev/null; rc=$?
    sz="$(wc -c < "$W/p.s" 2>/dev/null || echo 0)"
    if [ "$rc" = 153 ]; then printf 'DEFERRED\tWE chose not to measure: mode-4 asm exceeded the declared %s MB budget (SIGXFSZ at %s bytes); raise SPITBOL_X32_M4_ASM_MB to grade it\n' "$M4_ASM_MB" "$sz"; return 1; fi
    if [ "$rc" = 124 ]; then printf 'DEFERRED\tWE chose not to measure: mode-4 compile hit the declared %ss timeout (asm at %s bytes); raise TIMEOUT to grade it\n' "$TIMEOUT" "$sz"; return 1; fi
    if [ "$rc" != 0 ]; then printf 'COMPILE_FAIL\tOUR compiler refused a graded program, rc=%s: %s\n' "$rc" "$(head -1 "$W/p.cerr" 2>/dev/null | cut -c1-100)"; return 1; fi
    gcc -c "$W/p.s" -o "$W/p.o" 2>"$W/p.cerr" || { printf 'COMPILE_FAIL\tOUR assembler refused %s bytes of our own asm: %s\n' "$sz" "$(head -1 "$W/p.cerr" | cut -c1-100)"; return 1; }
    gcc "$W/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>"$W/p.cerr" || { printf 'LINK_FAIL\tOUR link of a graded program failed: %s\n' "$(grep -m1 'undefined reference' "$W/p.cerr" | sed 's/.*undefined reference/undefined reference/' | cut -c1-80)"; return 1; }
    rm -f "$W/p.s" "$W/p.o"
    return 0
}
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one chunk or a request's entries, rows as each test ends
for sno in "$SUITE"/*.spt; do
    _rrn="$(basename "$sno")"; _rrn="${_rrn%.*}"; rr_admits "$_rrn" || continue; rr_yield "$_rrn" && break; [ "$PROG_RECORD" = 1 ] && rr_flush "$PROG_ROWS"
    name="$(basename "$sno" .spt)"; base="$(basename "$sno")"; ROW_S3=0; ROW_S4=0   # each mode's own wall for its row (CEO-1676 (c))
    export S4E_TIMEOUT_KEY="$name"   # the unit a retried timeout's stamp names (CEO-1335)
    # ⛔ THE ORACLE FIRST, AND IT DECIDES BOTH WHETHER AND HOW.  Whether: a program our mandated -bf arm
    # cannot get an answer for is UNGRADED (work owed, declared in UNGRADED.tsv).  How: whether its own
    # run carried verdict lines picks the instrument.  Nothing here is read off a name.
    "$TIMEOUT_RETRY" "$TIMEOUT" bash -c 'cd "$1" || exit 2; "$2" $3 "$4" < /dev/null > "$5" 2> "$6"' _ "$RUN" "$SBL" "$SBL_FLAGS" "$base" "$W/o.out" "$W/o.err" 2>/dev/null; rcO=$?
    if grep -q 'No END statement found' "$W/o.out" "$W/o.err" 2>/dev/null; then
        UNGRADED_N=$((UNGRADED_N+1)); UNG_LIST="${UNG_LIST}${base}\tORACLE_FAIL\tsbl -bf rc=$rcO \"No END statement found in source file(s).\"\n"
        prog_row "$name" m3 UNGRADED "the oracle gives no answer under sbl -bf: No END statement found"
        prog_row "$name" m4 UNGRADED "the oracle gives no answer under sbl -bf: No END statement found"; continue
    fi
    if grep -qE 'ERROR 0*22 -- [Uu]ndefined function called' "$W/o.out" "$W/o.err" 2>/dev/null; then
        UNGRADED_N=$((UNGRADED_N+1)); UNG_LIST="${UNG_LIST}${base}\tORACLE_FAIL\tsbl -bf parses it and then raises ERROR 022 -- undefined function called (the name lives inside an EVAL'd string literal)\n"
        prog_row "$name" m3 UNGRADED "the oracle raises ERROR 022 under sbl -bf: the name lives inside an EVAL'd string literal"
        prog_row "$name" m4 UNGRADED "the oracle raises ERROR 022 under sbl -bf: the name lives inside an EVAL'd string literal"; continue
    fi
    GRADED=$((GRADED+1))
    # ⛔ AN EXCLUDED PROGRAM THE ORACLE RUNS (EXCLUDED.tsv class DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27, ceo CEO-1345: EXIT(3,file)'s
    # resumable load module, Lon: "will be done but after the announcement") is still graded and its verdicts named below, but it
    # leaves pass, fail, rc and the denominator; it returns to them the day its row lands and its EXCLUDED.tsv row is deleted.
    isx=0; inventory_is_excluded "$SUITE" "$base" && isx=1
    oracle_v="$(verdict_lines "$W/o.out")"; oracle_p="$(pass_lines "$W/o.out")"; oracle_f="$(fail_lines "$W/o.out")"
    if [ "$oracle_v" -gt 0 ]; then ARM=self; SELF=$((SELF+1)); SELF_LIST="${SELF_LIST}${base}\n"; else ARM=stream; STREAM=$((STREAM+1)); fi
    mask_major=0; mask_n=0
    if [ "$ARM" = stream ]; then
        python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/ALL.ref" "$name" "$W/o.mn" --side=oracle < "$W/o.out" > "$W/o.cmp" \
            || { echo "⛔ REFUSE(rc=2): $base -- the CEO-409 mask sidecar beside $SUITE is refused (the reason above); a mask nobody can audit grades nothing"; exit 2; }
        mask_n="$(cat "$W/o.mn")"; mask_major="$(cat "$W/o.mn.major")"
        [ "$mask_n" -gt 0 ] && { MASKED_TOTAL=$((MASKED_TOTAL+mask_n)); MASKED_FIX=$((MASKED_FIX+1)); MASK_LINES="${MASK_LINES}  MASKED  $base  $mask_n line(s) of $(grep -c '' "$W/o.out"), declared in ALL.mask beside the suite (CEO-409; an ORACLE-IDENTITY row is CEO-1344/CEO-1351)\n"; }
    fi
    # --- mode 3
    ca="$(declared_compile_args_from_table "$DECL" "$name")" || exit 2
    _t0="$(progress_clock)"
    run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$TIMEOUT" bash -c 'cd "$1" || exit 2; "$2" --run $6 "$3" < /dev/null > "$4" 2> "$5"' _ "$RUN" "$SCRIP" "$base" "$W/m3.out" "$W/m3.err" "$ca" 2>/dev/null; rc3=$?
    ROW_S3="$(progress_secs_since "$_t0")"
    if [ "$rc3" -eq 124 ] || [ "$rc3" -ge 128 ]; then OUT3="$(verdict_of "$rc3")"; N3="rc=$rc3: $(head -1 "$W/m3.err" | cut -c1-90)"
    elif [ "$ARM" = self ]; then
        sp="$(pass_lines "$W/m3.out")"; sf="$(fail_lines "$W/m3.out")"
        if [ "$sf" = 0 ] && [ "$sp" = "$oracle_p" ] && [ "$oracle_f" = 0 ]; then OUT3=PASS; N3="self-check: $sp pass, 0 FAIL, oracle $oracle_p/0"
        else OUT3=FAIL; N3="self-check: $sp pass / $sf FAIL against the oracle's $oracle_p pass / $oracle_f FAIL"; fi
    else
        if stream_match m3 "$rc3"; then OUT3=PASS; else OUT3=FAIL; fi; N3="$(stream_note "$OUT3" "$rc3")"
    fi
    if [ "$isx" = 1 ]; then :; elif [ "$OUT3" = PASS ]; then P3=$((P3+1)); else F3=$((F3+1)); FL3="$FL3 $name($OUT3)"; fi
    # --- mode 4
    _t0="$(progress_clock)"
    m4why=""; if m4why="$(compile_m4 "$base" "$W/prog.bin" "$ca")"; then
        run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$TIMEOUT" bash -c 'cd "$1" || exit 2; "$2" < /dev/null > "$3" 2> "$4"' _ "$RUN" "$W/prog.bin" "$W/m4.out" "$W/m4.err" 2>/dev/null; rc4=$?
        if [ "$rc4" -eq 124 ] || [ "$rc4" -ge 128 ]; then OUT4="$(verdict_of "$rc4")"; N4="rc=$rc4: $(head -1 "$W/m4.err" | cut -c1-90)"
        elif [ "$ARM" = self ]; then
            sp="$(pass_lines "$W/m4.out")"; sf="$(fail_lines "$W/m4.out")"
            if [ "$sf" = 0 ] && [ "$sp" = "$oracle_p" ] && [ "$oracle_f" = 0 ]; then OUT4=PASS; N4="self-check: $sp pass, 0 FAIL, oracle $oracle_p/0"
            else OUT4=FAIL; N4="self-check: $sp pass / $sf FAIL against the oracle's $oracle_p pass / $oracle_f FAIL"; fi
        else
            if stream_match m4 "$rc4"; then OUT4=PASS; else OUT4=FAIL; fi; N4="$(stream_note "$OUT4" "$rc4")"
        fi
        if [ "$isx" = 1 ]; then :; elif [ "$OUT4" = PASS ]; then P4=$((P4+1)); else F4=$((F4+1)); FL4="$FL4 $name($OUT4)"; fi
    else
        OUT4="${m4why%%	*}"; N4="${m4why#*	}"
        if [ "$isx" = 1 ]; then :; elif [ "$OUT4" = DEFERRED ]; then D4=$((D4+1)); DEFER_LIST="$DEFER_LIST $name"
        else F4=$((F4+1)); FL4="$FL4 $name($OUT4)"; fi
    fi
    [ "$isx" = 0 ] && [ "$OUT3" = PASS ] && [ "$OUT4" = PASS ] && BOTH=$((BOTH+1))
    [ "$isx" = 1 ] && { XG_N=$((XG_N+1)); XG_LIST="$XG_LIST $name(m3=$OUT3,m4=$OUT4)"; XG_NAMES="$XG_NAMES $base"; }
    ROW_S4="$(progress_secs_since "$_t0")"
    prog_row "$name" m3 "$OUT3" "$N3"; prog_row "$name" m4 "$OUT4" "$N4"
done
GC=$((GRADED - XG_N))
echo "SPITBOL_X32_BOARD shipped=$SHIPPED graded=$GRADED excluded_graded=$XG_N ungraded=$UNGRADED_N m3_pass=$P3 m3_fail=$F3 m4_pass=$P4 m4_fail=$F4 m4_deferred=$D4 self_check_arm=$SELF stream_arm=$STREAM -- SCRIP $SCRIP_HASH corpus $CORP_HASH RT_OPT=-O0 oracle=sbl-bf timeout=${TIMEOUT}s m4_asm_budget=${M4_ASM_MB}MB"
echo "SPITBOL_X32_AND both_modes_pass=$BOTH/$GC -- the suite table states this reading (ceo-372: the AND per program; a timed-out or crashed run is HANG/CRASH, never PASS, whatever its stream; a mode 4 we DEFERRED on a declared threshold is never PASS either, and one OUR OWN toolchain could not build is COMPILE_FAIL/LINK_FAIL and counts in m4_fail, never in a bucket beside it -- hq_T 2026-09-12)"
# ⛔ THE ROW'S OWN CLAUSE: the population, said in one line, with the remainder NAMED rather than counted.
echo "SPITBOL_X32_POPULATION graded $GRADED of $SHIPPED shipped -- the ungraded remainder ($UNGRADED_N), each with the oracle's own words:"
if [ "$UNGRADED_N" -gt 0 ]; then printf '%b' "$UNG_LIST" | sed 's/^/UNGRADED\t/'; else printf 'UNGRADED\t(none -- every shipped program is graded)\n'; fi
[ -n "$DEFER_LIST" ] && echo "M4-DEFERRED (WE chose not to measure, each carrying its threshold -- asm over ${M4_ASM_MB}MB or the ${TIMEOUT}s compile timeout; never a pass, and never our failure either):$DEFER_LIST"
[ "$XG_N" -gt 0 ] && echo "EXCLUDED-GRADED (named in EXCLUDED.tsv and run anyway, out of pass, fail, rc and the denominator -- ceo CEO-1345):$XG_LIST"
echo "SPITBOL_X32_MASKS masked_lines=$MASKED_TOTAL in $MASKED_FIX fixture(s) -- CEO-409 masks declared in ALL.mask beside the suite, counted, the fixture staying in the denominator"
printf '%b' "$MASK_LINES"
[ -n "$FL3" ] && echo "FAIL-M3:$FL3"
[ -n "$FL4" ] && echo "FAIL-M4:$FL4"
# ⭐ THE DECLARATION, RE-ASKED EVERY RUN.  UNGRADED.tsv is the authority on which programs are owed (a
# runner may not decide that at run time), but a declaration nobody re-measures is how a list outlives
# the fact it recorded -- the coo's own board rule this week, off gimpel's OUTSIDE_SPITBOL_BASELINE.tsv
# naming sixteen programs as unanswerable by an oracle that now answers them.  So: measured set vs
# declared set, both directions, said aloud, never a red board.
UNG_TSV="$SUITE/UNGRADED.tsv"
if [ -f "$UNG_TSV" ]; then
    # ⛔ grep . ON BOTH OPERANDS, ALWAYS.  `printf '%s\n' "$empty"` emits ONE BLANK LINE, and comm counts
    # it as a member -- so an empty declared or measured set manufactured a warning that named nothing.
    # Measured here the first run after the sibling case-conversion row landed and the ungraded set went to
    # zero: the STALE line was right and the UNRECORDED line beside it was an artifact of the blank.
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$UNG_TSV" | grep . | sort)"
    live="$(printf '%b' "$UNG_LIST" | cut -f1 | grep . | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec" | grep .) <(printf '%s\n' "$live" | grep .) | tr '\n' ' ')"
    unrec="$(comm -13 <(printf '%s\n' "$rec" | grep .) <(printf '%s\n' "$live" | grep .) | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ UNGRADED.tsv STALE -- declared as unanswerable under sbl -bf, but the oracle answered them cleanly this run; they are graded now, so delete their rows: $stale"
    [ -n "$unrec" ] && echo "⚠ UNGRADED.tsv UNRECORDED -- the oracle gave no answer for these under sbl -bf and the declaration does not name them; add a row each with the oracle's own words: $unrec"
    [ -z "$stale$unrec" ] && echo "UNGRADED.tsv agrees with the measured ungraded set ($UNGRADED_N)"
else echo "⚠ no UNGRADED.tsv beside the suite -- the ungraded set above is measured, not yet declared"; fi
# ⭐⭐ AND THE SAME RE-ASKING FOR THE NARROW BUCKET, WHICH IS THE ONE NOBODY WOULD THINK TO RE-ASK.  The
# self-check arm is graded_narrow, not graded_stream: it reads " pass:"/"*FAIL:" counts and therefore
# cannot see the Obs[]/Exp[] text (NARROW.tsv states exactly that, per entry).  ⛔ The arm is CHOSEN by
# measurement and the declaration is a FILE, so the two drift the moment the graded set moves -- and it
# is about to: nine more math files join the self-check set when the case-conversion row lands.  The
# inventory would refuse on the count mismatch, but a refusal names the count, not the names, so the
# cross-check below names them.  Same discipline as UNGRADED.tsv above, both directions, never a red board.
NAR_TSV="$SUITE/NARROW.tsv"
if [ -f "$NAR_TSV" ]; then
    nrec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$NAR_TSV" | grep . | sort)"
    nlive="$(printf '%b' "$SELF_LIST" | grep . | sort)"
    nstale="$(comm -23 <(printf '%s\n' "$nrec" | grep .) <(printf '%s\n' "$nlive" | grep .) | tr '\n' ' ')"
    nunrec="$(comm -13 <(printf '%s\n' "$nrec" | grep .) <(printf '%s\n' "$nlive" | grep .) | tr '\n' ' ')"
    [ -n "$nstale" ] && echo "⚠ NARROW.tsv STALE -- declared as graded by their own verdict lines, but the oracle printed none for them this run (they are stream-graded now, or no longer graded at all): $nstale"
    [ -n "$nunrec" ] && echo "⚠ NARROW.tsv UNRECORDED -- these were graded on their own verdict lines and the declaration does not name them; add a row each saying what that comparison does not see: $nunrec"
    [ -z "$nstale$nunrec" ] && echo "NARROW.tsv agrees with the measured self-check set ($SELF)"
elif [ "$SELF" -gt 0 ]; then echo "⚠ no NARROW.tsv beside the suite -- $SELF programs were graded by a comparison narrower than the percent claims, and nothing declares which"; fi
# ⭐ THE PACKAGE LOCKDOWN (Lon 2026-09-06): graded + ungraded + ungradable must equal shipped, or a
# program is in no bucket at all and appears in no number.  lib_inventory.sh recomputes every bucket
# itself from the sidecars rather than trusting this runner's counters.
INV_PACKAGE=spitbol_x32; INV_DIR="$SUITE"; INV_EXT=".spt"
if ! rr_selected; then   # a chunk grades a part of the package, and the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$STREAM" "$SELF")"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
if [ "$PROG_RECORD" = 1 ]; then
    progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS ROWS NOT RECORDED (writer rc=$? above) -- a run that leaves the table untouched is a defect of that run (progress/README.md), not a red board" >&2
else echo "progress: scratch suite $SUITE -- $(grep -c . "$PROG_ROWS") row(s) NOT recorded (only the canonical suite, or S4E_PROGRESS_DB, records)"; fi
rr_selected && { rr_end x32tests; exit 0; }   # a chunk or a request writes its rows and no suite row (CEO-1802)
# ⛔⭐ AN EXCLUSION NOBODY SIGNED IS NOT AN EXCLUSION -- THE DEFERRAL DECLARATION, RE-ASKED BOTH WAYS.  The
# split above stopped a DEFERRED program from redding the board, which is right (WE chose not to measure it)
# and is ALSO a loosening: without this block, a deferral is a silent exclusion that keeps a green rc, the
# exact shape of the skip-as-success it replaced.  So a deferral has to be DECLARED beside the suite with its
# threshold, the same contract UNGRADED.tsv carries above -- an UNDECLARED deferral blocks (it is a new fact,
# not a standing decision), and a declaration the run did not reproduce is said aloud so the list cannot
# outlive the fact.  ⛔ The FORMAT here is this suite's own; the lane-wide DEFERRED.tsv standard and its
# re-ask cadence are hq_T's row (CEO-597) and this does not anticipate them.
DEF_TSV="$SUITE/DEFERRED.tsv"; DEF_UNDECLARED=""
dlive="$(printf '%s\n' $DEFER_LIST | grep . | sort)"
if [ -f "$DEF_TSV" ]; then
    drec="$(awk -F'\t' 'NF>1 && $1 !~ /^#/{print $1}' "$DEF_TSV" | grep . | sort)"
    dstale="$(comm -23 <(printf '%s\n' "$drec" | grep .) <(printf '%s\n' "$dlive" | grep .) | tr '\n' ' ')"
    DEF_UNDECLARED="$(comm -13 <(printf '%s\n' "$drec" | grep .) <(printf '%s\n' "$dlive" | grep .) | tr '\n' ' ')"
    [ -n "$dstale" ] && echo "⚠ DEFERRED.tsv STALE -- declared as over a threshold, but they were graded this run; delete their rows: $dstale"
    [ -z "$dstale$DEF_UNDECLARED" ] && echo "DEFERRED.tsv agrees with the measured deferred set ($D4)"
else DEF_UNDECLARED="$dlive"; fi
if [ -n "$DEF_UNDECLARED" ]; then
    echo "⛔ UNDECLARED DEFERRAL -- mode 4 was not measured for these and nothing beside the suite says we decided that:$(printf ' %s' $DEF_UNDECLARED)"
    echo "    A deferral is a decision with a threshold, so it is recorded or it is red.  Add a row each to $DEF_TSV (name<TAB>threshold<TAB>why), or cure the program."
fi
# ⛔⭐ POPULATION FLOOR: F3/F4/D4 all read 0 over zero graded entries too (the oracle refusing every
# program would do it), so refuse before the vacuous-clean verdict below can be reached.
"$HERE/util_require_population.sh" --gate test_snobol4_spitbol_x32_suite "$GRADED" 1 "graded programs (shipped=$SHIPPED ungraded=$UNGRADED_N deferred_m4=$D4)" || exit 2
if [ "$SUITE" = "$CANON_SUITE" ]; then
# ⛔⭐ CEO-1286 (Lon 2026-09-26): the denominator is SHIPPED minus the programs NOT IN THE SPITBOL DIALECT (EXCLUDED.tsv) -- none here, the
# 36 are our oracle's own upstream tests -- so the row publishes over shipped, the unreadable ones named in UNGRADED.tsv as debt.
. "$HERE/lib_outside_shape.sh" || exit 2
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(printf '%b' "${UNG_LIST:-}" | cut -f1) $XG_NAMES")" || exit 2; DENOM=$((SHIPPED - EXCL_D_N))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set and its $XG_N excluded-graded program(s) (CEO-1345) leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || { _cc="$(excluded_shape_stamp x32tests "$DENOM" "$UNGRADED_N" "$EXCL_D_N")" || exit 2; [ "$XG_N" -gt 0 ] && _cc="${_cc/not-in-the-SPITBOL-dialect-named-in-EXCLUDED.tsv/named-in-EXCLUDED.tsv-$((EXCL_D_N - XG_N))-not-in-the-SPITBOL-dialect-CEO-1286-and-$XG_N-deferred-after-the-announcement-by-Lons-word-CEO-1345}"; }
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite x32tests --suite-key x32tests --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" --suite-pass "$BOTH" --suite-total "$DENOM" --excluded "$EXCL_D_N" \
    --text "spitbol_x32 both_modes_pass=$BOTH/$DENOM ($SHIPPED shipped minus EXCLUDED=$EXCL_D_N named in EXCLUDED.tsv: not in the SPITBOL dialect, CEO-1286, or $XG_N deferred after the announcement by Lon's word, graded and named, CEO-1345; $GRADED graded) (the table's reading: the ceo-372 AND per program · $SELF graded by the programs' OWN \" pass:\"/\"*FAIL:\" verdict lines, $STREAM by live oracle stdout diff · $UNGRADED_N of $SHIPPED shipped still unreadable by our mandated sbl -bf, named in UNGRADED.tsv and owed to the case-conversion row) · m3 $P3/$GC · m4 $P4/$GC ($D4 m4 DEFERRED on the declared ${M4_ASM_MB}MB asm budget; a program our own toolchain could not build is COMPILE_FAIL/LINK_FAIL and counts in m4_fail, hq_T 2026-09-12) · masked_lines=$MASKED_TOTAL in $MASKED_FIX fixture(s) (CEO-409 ALL.mask; host's HOST() line is the oracle's own identity, CEO-1344/CEO-1351) · sbl -bf the one oracle${INV_LINE:+ · $INV_LINE} (\`test_snobol4_spitbol_x32_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
else echo "SCORE.md: scratch suite $SUITE -- not written (only the canonical suite records the leaderboard)"; fi
[ "$F3" = 0 ] && [ "$F4" = 0 ] && [ -z "$DEF_UNDECLARED" ]
