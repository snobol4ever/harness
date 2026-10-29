#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${PAT_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/pascal/pat}" || exit 2
# test_pascal_pat_suite.sh — THE ISO 7185 PASCAL DENOMINATOR (row pascal-iso-7185-validation-suite-pat-vendored-and-graded).
# Lon 2026-09-03 20:45: "100% means 100% of the industry standard language." For Pascal the standard is ISO 7185 and the
# public suite that grades it is the Pascal-P5 validation suite, vendored at corpus/packages/pascal/pat (see its README).
#
# TWO POPULATIONS, GRADED BY DIFFERENT QUESTIONS — that is the whole design, not a detail:
#   iso7185prt*  (427)  REJECTION tests. Each carries ONE deliberate violation. A conforming implementation must REFUSE it.
#                       PASS = scrip exits non-zero WITH a diagnostic.  FAIL = scrip accepts it.
#   iso7185pat*  (1)    ACCEPTANCE test. A large conforming program. Graded against `fpc -Miso` as the oracle.
#
# ⛔ THE .cmp/.ecp FILES ARE NOT THE ORACLE AND ARE NEVER DIFFED. They are Pascal-P5's own transcript and open with its
# banner ("P5 Pascal compiler vs. 1.4.x"). Diffing SCRIP against them would grade SCRIP on whether it is P5.
#
# ⛔⭐ A CRASH IS NOT A REJECTION, AND THIS IS THE ONE PLACE THAT DISTINCTION DECIDES THE BOARD. The obvious test for
# "did it reject?" is `rc != 0` — and under it a SIGSEGV scores as a CORRECT REJECTION, because a crashing compiler exits
# non-zero on every malformed program. That would turn the suite's whole point inside out: the worse the compiler behaves,
# the better it scores. Signals (rc >= 128) are counted as CRASH and are NEVER passes; a timeout (rc 124) likewise.
set -u
GATE_NAME=test_pascal_pat_suite
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${PAT_SUITE:-$ROOT/corpus/packages/pascal/pat}"   # line 2 sets it to this default, so the guard judges the suite graded here
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE -- a suite that is absent is not a suite that is failing"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_pascal_pat_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_inventory.sh" 2>/dev/null || refuse "lib_inventory.sh unloadable"
. "$HERE/lib_progress.sh" 2>/dev/null || refuse "lib_progress.sh unloadable"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing (the acceptance programs carry no row today); a refused cell
# refuses the board. The oracle (fpc -Miso) runs as before.
. "$HERE/lib_declared_arena.sh" || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"
DECL="$TMP/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || refuse "a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"
declare -A P F C
for m in m3 m4; do P[$m]=0; F[$m]=0; C[$m]=0; done
TOTAL=0; NAMED=""; UNGRADABLE=0
PROG_ROWS="$TMP/progress.tsv"; : >"$PROG_ROWS"
# ⛔⭐ THE CEO-749 SHAPE FOR A REJECTION TEST THAT CARRIES NO ISO VIOLATION (ceo CEO-1231, 2026-09-24, on hq_pascal's ask
# q-pascal-pat-1834-and-1850-carry-no-iso-violation). OUTSIDE_ISO_BASELINE.tsv beside the package names each iso7185prt program whose
# supposed violation ISO 7185 does not make an error (CLASS not-an-iso-error; Pascal-P5's own transcript reads "Errors in program: 0"),
# with that measurement. A listed program STAYS IN THE DENOMINATOR (PASS over SHIPPED, OUTSIDE=k named and stamped through
# lib_outside_shape.sh) and is not graded as a rejection -- but it is CROSS-CHECKED on every run the other way round: a conforming
# compiler ACCEPTS it, so SCRIP must compile it without an ISO diagnostic, and one SCRIP refuses is reported STALE and graded like any
# other rejection test. The ceiling is TOTAL - OUTSIDE by ruling, never by silence.
OUTSIDE_TSV="$SUITE/OUTSIDE_ISO_BASELINE.tsv"; declare -A OUTSIDE_SET=(); OUTSIDE=0; OUTSIDE_NAMES=(); STALE_NAMES=()
if [ -f "$OUTSIDE_TSV" ]; then
    while IFS=$'\t' read -r _on _orest; do case "$_on" in ''|'#'*) continue;; esac; OUTSIDE_SET[${_on%.pas}]=1; done < "$OUTSIDE_TSV"
fi
# ⛔⭐ A REJECTION TEST THE ORACLE ACCEPTS IS GRADED AS AN ACCEPTANCE TEST (ceo CEO-1269, 2026-09-25, superseding CEO-1231's
# OUTSIDE ruling for iso7185prt1834/1850 on hq_pascal's ask). fpc -Miso accepts both and runs them rc 0, so each has an oracle
# output and is graded exactly like the acceptance population below -- PASS when SCRIP prints the oracle's output in both modes,
# FAIL otherwise, in the denominator. ISO_ACCEPTS.tsv beside the package names them; this loop skips them and the acceptance
# loop grades them, so TOTAL is unchanged. (b) -- a DONE-WHEN that subtracts OUTSIDE -- was refused: it narrows the denominator.
ACCEPT_TSV="$SUITE/ISO_ACCEPTS.tsv"; declare -A ACCEPT_SET=(); ACCEPT_FILES=()
if [ -f "$ACCEPT_TSV" ]; then
    while IFS=$'\t' read -r _an _arest; do case "$_an" in ''|'#'*) continue;; esac
        [ -f "$SUITE/$_an" ] || refuse "ISO_ACCEPTS.tsv names $_an, which is not in $SUITE"; ACCEPT_SET[${_an%.pas}]=1; ACCEPT_FILES+=("$SUITE/$_an"); done < "$ACCEPT_TSV"
fi
# ⛔⭐⭐ A PASS A BROKEN ENGINE CAN EARN IS NOT A PASS (Lon 2026-10-21 16:5x CDT, in-chat to the coo, verbatim: "I suspect you know not what you are
# doing and are measuring failure not success." · "You better fix your flawed measurement system for the test suites."; his ruling on the coo's
# question, "Tighten, else exclude"; ceo CEO-1865). MEASURED by util_false_green_census.sh on harness 54425c7: an engine whose every program prints
# an error and exits 1 earned 417 rejection tests here (834 PASS rows, every refused-with-a-diagnostic PASS of the real table), because a refusal
# passed on ANY non-zero exit with ANY output; an engine that prints nothing earned iso7185prt1702c and prt1850, whose oracle answer is no output.
# THE TIGHTENED VERDICT: a rejection test passes only when SCRIP's refusal NAMES ITS REASON -- the source line Pascal-P5's reference transcript marks
# for a COMPILE-TIME test (its .ecp marks "N ****"; within one line, since P5 marks the token that detects the error and that token is often the
# next line's), or an ISO 7185 clause ("ISO 7185 6.2.1 violation: ...", "pascal runtime error: ISO 7185 6.6.6.2: ..."). Any clause, not the one a
# RUN-TIME test's header cites: measured on 77fe69586, the headers' numbers are not reliable (prt1733's ln(x) cites 6.6.5.2, the clause is 6.6.6.2,
# which SCRIP names). Neither stub engine names a line or a clause, and neither does a generic "error 262: division caused real overflow". A test
# with no marked line and no clause in its header, and a test whose oracle answer is empty, cannot tell SCRIP from a broken engine: it is EXCLUDED
# as CEO-1696 rules, its answer not known in any form a refusal can be checked against (EXCLUDED.tsv class NO_ORACLE_ANSWER, an iso7185prt* row,
# with what it lacks), never debt and never a pass.
declare -A FAKE_SET=()
[ -f "$SUITE/EXCLUDED.tsv" ] && while IFS=$'\t' read -r _fn _fc _frest; do case "$_fn" in iso7185prt*) [ "$_fc" = NO_ORACLE_ANSWER ] && FAKE_SET[${_fn%.pas}]=1;; esac; done < "$SUITE/EXCLUDED.tsv"
prt_want() {  # f: "line N..." (the .ecp's marked lines) | "clause X..." (the header's ISO 7185 reference) | "" (nothing a refusal can be checked against)
    local _l _c
    _l="$(awk '/^[ \t]*[0-9]+[ \t]+\*\*\*\*/ {print $1}' "${1%.pas}.ecp" 2>/dev/null | sort -un | tr '\n' ' ')"
    [ -n "${_l// /}" ] && { echo "line $_l"; return; }
    _c="$(sed -n 's/.*ISO 7185 reference:[[:space:]]*//p' "$1" | grep -oE '[0-9]+(\.[0-9]+)+' | tr '\n' ' ')"
    [ -n "${_c// /}" ] && { echo "clause $_c"; return; }
    echo ""
}
prt_refusal_names_it() {  # want output-file: prints what the refusal named (a marked line, +-1, or an ISO 7185 clause), or fails
    local _k="${1%% *}" _v="${1#* }" _x _c
    if [ "$_k" = line ]; then
        for _x in $_v; do
            for _c in $((_x - 1)) "$_x" $((_x + 1)); do grep -qE "line $_c([^0-9]|\$)" "$2" && { echo "line-$_c"; return 0; }; done
        done
    fi
    _c="$(grep -oE 'ISO 7185 [0-9]+(\.[0-9]+)+' "$2" | head -1 | sed 's/ISO 7185 //')"
    [ -n "$_c" ] && { echo "clause-$_c"; return 0; }
    return 1
}
# ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06), accumulated across BOTH populations below -- the rejection
# tests and the acceptance tests -- because both feed the one TOTAL this row is stated over. A per-program
# accumulator is the only shape that survives two loops; a post-hoc min() of P[m3] and P[m4] would not even be
# wrong in a detectable way, since it is not a count of any set of programs.
BOTH=0
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one part or a request's entries, rows as each test ends
# ---- rejection population -------------------------------------------------------------------------------------------
for f in "$SUITE"/iso7185prt*.pas; do
    [ -e "$f" ] || continue
    b="$(basename "$f" .pas)"; rr_admits "$b" || continue; rr_yield "$b" && { RR_STOP=1; break; }; rr_flush "$PROG_ROWS"
    [ -n "${ACCEPT_SET[$b]:-}" ] && continue; [ -n "${FAKE_SET[$b]:-}" ] && continue; TOTAL=$((TOTAL+1)); okboth=1
    WANT="$(prt_want "$f")"
    [ -n "$WANT" ] || refuse "$b carries no marked line in its .ecp and no ISO 7185 reference in its header, and EXCLUDED.tsv does not name it NO_ORACLE_ANSWER -- a refusal of it cannot be checked (Lon 2026-10-21, tighten else exclude)"
    export S4E_TIMEOUT_KEY="$b"   # the unit a retried timeout's stamp names (CEO-1335)
    if [ -n "${OUTSIDE_SET[$b]:-}" ]; then
        _oerr="$(cd "$TMP" && "$TIMEOUT_RETRY" 8s "$SCRIP" --dump-ast "$f" </dev/null 2>&1 >/dev/null)"; _orc=$?
        if [ "$_orc" -eq 0 ] && ! printf '%s' "$_oerr" | grep -q 'ISO 7185'; then
            OUTSIDE=$((OUTSIDE+1)); OUTSIDE_NAMES+=("$b")
            for m in m3 m4; do printf 'package\tpat\tpascal\t%s\t%s\tUNGRADED\t0\toutside-iso-baseline-not-an-iso-error\n' "$b" "$m" >>"$PROG_ROWS"; done
            continue
        fi
        STALE_NAMES+=("$b")
    fi
    for m in m3 m4; do
        # ⛔⭐ A TIMEOUT ON A REJECTION TEST IS "ACCEPTED", NOT "CRASHED" — and the 2s bound is a CONSEQUENCE of that,
        # not a guess. A program the front end refuses dies in ~10ms; one that reaches the timeout is one scrip
        # AGREED TO RUN, which is already the FAIL this test is looking for. Measured, not assumed: the first cut of
        # this runner used 8s and `rc>=124 => CRASH`, and the m3 arm then EXECUTED all 143 wrongly-accepted programs
        # for 8s each -- a >19-minute runner that also mislabelled its own headline defect as a crash.
        # ⛔⭐ RUN IN A SCRATCH CWD, NEVER IN THE WORKING TREE. A rejection test that scrip WRONGLY ACCEPTS is
        # then EXECUTED -- and these are ISO 7185 programs that do file I/O, so their side effects land wherever
        # the runner happens to stand. MEASURED: this left an empty file named `0` in SCRIP/ on every run, which
        # made the tree dirty, which made util_score_row.py correctly REFUSE to write the leaderboard row --
        # so the suite's own debris silently blocked the FACT RULE the suite exists to satisfy. ⭐ The general
        # form: a runner that executes its subjects in the repo root has made the repo part of the experiment.
        # ⛔⭐⭐ THE m4 ARM COMPILES, LINKS AND RUNS -- IT USED TO ONLY COMPILE, AND THAT WAS A FALSE READING, NOT A
        # CHEAP ONE (hq_pascal 2026-09-16, cfo ruling, ceo copied; INSTRUMENT CHANGE in the CEO-749 shape, never a cure).
        # `--compile --out=/dev/null` answers "was it refused AT COMPILE TIME", so a witness whose ISO condition fires at
        # RUN time could never fail this arm -- and most of a REJECTION suite is runtime conditions. MEASURED: eleven
        # witnesses cured on 2026-09-16 (1826/1827/1842 statically, 1709/1710/1712/1714/1715/1716/1740/1757 at run time)
        # moved both_pass by ONE, because the m4 column floored it. The acceptance arm below ALREADY compiles, links and
        # runs; only the rejection arm was asymmetric. ⭐ THE GENERAL FORM, which is why this is worth eight lines: an
        # instrument that can observe only one half of a cure reports the other half as absent FOREVER, and it does not
        # get louder as the cure lands -- it gets quieter, because the cure it cannot see keeps arriving.
        # ⛔ A LINK FAILURE IS NOT A REFUSAL: the compiler accepted the program, so the witness FAILS (it was not
        # refused) rather than passing on a toolchain accident. test_gate_pas_pat_m4_arm_links_and_runs.sh pins this.
        _t0="$(progress_clock)"   # the mode's own wall for its row (CEO-1676 (c)): m4's takes its compile and link
        if [ "$m" = m3 ]; then ( cd "$TMP" && run_at_declared_table "$DECL" "$b" -- "$TIMEOUT_RETRY" 2s "$SCRIP" "$f" </dev/null >"$TMP/o" 2>&1 ); rc=$?
        else ( cd "$TMP" && exec "$TIMEOUT_RETRY" 8s "$SCRIP" --compile --out="$TMP/rj.s" "$f" </dev/null >"$TMP/o" 2>&1 ); rc=$?
             if [ "$rc" = 0 ]; then
                 if ( cd "$TMP" && cc -m64 -no-pie rj.s -o rj -L"$HERE/../../SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$HERE/../../SCRIP/out" >/dev/null 2>&1 ); then
                     ( cd "$TMP" && run_at_declared_table "$DECL" "$b" -- "$TIMEOUT_RETRY" 2s ./rj </dev/null >"$TMP/o" 2>&1 ); rc=$?
                 else : ; fi
             fi; fi
        SM="$(progress_secs_since "$_t0")"
        # ⛔⭐ THE VERDICT IS STABLE; ONLY THE DIAGNOSIS VARIES (ceo ruling 2026-09-03, after their audit read
        # m3 296/129 where mine read 303/123 on the same tree). THE VERDICT is binary and load-independent:
        # a rejection test PASSES only when scrip REFUSES it with a diagnostic, and everything else -- ran to
        # completion, ran until the bound, crashed -- is the same FAIL, because none of them is a refusal.
        # The crash/timeout split is then a LABELLED DIAGNOSIS counted alongside, never inside, the verdict.
        # Before this, a program that SIGABRTs on an idle box hit the 2s bound under load ~20 instead, and
        # moved between the crash and fail columns run to run: two HQs reading the same tree got different
        # boards and had to reconcile numbers that never disagreed about anything that mattered.
        # ⛔⭐ THE PROGRESS ROW CARRIES THE VERDICT IN `outcome` AND THE DIAGNOSIS IN `note`, which is the
        # banner above applied to the database: CRASH and HANG are real values in that table's vocabulary,
        # and writing them here would put this suite's crash column OUTSIDE its fail column for every reader
        # who counts FAIL -- the exact two-HQs-disagree defect the verdict/diagnosis split was cut to end.
        NAMED_IT=""; [ "$rc" -ne 0 ] && [ "$rc" -lt 124 ] && [ -s "$TMP/o" ] && NAMED_IT="$(prt_refusal_names_it "$WANT" "$TMP/o")"
        if [ -n "$NAMED_IT" ]; then P[$m]=$((P[$m]+1))
            printf 'package\tpat\tpascal\t%s\t%s\tPASS\t%s\trefused-naming-the-%s\n' "$b" "$m" "$SM" "$NAMED_IT" >>"$PROG_ROWS"
            [ -n "${PAT_VERBOSE:-}" ] && echo "  $m PASS $b"
        else
            F[$m]=$((F[$m]+1)); okboth=0
            if   [ "$rc" -eq 124 ]; then C[$m]=$((C[$m]+1)); DIAG="accepted-and-ran-to-bound"
            elif [ "$rc" -gt 124 ]; then C[$m]=$((C[$m]+1)); DIAG="crash(rc=$rc)"
            elif [ "$rc" -ne 0 ] && [ -s "$TMP/o" ]; then DIAG="refused-but-not-naming-the-$(echo $WANT | tr ' ' '-')"
            elif [ "$rc" -ne 0 ];   then DIAG="rejected-silently-no-diagnostic"
            else                         DIAG="accepted"; fi
            NAMED="$NAMED $b:$m:FAIL/diag=$DIAG"
            printf 'package\tpat\tpascal\t%s\t%s\tFAIL\t%s\t%s\n' "$b" "$m" "$SM" "$DIAG" >>"$PROG_ROWS"
            [ -n "${PAT_VERBOSE:-}" ] && echo "  $m FAIL $b ($DIAG)"
        fi
    done
    BOTH=$((BOTH+okboth))
done
# ---- acceptance population, oracle = fpc -Miso ----------------------------------------------------------------------
FPC="$(command -v fpc || true)"
# ⭐ A DECLARED RULING IS RE-PROBED, NOT RE-PAID (cfo 2026-09-07, THE ECONOMY). iso7185pat.pas is ruled
# ORACLE_REFUSES in UNGRADABLE.tsv: fpc 3.2.2 -Miso loops forever on `label 0` (ISO 7185 permits it; a
# three-line program reproduces it), so it is not slow, it never finishes, and a 60s wait per board bought
# nothing. A program the sidecar already rules gets a 10s probe instead: enough to see a fast rejection or
# a spin, and if the oracle BUILDS it anyway the ruling is stale and the run says so loudly (the inventory
# then over-sums and refuses, which is the right red). The sidecar is read through lib_inventory.sh's own
# validated reader, never a second parser; the stanza below is the same one inventory_line uses later.
INV_PACKAGE=pat; INV_DIR="$SUITE"; INV_EXT=".pas"
RULED_UNGRADABLE="$(_inv_names "$(_inv_tsv UNGRADABLE.tsv)" UNGRADABLE 2>/dev/null || true)"
for f in "$SUITE"/iso7185pat*.pas "${ACCEPT_FILES[@]}"; do
    [ -n "${RR_STOP:-}" ] && break
    [ -e "$f" ] || continue
    b="$(basename "$f" .pas)"; rr_admits "$b" || continue; rr_yield "$b" && break; rr_flush "$PROG_ROWS"
    [ -n "${FAKE_SET[$b]:-}" ] && continue
    export S4E_TIMEOUT_KEY="$b"   # the unit a retried timeout's stamp names (CEO-1335)
    [ -n "$FPC" ] || { echo "note: fpc absent -- acceptance test $b not graded (its oracle is fpc -Miso); rejection population unaffected"; break; }
    in="$SUITE/$b.inp"; [ -f "$in" ] || in=/dev/null
    # ⛔⭐ THE ORACLE GETS A TIMEOUT TOO, AND THAT IS NOT DEFENSIVE PADDING -- MEASURED: `fpc -Miso` does not
    # finish on iso7185pat.pas (123KB) inside 60s (nor 300s: it spins on `label 0`, see UNGRADABLE.tsv). The first cut of this runner invoked fpc with NO bound, so
    # the whole suite hung on its ORACLE, not on scrip, and read as a >10-minute runner with no output. An
    # un-bounded oracle turns "the reference implementation cannot do this either" into "our runner is broken".
    rm -f "$TMP/oracle"
    ruled=0; printf '%s\n' "$RULED_UNGRADABLE" | grep -qxF "$b.pas" && ruled=1
    bound=60; [ "$ruled" -eq 1 ] && bound=10
    ( cd "$TMP" && "$TIMEOUT_RETRY" "$bound" "$FPC" -Miso -o"$TMP/oracle" "$f" >"$TMP/oracle.err" 2>&1 ); orc=$?
    if [ ! -x "$TMP/oracle" ] && [ "$ruled" -eq 1 ]; then
        echo "note: acceptance test $b is DECLARED UNGRADABLE in $SUITE/UNGRADABLE.tsv; the oracle (fpc -Miso) was re-probed at a ${bound}s bound (rc=$orc) and the ruling stands -- not graded, and explicitly NOT counted against scrip"
        UNGRADABLE=$((UNGRADABLE+1))
        continue
    fi
    [ "$ruled" -eq 1 ] && echo "⚠ RULING STALE: acceptance test $b is declared UNGRADABLE in $SUITE/UNGRADABLE.tsv but the oracle (fpc -Miso) BUILT it this run -- the oracle changed or the declaration is wrong; it is graded below and the inventory will refuse until the row moves"
    if [ ! -x "$TMP/oracle" ]; then
        # ⛔ rc=124 IS THE ONLY GENUINE TIMEOUT -- any other nonzero exit is the oracle REJECTING the
        # program (a real, fast compile error), a different fact with a different consequence, and the
        # two must not share one message (found via iso7185pat0001.pas: fpc -Miso rejects it in ~0.1s
        # with a genuine fatal error, not a 60s stall -- the old message called every non-build a timeout).
        if [ "$orc" -eq 124 ]; then
            echo "note: acceptance test $b is NOT COMPILED BY THE ORACLE (fpc -Miso) within 60s -- not graded, and explicitly NOT counted against scrip; a program the oracle cannot build grades nothing"
        else
            echo "note: acceptance test $b is REJECTED BY THE ORACLE (fpc -Miso rc=$orc, not a timeout) -- not graded, and explicitly NOT counted against scrip: $(tail -1 "$TMP/oracle.err")"
        fi
        UNGRADABLE=$((UNGRADABLE+1))
        continue
    fi
    "$TIMEOUT_RETRY" 20s "$TMP/oracle" <"$in" >"$TMP/want" 2>&1 || true
    TOTAL=$((TOTAL+1))
    # ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06): this suite's row states the programs green in EVERY graded
    # mode. `okboth` starts at 1 and only ever falls to 0 -- a CRASH and a MISMATCH both clear it -- so the AND is
    # taken from the verdicts themselves rather than reconstructed from two counts afterwards, which cannot be done.
    okboth=1
    for m in m3 m4; do
        _t0="$(progress_clock)"
        if [ "$m" = m3 ]; then run_at_declared_table "$DECL" "$b" -- "$TIMEOUT_RETRY" 20s "$SCRIP" "$f" <"$in" >"$TMP/got" 2>&1; rc=$?
        else "$TIMEOUT_RETRY" 20s "$SCRIP" --compile --out="$TMP/b.s" "$f" </dev/null >/dev/null 2>&1 && \
             gcc -m64 -no-pie "$TMP/b.s" -o "$TMP/bin" -L"$HERE/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"$HERE/../../SCRIP/out" -lm 2>/dev/null && \
             run_at_declared_table "$DECL" "$b" -- "$TIMEOUT_RETRY" 20s "$TMP/bin" <"$in" >"$TMP/got" 2>&1; rc=$?; fi
        SM="$(progress_secs_since "$_t0")"
        # ⛔ A CRASHED ACCEPTANCE TEST IS A FAIL AND MUST BE COUNTED AS ONE. Before this line it incremented
        # the crash column ALONE, so a crash left P+F one short of TOTAL and the board's own denominator
        # stopped adding up -- latent today only because both acceptance fixtures are ungradable by the
        # oracle, i.e. the arm never fires; it fires the day one of them becomes gradable.
        if [ "$rc" -ge 124 ]; then C[$m]=$((C[$m]+1)); F[$m]=$((F[$m]+1)); NAMED="$NAMED $b:$m:CRASH(rc=$rc)"; okboth=0
            printf 'package\tpat\tpascal\t%s\t%s\tFAIL\t%s\tcrash(rc=%s)\n' "$b" "$m" "$SM" "$rc" >>"$PROG_ROWS"
        elif cmp -s "$TMP/want" "$TMP/got"; then P[$m]=$((P[$m]+1))
            printf 'package\tpat\tpascal\t%s\t%s\tPASS\t%s\tmatches-the-oracle\n' "$b" "$m" "$SM" >>"$PROG_ROWS"
        else F[$m]=$((F[$m]+1)); NAMED="$NAMED $b:$m:MISMATCH"; okboth=0
            printf 'package\tpat\tpascal\t%s\t%s\tFAIL\t%s\tmismatch-vs-oracle\n' "$b" "$m" "$SM" >>"$PROG_ROWS"; fi
    done
    BOTH=$((BOTH+okboth))
done
# ⛔ A RUNNER THAT GRADED NOTHING MUST NEVER PRINT THE SUCCESS SHAPE (the seven-point standard, point 3).
[ "$TOTAL" -gt 0 ] || refuse "graded ZERO programs over $SUITE -- refusing to print a board with no denominator"
echo "PAT_SUITE_BOARD total=$TOTAL both_pass=$BOTH m3_pass=${P[m3]} m3_fail=${F[m3]} m4_pass=${P[m4]} m4_fail=${F[m4]} outside=$OUTSIDE"
if [ "$OUTSIDE" -gt 0 ]; then echo "-- OUTSIDE the ISO baseline ($OUTSIDE, named in OUTSIDE_ISO_BASELINE.tsv, CLASS not-an-iso-error, accepted as ISO 7185 requires, kept in the denominator): ${OUTSIDE_NAMES[*]}"; fi
if [ "${#STALE_NAMES[@]}" -gt 0 ]; then echo "⚠ OUTSIDE_ISO_BASELINE.tsv STALE -- listed as carrying no ISO violation, but this compiler REFUSED them, so they were graded as rejection tests: ${STALE_NAMES[*]}"; fi
# ⭐ THE PACKAGE LOCKDOWN (Lon 2026-09-06, MASTER-PLAN sec THE PACKAGE LOCKDOWN): shipped is measured
# FRESH from the vendored dir every run (both iso7185prt* and iso7185pat* globs), never assumed from
# TOTAL alone -- a file added to $SUITE after this script was last touched must show up as ungraded,
# not silently vanish. lib_inventory.sh recomputes ungradable/ungraded itself from UNGRADABLE.tsv/
# UNGRADED.tsv beside $SUITE (the two acceptance-population fixtures fpc -Miso cannot build this run)
# rather than trusting this script's own $UNGRADABLE counter.
INV_PACKAGE=pat; INV_DIR="$SUITE"; INV_EXT=".pas"   # the same stanza as above the acceptance loop, restated so the inventory reads beside its call
if ! rr_selected; then   # a part of the package; the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$TOTAL" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
echo "  diagnosis (counted INSIDE fail, never beside it): m3 crash-or-ran-to-bound=${C[m3]} of m4 crash-or-ran-to-bound=${C[m4]} — the verdict is REFUSED-WITH-A-DIAGNOSTIC or not, which does not vary with machine load; this split does"
# ⛔⭐ THE CAP IS A DISPLAY CHOICE AND MUST NOT BE THE ONLY LISTING. 40 keeps a board readable, but this
# suite is THE Pascal denominator and its reds are the lane's whole work pool -- at 127 m3 reds the cap hid
# 87 of them, so the pool could not be populated from the instrument that measures it. Default unchanged;
# PAT_NAME_REDS_MAX=all (or a number) lifts it for the seat that is building the pool.
if [ -n "${PAT_NAME_REDS:-}" ]; then
    echo "  reds:"
    if [ "${PAT_NAME_REDS_MAX:-40}" = all ]; then for x in $NAMED; do echo "    $x"; done
    else for x in $NAMED; do echo "    $x"; done | head -"${PAT_NAME_REDS_MAX:-40}"; fi
fi
if . "$HERE/lib_gate.sh" 2>/dev/null && command -v gate_stamp >/dev/null 2>&1; then gate_stamp; fi
# ⛔⭐ THE PROGRESS APPEND COMES FIRST (hq_pascal 2026-09-23, the twin of the FPC runner's own cure). util_score_row.py write
# REFUSES unless this suite's per-program rows are ALREADY on the progress DB for this exact tree (CEO-750), and this runner
# appended them AFTER the write, so the write refused on every clean run and the PAT row was set by hand. Measured on SCRIP
# 42665301c: "no progress rows for suite 'pat' on tree 42665301c", then 854 rows appended one line later.
# ⛔ THE PROGRESS LINE IS DELETED (Lon 2026-09-13, verbatim: "All bogus. Delete that. Do not show
# that ever again."). The call that stood here printed it; util_score_row.py progress is now a silent
# no-op and this call is removed so the intent is visible rather than inferred from an empty output.
# ⛔⭐ THE FACT RULE'S OTHER HALF (CEO-319, /home/resources/progress/README.md): every suite run APPENDS its
# per-program rows in the same sitting it rewrites its cell. MEASURED by hq_V at its opening, 2026-09-06:
# 497 pascal rows stood in that table and every one was pascal-rungs -- ZERO from pat or fpc, so no Pascal
# PACKAGE flip had ever been visible to the measure OCTET is actually run on. One bulk call, not 854.
# ⛔ NON-FATAL, LOUDLY: bookkeeping must never turn a real measurement into a red board, and it must never fail quietly either.
if [ -s "$PROG_ROWS" ]; then
    if ! progress_append_rows_tsv "$PROG_ROWS"; then
        echo "⚠ PROGRESS DB NOT UPDATED -- the score write below cannot cross-check and will refuse (reason above)" >&2
    fi
fi
rr_selected && { rr_end pat; exit 0; }   # a part or a request writes its rows and no suite row (CEO-1802)
# ⛔⭐ THE SUITE ROW'S PAIR IS DECLARED, NEVER PARSED (hq_T 2026-09-06, ceo CEO-363; the coo had to set
# this row BY HAND after a clean run because util_score_row correctly REFUSED to guess). The --text below
# carries several fractions over the same denominator -- so there is no fact of the matter about which one a
# text parse should take, and the writer refuses rather than picking while the runner declares its pair.
# ⛔⭐ THE RULING CAME, AND IT IS NEITHER ARM: ceo-372, 2026-09-06, on hq_T's ask. This row was wired to m4
# (because SUITES.tsv carried m4), then to m3 by hq_V at 20:5x when the coo hand-set the published row to the
# m3 numbers -- each rewiring correctly avoiding the phantom regression the other would have published, and
# hq_V closed with "The ceo is asked to rule; either way it stays one line." This is that line. The pair is
# THE AND PER PROGRAM -- the programs green in EVERY graded mode: "a program red in m3 and another red in m4
# both count against the row; never m3 alone, never m4 alone, never the min of two counts (which hides a
# program red in each)."
# ⭐ hq_V's SECOND, STANDING REASON IS ANSWERED RATHER THAN OVERRULED. m4 here has a NAMED non-determinism row
# against it (pascal-m4-intermittent-segv-layout-sensitive: five runs, one tree, five pass counts -- ✅ LIVE,
# reopened by the ceo at 21:05, CEO-379, rank 0, hq_V, after this runner's landing measured it filed DONE while
# its defect was in that night's board; its old DONE-WHEN was met on the GATE's population while the class lives
# on the suite's, so one member was cured and the class stayed red), and a row
# wired to a number that moves without the code moving really does manufacture phantom movement in the table
# Lon reads, ETA column included. ceo-372 puts that where it belongs: "a mode whose count varies run to run is
# a DEFECT ROW in that lane -- a nondeterministic compile is the xfail shape with a runner's excuse in front
# of it -- never a reason to publish the steadier mode."
# ⛔ THE NUMBER DROPS FROM ${P[m3]} (m3, as published) TO $BOTH -- 300 to 286 of 427, measured this sitting --
# AND THAT IS A CRITERION CHANGE, NOT A REGRESSION. The commit landing it says so in those words.
# ⛔⭐ THE HEADLINE FRACTION LEADS THE CLAUSE, AND THAT IS A CONSTRAINT ON THE TEXT, NOT A STYLE CHOICE
# (hq_T 2026-09-06, convicted by test_gate_score_v_clause_carries_its_fraction.sh on this runner's own write).
# counted_fractions() reads a package's clause from its NAME to the next ` · `, ` — ` or `; ` separator, and this
# cell used to open `...: $TOTAL programs — both-modes ...`: the em-dash CLOSED the clause before the fraction,
# so the reader saw digits it could not count and scored the whole PAT package ZERO on the September-10 grid --
# 427 programs graded, published as never run. That is the recorded e71d3210 incident (INRIA, same em-dash, same
# reader) whose cure 8b0c2dd9 was "move the fraction first"; it recurred here because the rule lived in a commit
# message and not beside the text it constrains. ⭐ The prose is not lost -- it moved AFTER the fractions, which
# is the whole cure: a writer is entitled to explain, and the explanation belongs downstream of the number.
# ⭐ AND THIS TEXT ALSO CARRIES A FRACTION-SHAPED DIAGNOSTIC -- the "(N/M crash)" counts -- which any
# text-parsing rule would read as one more distinct fraction. Declaring the pair makes the parse moot: the
# overrides short-circuit it entirely, so no diagnostic that merely LOOKS like a fraction can move this row.
. "$HERE/lib_outside_shape.sh" || exit 2
_cc="${S4E_CRITERION_CHANGED:-}"
if [ -z "$_cc" ]; then _cc="$(outside_shape_stamp pat "$TOTAL" "$OUTSIDE")" || exit 2; _cc="${_cc//OUTSIDE_SPITBOL_BASELINE/OUTSIDE_ISO_BASELINE}"; fi
# ⭐ Excl IS THE EXCLUDED.tsv ROWS (ceo CEO-1696, Lon: "Exclude any program in which we have no way to get output from an oracle"): the two
# acceptance tests fpc -Miso never builds (UNGRADABLE.tsv's ORACLE_REFUSES, re-probed above) were already outside TOTAL; their NO_ORACLE_ANSWER rows
# now name them on the row, so shipped = denominator + Excl reads as every other package's does. Counted through lib_inventory.sh's one reader.
_pat_excl="$(inventory_excluded_names "$SUITE" | grep -c . || true)"
python3 "$HERE/util_score_row.py" write --lang pascal --column vendor --suite PAT --modes m3,m4 \
    --suite-pass "$BOTH" --suite-total "$TOTAL" --excluded "${_pat_excl:-0}" \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" \
    --text "ISO 7185 validation suite (Pascal-P5 1.4.x, vendored corpus/packages/pascal/pat): both-modes $BOTH/$TOTAL shipped OUTSIDE=$OUTSIDE · m3 ${P[m3]}/$TOTAL · m4 ${P[m4]}/$TOTAL (crash m3 ${C[m3]}, m4 ${C[m4]}) — $TOTAL programs, of which 427 are REJECTION tests graded on whether scrip refuses them${INV_LINE:+ . $INV_LINE}, per \`test_pascal_pat_suite.sh\`" \
    2>&1 | sed 's/^/    /'
exit 0
