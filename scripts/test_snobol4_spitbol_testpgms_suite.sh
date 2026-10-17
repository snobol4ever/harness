#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${SPITBOL_TESTPGMS_SUITE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/spitbol_testpgms}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snobol4_spitbol_testpgms_suite.sh -- SPITBOL's OWN test programs 1-4, graded in both modes against refs
# cut LIVE from the shared correctness oracle (row snobol4-spitbol-testpgms-vendored-as-a-package-suite-with-a-
# runner-and-a-score-cell, Lon 2026-09-04 17:57 CDT via ceo: "SPITBOL's own testpgms 1-4 must run").
#
# ⛔⭐ REFS ARE CUT LIVE, EVERY RUN, AND NOTHING IS STORED. A stored .ref proves only "unchanged since someone
# cut it" -- it cannot tell a cured compiler from a ref that was cut while the compiler was broken, and this
# suite's oracle is KNOWN to die mid-run on three of its four programs, which is exactly the condition under
# which a stored ref is most likely to be a frozen truncation. Cutting live also means the day hq_P's oracle
# row lands, tests 2-4 start being scored with no edit here.
#
# ⛔⛔ AN ORACLE THAT DIES IS UNSCORED AND COUNTED AS SUCH -- never a pass, never a fail, never a ref (row
# every-ref-cutting-path-refuses-when-the-oracle-dies-mid-cut). MEASURED 2026-09-04 on the shared oracle:
# test1 rc=0 with 120 lines; tests 2, 3 and 4 rc=139 (SIGSEGV) after 8, 5 and 5 lines. Those truncations LOOK
# like answers -- that is the whole danger -- so the run status decides, never the byte count.
# ⭐ WHY COUNTED RATHER THAN SKIPPED: an unscored program is a hole in the denominator, and a board that
# silently shrinks its denominator to what happened to work reports a percentage of the wrong thing. The board
# line carries total, scored AND unscored, and names each unscored program with its signal.
#
# ⛔ EVERY PROGRAM RUNS IN A SCRATCH CWD, never the vendored directory (precedent: the Icon Arizona runner
# c96cb087d and the gimpel runner, same class, same day -- a suite program that opens a work file leaves the
# vendored tree DIRTY, and util_score_row then correctly refuses the row this run exists to write).
#
# EXIT: 0 every SCORED program passes both modes · 1 a scored program is red · 2 REFUSED (unbuilt/stale tree,
# missing suite, oracle unreachable, or ZERO programs scored -- a run that graded nothing is never green).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$(cd "$HERE/../../SCRIP" && pwd)"; ROOT="$(cd "$SD/.." && pwd)"
SUITE="${SPITBOL_TESTPGMS_SUITE:-$ROOT/corpus/packages/snobol4/spitbol_testpgms}"
SCRIP="${SCRIP:-$SD/scrip}"; RT_DIR="${RT_DIR:-$SD/out}"; T="${TIMEOUT:-60}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_snobol4_spitbol_testpgms_suite "$SCRIP" "$RT_DIR/libscrip_rt.so" || exit 2
[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): no suite at $SUITE"; exit 2; }
[ -f "$SUITE/testpgms.in" ] || { echo "⛔ REFUSE(rc=2): $SUITE/testpgms.in missing -- every program reads it on stdin"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority; a private fallback would grade a DIFFERENT LANGUAGE (s189: -bf is the only correct arm)"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)" || exit 2
FLAGS="$(sbl_lang_flags)"
# ⛔⭐⭐ CEO-281 CLAUSE (2) -- SUPERSEDED BY CEO-1316 (2026-09-27): test5 and test8 are graded against sbl itself, through its post-mortem block (the CEO-1316 arm below); what follows is the history of why they once read against csnobol4.
# test5 and test8 are LEGAL SNOBOL4 that SPITBOL declines by I/O ENVIRONMENT rather than by semantics: sbl -bf
# stops test5 with ERROR 116 (`INPUT(.INPUT,,72)` -- an EMPTY channel, where manual v3.7:1929 requires a valid
# integer) and test8 with ERROR 160 (`OUTPUT('TITLE',6,'(14H1THIS IS HAND ,110A1)')` -- a third argument that is
# a FORTRAN FORMAT, not a file name), and in BOTH cases exits 0 carrying a diagnostic instead of an answer.
# A ref cut from that is a frozen error post-mortem carrying `memory used (bytes)` and `execution time msec` --
# implementation-specific and nondeterministic -- so NO second implementation can ever byte-match it.
# ⭐ THE PRECEDENT IS OUR OWN AND IS OLDER THAN THIS ROW: corpus/packages/snobol4/gimpel/ASM_driver.sno:16
# records the identical choice for the identical reason ("This .ref comes from CSNOBOL4 (snobol4 -b), not from
# x64/bin/sbl ... CSNOBOL4 is the other sanctioned SNOBOL4 oracle and runs it"), POKER_driver.sno:6 the same for
# 116 and 248. VERIFIED BY EXECUTION before this arm was written (hq_P 2026-09-05): csnobol4 -b runs test5 to 50
# lines and test8 to a full bridge deal, both rc=0, with ZERO `ERROR NNN --` banners and ZERO post-mortem lines.
# ⛔ IT IS NOT A BLANKET SUBSTITUTE, and the NEGATIVE CONTROL is what keeps that honest: csnobol4 exits rc=1 on
# test1, which sbl answers cleanly in 140 lines. So the set is the ruled TWO **by name** -- never "whatever sbl
# happened to refuse", which is the count-shaped reading the ceo's own wording forbids: a class is a list a
# census produced, never a count.
W="$(mktemp -d "${TMPDIR:-/tmp}/spitbol_testpgms.XXXXXX")" || { echo "⛔ REFUSE(rc=2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
cp -a "$SUITE"/. "$W/" || { echo "⛔ REFUSE(rc=2): could not copy the suite to a scratch cwd -- refusing to grade in the vendored dir"; exit 2; }
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board. The oracle runs as before.
# Line 2 hands the guard the same suite this runner grades (SPITBOL_TESTPGMS_SUITE), so a scratch fixture is judged as one.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(rc=2): lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$W/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSE(rc=2): a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }

# ⭐ THE PROGRESS DATABASE (CEO-319/331, CEO-750; the spitbol_x64 runner's shape): one row per program per mode, appended
# once before the row is written, because util_score_row takes the row's number from the append on the tree it stamps.
# ⛔ THIS RUNNER APPENDED NOTHING UNTIL 2026-09-26 (coo, on hq_snobol4's report): every write refused "no progress rows
# for suite 'testpgms'" although the board graded, and the batch audit read the row UNPROVEN since 61315eaa9. A program
# the oracle does not run is OUTSIDE with the oracle's own refusal; a scored one is PASS, or FAIL/CRASH/HANG by status.
# Recorded only for the canonical suite or when S4E_PROGRESS_DB names a scratch table.
PROG_ROWS="$W/progress.tsv"; : > "$PROG_ROWS"
CANON_SUITE="$ROOT/corpus/packages/snobol4/spitbol_testpgms"
PROG_RECORD=0; { [ "$SUITE" = "$CANON_SUITE" ] || [ -n "${S4E_PROGRESS_DB:-}" ]; } && PROG_RECORD=1
prog_row() { printf 'package\ttestpgms\tsnobol4\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(progress_row_secs "$2")" "${4:-}" >> "$PROG_ROWS"; }   # secs: ROW_S3/ROW_S4, each mode's own wall (CEO-1676 (c))
verdict_of() { if [ "$1" -eq 124 ]; then echo HANG; elif [ "$1" -ge 128 ]; then echo CRASH; else echo FAIL; fi; }
# graded_same <scrip-stdout> -- the one comparison, both modes (CEO-1316): stdout byte for byte against the oracle's stdout, or against
# its body with the post-mortem block removed; and for a post-mortem answer, SCRIP's stderr (<stdout>.err) rendered through the one
# error voice must carry the oracle's banner line exactly and its statement.
voice_of() { python3 "$HERE/util_render_error_voice.py" spitbol < "$1" 2>/dev/null; }
# ⭐ CEO-409 masks from the ALL.mask beside the suite, applied to BOTH streams through the one shim (util_apply_ceo409_mask.py), our
# side as --side=scrip and the oracle's as --side=oracle, so a CEO-1316 (2) ORACLE-ONLY row can remove its one line from the oracle's
# stream and never from ours. No sidecar: both streams byte-identical to what they were.
mask_ours() { python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/ALL.ref" "$p" "$1.mn" --side=scrip < "$1" > "$1.masked"; }
graded_same() {
    [ "$mask_major" = 1 ] && return 1
    mask_ours "$1" || return 1
    cmp -s "$ora_cmp" "$1.masked" || return 1
    [ -z "$pm_banner" ] && return 0
    local v; v="$(voice_of "$1.err")" || return 1
    printf '%s\n' "$v" | grep -qxF -- "$pm_banner" && printf '%s\n' "$v" | grep -qxF -- "in statement $pm_stno"
}
why_red() {
    if [ "$mask_major" = 1 ]; then echo "the mask covers $mask_n of $ora_lines oracle lines -- a majority-masked fixture is UNGRADABLE and belongs outside the baseline, named, not masked (CEO-409 guardrail 4)"; return; fi
    if ! cmp -s "$ora_cmp" "$1.masked"; then echo "first diff: $(diff "$ora_cmp" "$1.masked" 2>/dev/null | head -2 | tr '\n' ' ' | cut -c1-100)"
    else echo "stdout agrees; the error voice does not: oracle [$pm_banner / in statement $pm_stno], SCRIP rendered [$(voice_of "$1.err" | head -2 | tr '\n' ' ' | cut -c1-120)]"; fi
}
# ⭐ A PROGRAM'S OWN STDIN IS ITS <stem>.in SIDECAR WHEN IT HAS ONE (ceo CEO-1410; CEO-1281: a test unit stores its stdin WITH ITSELF).
# The eight programs once all read testpgms.in, the first program's cards, so test6 (TOPOLOGICAL SORT) read test4's syntax
# cards as its relations and never ran; its own 14 relation cards, cut from the original deck, are test6.in. No sidecar: testpgms.in.
stdin_of() { if [ -f "$W/$1.in" ]; then printf '%s' "$W/$1.in"; else printf '%s' "$W/testpgms.in"; fi; }
progs=""; for f in "$W"/test*.spt; do [ -f "$f" ] || continue; progs="$progs $(basename "$f" .spt)"; done
[ -n "$progs" ] || { echo "⛔ REFUSE(rc=2): zero test*.spt programs found under $SUITE"; exit 2; }
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one chunk or a request's entries, rows as each test ends
TOTAL=0; SCORED=0; UNSCR=0; M3P=0; M3F=0; M4P=0; M4F=0; UNSCR_LINES=""; RED_LINES=""; PM_GRADED=0; PM_VOICE_ONLY=0; CR_GRADED=0; CR_LINES=""; MASKED_TOTAL=0; MASKED_FIX=0; MASK_LINES=""
# ⭐ THE SPITBOL BASELINE (Lon 2026-09-08, row snobol4-every-package-runner-states-its-row-over-the-spitbol-
# baseline-measured-live; test_snoflake_suite.sh is the shape). A program SPITBOL ITSELF cannot run is OUTSIDE
# the baseline and out of the denominator. This runner already MEASURES that set live -- it is exactly the
# UNSCORED arms below, which key on sbl's own listing -- so nothing new is computed here; what is added is the
# RECORD (OUTSIDE_SPITBOL_BASELINE.tsv beside the package, mirrored by UNGRADABLE.tsv) and a live cross-check
# that says STALE or UNRECORDED aloud rather than letting a written ruling drift away from what sbl does today.
# BOTH is the ceo-372 AND per program: the suite row states both_modes_pass over the baseline, never a per-mode count.
BOTH=0; OUTSIDE_LIST=""; OUTSIDE_TSV="$SUITE/OUTSIDE_SPITBOL_BASELINE.tsv"; MIRROR_TSV="$SUITE/UNGRADABLE.tsv"
for p in $progs; do
    rr_admits "$p" || continue
    rr_yield "$p" && break
    [ "$PROG_RECORD" = 1 ] && rr_flush "$PROG_ROWS"
    export S4E_TIMEOUT_KEY="$p"   # the unit a retried timeout's stamp names (CEO-1335)
    TOTAL=$((TOTAL+1)); ROW_S3=0; ROW_S4=0
    src="$W/$p.spt"
    okind=sbl; obin="$SBL"; oflags="$FLAGS"; cmpt=""
    # ── the oracle, in the scratch dir, fed the shared stdin file. Status FIRST, bytes never.
    ora="$W/$p.oracle"
    (cd "$W" && "$TIMEOUT_RETRY" "$T" "$obin" $oflags "$p.spt" < "$(stdin_of "$p")" > "$ora" 2>/dev/null); orc=$?
    # ⭐⭐ CEO-1323 (2026-09-27, on Lon's "I want to see TPgm go to 8/8"): A COMPILE REFUSAL IS GRADED, the way CEO-1316 grades a post-mortem.
    # When sbl -bf refuses to compile a program (test2: rc 231, ERROR 214 at line 238, deterministic 30 of 30), SCRIP passes by refusing
    # where SPITBOL x64 refuses: util_spitbol_compile_refusal.py reads the oracle's diagnostics as (line, code) pairs, SCRIP's stderr is
    # rendered through util_render_error_voice.py spitbol and read the same way, and the two sets must be equal, with SCRIP exiting
    # nonzero and printing nothing on stdout (m3) or emitting no assembly (m4). The rc alone never grades (the cfo's condition). An
    # oracle run with no diagnostic (a signal, a timeout) keeps the OUTSIDE arm below; a diagnostic in a shape the helper was not
    # measured on refuses rc 2.
    if [ "$orc" -ne 0 ]; then
        cr_pairs="$(python3 "$HERE/util_spitbol_compile_refusal.py" oracle "$ora" "$orc")"; crc=$?
        [ "$crc" = 2 ] && { echo "⛔ REFUSE(rc=2): $p -- sbl exited rc $orc with a diagnostic in a shape util_spitbol_compile_refusal.py was not measured on (its reason above); CEO-1323 grades only the measured shape"; exit 2; }
        if [ "$crc" = 0 ]; then
            SCORED=$((SCORED+1)); CR_GRADED=$((CR_GRADED+1))
            ca="$(declared_compile_args_from_table "$DECL" "$p")" || exit 2
            _t0="$(progress_clock)"; m3="$W/$p.m3"; (cd "$W" && run_at_declared_table "$DECL" "$p" -- "$TIMEOUT_RETRY" "$T" "$SCRIP" $cmpt $ca "$p.spt" < "$(stdin_of "$p")" > "$m3" 2>"$m3.err"); r3=$?; ROW_S3="$(progress_secs_since "$_t0")"
            got3="$(python3 "$HERE/util_render_error_voice.py" spitbol < "$m3.err" | python3 "$HERE/util_spitbol_compile_refusal.py" pairs -)"
            _t0="$(progress_clock)"; s4="$W/$p.s"; (cd "$W" && "$TIMEOUT_RETRY" "$T" "$SCRIP" $cmpt --compile $ca "$p.spt" > "$s4" 2>"$s4.err") </dev/null; r4=$?; ROW_S4="$(progress_secs_since "$_t0")"
            got4="$(python3 "$HERE/util_render_error_voice.py" spitbol < "$s4.err" | python3 "$HERE/util_spitbol_compile_refusal.py" pairs -)"
            want="$(printf '%s' "$cr_pairs" | tr '\t\n' ': ' | sed 's/ *$//')"
            _p3=0; _p4=0
            if [ "$r3" -ne 0 ] && [ ! -s "$m3" ] && [ "$got3" = "$cr_pairs" ]; then M3P=$((M3P+1)); _p3=1
            else M3F=$((M3F+1)); RED_LINES="$RED_LINES  RED  $p m3 (rc=$r3; sbl refuses at compile, line:code $want; SCRIP's rendered voice read [$(printf '%s' "$got3" | tr '\t\n' ': ')], stdout $(grep -c '' "$m3") line(s))
"; fi
            if [ "$r4" -ne 0 ] && [ ! -s "$s4" ] && [ "$got4" = "$cr_pairs" ]; then M4P=$((M4P+1)); _p4=1
            else M4F=$((M4F+1)); RED_LINES="$RED_LINES  RED  $p m4 (compile rc=$r4; sbl refuses at compile, line:code $want; SCRIP's rendered voice read [$(printf '%s' "$got4" | tr '\t\n' ': ')], assembly $(grep -c '' "$s4") line(s))
"; fi
            if [ "$_p3" = 1 ] && [ "$_p4" = 1 ]; then BOTH=$((BOTH+1)); fi
            if [ "$_p3" = 1 ]; then prog_row "$p" m3 PASS; else prog_row "$p" m3 FAIL "sbl refuses at compile ($want); SCRIP rc=$r3"; fi
            if [ "$_p4" = 1 ]; then prog_row "$p" m4 PASS; else prog_row "$p" m4 FAIL "sbl refuses at compile ($want); SCRIP compile rc=$r4"; fi
            CR_LINES="$CR_LINES  COMPILE-REFUSAL  $p  sbl rc $orc, line:code $want -- graded by code and line (CEO-1323)
"
            continue
        fi
        UNSCR=$((UNSCR+1))
        # ⛔ NAME A SIGNAL ONLY WHEN 128+n IS A PLAUSIBLE SIGNAL NUMBER. A program may legitimately EXIT with a
        # code above 128, and this oracle does: measured on test2 in consecutive runs of this very runner --
        # rc=139 (a real SIGSEGV) once, rc=231 the next, which would decode to "signal 103" and there is no
        # signal 103. That is SPITBOL's own error exit, and calling it a signal would put a fabricated fact in
        # a board line. ⭐ The nondeterminism is itself the ceo's witness holding up ("sbl -bf SIGSEGVs on about
        # HALF its ERROR 212 runs"): the same program, the same input, two different failure modes -- which is
        # exactly why the run STATUS decides here and the output bytes never do.
        why="exited rc=$orc"
        if [ "$orc" -ge 129 ] && [ "$orc" -le 192 ]; then why="KILLED BY SIGNAL $((orc-128)) (rc=$orc)"; fi
        [ "$orc" -eq 124 ] && why="TIMED OUT after ${T}s"
        OUTSIDE_LIST="${OUTSIDE_LIST}${p}\t${why} (sbl -bf does not complete the program)\n"
        UNSCR_LINES="$UNSCR_LINES  UNSCORED  $p  oracle $why after $(grep -c . "$ora" 2>/dev/null || echo 0) line(s) -- truncated output is not ground truth, no ref cut
"
        prog_row "$p" m3 OUTSIDE "sbl -bf $why"; prog_row "$p" m4 OUTSIDE "sbl -bf $why"
        continue
    fi
    # ⛔⭐⭐ AND rc=0 IS NOT "THE ORACLE ANSWERED". This guard's own header says the run STATUS decides and the
    # byte count never does -- and it was one turn short, because SPITBOL REPORTS A FATAL ERROR AND EXITS 0.
    # Reported by hq_P from the first live run; re-measured here on all eight programs (SCRIP c3948a321,
    # corpus d58a796fa, oracle /home/resources/x64/bin/sbl -bf):
    #   test1 rc=0 140 lines, no diagnostic          -> a real answer
    #   test3 rc=0  47 lines, no diagnostic          -> a real answer
    #   test2 rc=231 ERROR 214, NO post-mortem       -> already unscored by the rc arm above
    #   test4 test5 test7 test8 rc=0, 18 lines       -> ERROR 116 / 248 / 160 + post-mortem
    #   test6 rc=0, 56 lines                         -> ERROR 248 + post-mortem, output TRUNCATED mid-answer
    # ⭐ WHY THIS IS WORSE THAN A MISCOUNT, and it is hq_P's point kept in their words: the whole reason this
    # runner cuts its refs LIVE is that a stored ref cannot tell a cured compiler from a ref frozen while the
    # compiler was broken. Scoring an error post-mortem reintroduces exactly that failure one level up, by
    # minting the frozen-truncation ref FRESH on every run. It also fills the denominator hole the board line
    # exists to expose: unscored read 1 where the honest number is 6.
    # ⛔ BOTH MARKERS ARE REQUIRED, and the negative control is why. The post-mortem block is ERROR-PATH ONLY
    # (test3 completes and carries none, which is why test3 legitimately passes) -- but test2 carries the
    # diagnostic with NO post-mortem, so a diagnostic-only rule and a post-mortem-only rule each miss a real
    # case that the other catches. Requiring both together fires on exactly the five rc=0 error-path programs
    # and on neither of the two that answered.
    # ⛔ SUPERSEDED BY CEO-1316 (the arm just below this block): THE FIVE ARE NOW GRADED THROUGH SPITBOL'S POST-MORTEM. What follows is the 2026-09-05 reasoning for the old UNSCORED arm. Grading them against csnobol4 (as gimpel's
    # ASM_driver.sno already does for this class) is with the ceo as a ruling; this arm only stops calling a
    # non-answer an answer. The honest board reads WORSE (scored 3, unscored 5) and that is the point.
    # ⛔ THIS ARM IS SPITBOL-SPECIFIC AND IS NOW SCOPED TO THE sbl ORACLE. It keys on SPITBOL's own listing
    # format (the `ERROR NNN --` banner plus its post-mortem block) and on SPITBOL's habit of reporting a FATAL
    # error while exiting 0. CSNOBOL4 does neither: it signals by STATUS -- measured rc=1 on test1 -- so the
    # `orc -ne 0` arm above already covers it, and running this grep over csnobol4 output would only invite a
    # false UNSCORED the day a program legitimately PRINTS the words "ERROR 116 --" as part of its answer.
    # ⭐ test5 is exactly that hazard: its own answer quotes SPITBOL diagnostics back as data.
    # ⭐⭐ CEO-1316 (2026-09-27, on Lon's word "I want to see TPgm go to 8/8. I'm tired of seeing that 1/8."): THE FIVE ARE GRADED.
    # A post-mortem answer is graded, never marked OUTSIDE: util_spitbol_post_mortem.py removes SPITBOL's post-mortem block ONLY when it
    # has exactly the measured shape (its header carries the grammar, derived from stopr in sbl.min) and REFUSES rc 2 on any other shape;
    # the remainder is compared byte for byte with SCRIP's stdout, the banner's line and statement with SCRIP's stderr rendered through
    # util_render_error_voice.py spitbol; the accounting is never graded (CEO-420 (b), the rewind-174 precedent). Measured when this
    # landed: test4..test8 PASS both modes -- they pass by STOPPING EXACTLY WHERE SPITBOL x64 STOPS, and running them to completion as
    # Macro SPITBOL 370 would would widen the dialect, which is Lon's call and is not taken. The hazard kept from the old arm: test5's own
    # answer quotes SPITBOL diagnostics as data, so the trigger still needs a diagnostic AND the accounting lines before the helper runs.
    _diag=""; _pm=0; pm_banner=""; pm_stno=""; ora_cmp="$ora"
    if [ "$okind" = sbl ]; then
        _diag="$(grep -m1 -E 'ERROR [0-9]+ --' "$ora" 2>/dev/null)"
        _pm="$(grep -cE '^(in line|stmts executed|memory used \(bytes\)|memory left \(bytes\))' "$ora" 2>/dev/null || echo 0)"
    fi
    if [ -n "$_diag" ] && [ "$_pm" -ge 2 ]; then
        pm_out="$(python3 "$HERE/util_spitbol_post_mortem.py" "$ora" "$ora.body")"; pmrc=$?
        [ "$pmrc" = 0 ] || { echo "⛔ REFUSE(rc=2): $p -- sbl answered with a post-mortem that is not the measured shape (util_spitbol_post_mortem.py rc=$pmrc, its reason above); CEO-1316 grades only the exact shape"; exit 2; }
        pm_banner="$(printf '%s\n' "$pm_out" | awk -F'\t' '$1=="BANNER"{print $2}')"; pm_stno="$(printf '%s\n' "$pm_out" | awk -F'\t' '$1=="STATEMENT"{print $2}')"
        ora_cmp="$ora.body"; PM_GRADED=$((PM_GRADED+1)); [ -s "$ora.body" ] || PM_VOICE_ONLY=$((PM_VOICE_ONLY+1))
    fi
    ora_lines=$(grep -c "" "$ora_cmp"); mask_major=0
    python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/ALL.ref" "$p" "$ora_cmp.mn" --side=oracle < "$ora_cmp" > "$ora_cmp.masked" \
        || { echo "⛔ REFUSE(rc=2): $p -- the CEO-409 mask sidecar beside $SUITE is refused (the reason above); a mask nobody can audit grades nothing"; exit 2; }
    mask_n=$(cat "$ora_cmp.mn"); ora_cmp="$ora_cmp.masked"
    if [ "$mask_n" -gt 0 ]; then
        MASKED_TOTAL=$((MASKED_TOTAL+mask_n)); MASKED_FIX=$((MASKED_FIX+1)); mask_major="$(cat "${ora_cmp%.masked}.mn.major")"
        MASK_LINES="$MASK_LINES  MASKED  $p  $mask_n line(s) of $ora_lines, declared in ALL.mask beside the suite (CEO-409; an ORACLE-ONLY row is CEO-1316 (2))
"
    fi
    SCORED=$((SCORED+1))
    # ── mode 3 and mode 4, same scratch cwd, same stdin.
    ca="$(declared_compile_args_from_table "$DECL" "$p")" || exit 2
    _t0="$(progress_clock)"; m3="$W/$p.m3"; (cd "$W" && run_at_declared_table "$DECL" "$p" -- "$TIMEOUT_RETRY" "$T" "$SCRIP" $cmpt $ca "$p.spt" < "$(stdin_of "$p")" > "$m3" 2>"$m3.err"); r3=$?; ROW_S3="$(progress_secs_since "$_t0")"
    _p3=0
    if graded_same "$m3"; then M3P=$((M3P+1)); _p3=1; else M3F=$((M3F+1)); RED_LINES="$RED_LINES  RED  $p m3 (rc=$r3, $(why_red "$m3"))
"; fi
    s4="$W/$p.s"; b4="$W/$p.bin"; _t0="$(progress_clock)"
    (cd "$W" && "$TIMEOUT_RETRY" "$T" "$SCRIP" $cmpt --compile $ca "$p.spt" > "$s4" 2>/dev/null) </dev/null
    m4="$W/$p.m4"; r4=0
    if [ -s "$s4" ] && gcc -no-pie "$s4" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -o "$b4" 2>/dev/null; then
        (cd "$W" && run_at_declared_table "$DECL" "$p" -- "$TIMEOUT_RETRY" "$T" "$b4" < "$(stdin_of "$p")" > "$m4" 2>"$m4.err"); r4=$?
    else
        : > "$m4"; : > "$m4.err"; r4=125
    fi
    ROW_S4="$(progress_secs_since "$_t0")"
    _p4=0
    if graded_same "$m4"; then M4P=$((M4P+1)); _p4=1; else M4F=$((M4F+1)); RED_LINES="$RED_LINES  RED  $p m4 (rc=$r4, $(why_red "$m4"))
"; fi
    # written as an if, not an && chain: this file is set -uo pipefail today, but an && chain whose last
    # link is false returns non-zero and would abort the loop the day someone adds -e.
    if [ "$_p3" = 1 ] && [ "$_p4" = 1 ]; then BOTH=$((BOTH+1)); fi
    if [ "$_p3" = 1 ]; then prog_row "$p" m3 PASS; else prog_row "$p" m3 "$(verdict_of "$r3")" "rc=$r3"; fi
    if [ "$_p4" = 1 ]; then prog_row "$p" m4 PASS
    elif [ "$r4" = 125 ]; then prog_row "$p" m4 FAIL "mode-4 compile or link failed"
    else prog_row "$p" m4 "$(verdict_of "$r4")" "rc=$r4"; fi
done
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "SPITBOL_TESTPGMS_BOARD total=$TOTAL scored=$SCORED unscored=$UNSCR m3_pass=$M3P m3_fail=$M3F m4_pass=$M4P m4_fail=$M4F -- SCRIP $SCRIP_HASH corpus $CORP_HASH RT_OPT=-O0 oracle=sbl-bf (the one SNOBOL4 oracle, Lon 2026-09-07) refs cut live"
echo "SPITBOL_TESTPGMS_POST_MORTEM graded=$PM_GRADED voice_only=$PM_VOICE_ONLY -- programs whose sbl answer is a fatal post-mortem, graded through it (CEO-1316): stdout minus the block byte for byte, the banner and statement through the one error voice, the accounting ungraded (CEO-420 (b)); they pass by stopping exactly where SPITBOL x64 stops -- running them to completion would widen the dialect, Lon's call, not taken; voice_only counts those whose whole sbl stdout IS the post-mortem, so their body compared is empty and they pass on the banner and statement alone (the coo's review, 2026-09-27)"
echo "SPITBOL_TESTPGMS_COMPILE_REFUSAL graded=$CR_GRADED -- programs sbl -bf refuses to compile, graded by the code and line of every diagnostic through the one error voice (CEO-1323): they pass by being refused where SPITBOL x64 refuses them"
printf '%s' "$CR_LINES"
echo "SPITBOL_TESTPGMS_MASKS masked_lines=$MASKED_TOTAL in $MASKED_FIX fixture(s) -- CEO-409 masks declared in ALL.mask beside the suite, counted, the fixture staying in the denominator"
printf '%b' "$MASK_LINES"
echo "SPITBOL_TESTPGMS_BASELINE baseline=$SCORED both_modes_pass=$BOTH outside_spitbol_baseline=$UNSCR of $TOTAL -- THE SUITE TABLE STATES both_modes_pass/baseline (a program SPITBOL itself cannot run is outside the baseline and out of the denominator; Lon 2026-09-08)"
if [ "$UNSCR" -gt 0 ]; then echo "OUTSIDE-SPITBOL-BASELINE ($UNSCR; name<TAB>SPITBOL's own refusal):"; printf '%b' "$OUTSIDE_LIST" | sed 's/^/OUTSIDE\t/'; fi
# ⛔ THE RECORD IS CROSS-CHECKED AGAINST THE LIVE MEASURE EVERY RUN, and disagreement is said aloud rather than
# resolved silently: a written ruling that sbl no longer agrees with is the stale-declaration failure this
# runner's own header warns about, one level up.
if [ -f "$OUTSIDE_TSV" ]; then
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{sub(/\.spt$/,"",$1); print $1}' "$OUTSIDE_TSV" | sort)"
    live="$(printf '%b' "$OUTSIDE_LIST" | cut -f1 | grep . | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    unrec="$(comm -13 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv STALE -- recorded as not running in SPITBOL, but sbl -bf answered it cleanly this run; move it back into the baseline record: $stale"
    [ -n "$unrec" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv UNRECORDED -- sbl -bf refuses these and the record does not name them; record each with its error and a source check: $unrec"
    [ -z "$stale$unrec" ] && echo "OUTSIDE_SPITBOL_BASELINE.tsv agrees with the measured outside set ($UNSCR)"
    if [ -f "$MIRROR_TSV" ]; then
        mir="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$MIRROR_TSV" | sort)"; recn="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$OUTSIDE_TSV" | sort)"
        [ "$mir" = "$recn" ] || echo "⚠ UNGRADABLE.tsv does not mirror OUTSIDE_SPITBOL_BASELINE.tsv row for row -- the lockdown bucket and the record have drifted; edit them together"
    fi
else echo "⚠ no OUTSIDE_SPITBOL_BASELINE.tsv beside the suite -- the outside-baseline set above is measured, not yet recorded"; fi
printf '%s' "$UNSCR_LINES"
printf '%s' "$RED_LINES"
# ⭐ THE PACKAGE LOCKDOWN: lib_inventory.sh recomputes ungradable from UNGRADABLE.tsv beside $SUITE (a
# static declaration of test2/test4/test6/test7's known sbl behavior) rather than trusting $UNSCR as a
# number. test4..test8 are graded (through the post-mortem, CEO-1316) and land in graded_stream via
# SCORED -- ⛔ if a future run of sbl answers a declared-ungradable program cleanly instead, SCORED
# changes but the static declaration does not, and inventory_line correctly REFUSES on that mismatch
# rather than silently accepting a stale ruling (this runner's own live UNSCR check still decides each
# run; only the WRITTEN reason for a name that stays unscored is static).
INV_PACKAGE=spitbol_testpgms; INV_DIR="$SUITE"; INV_EXT=".spt"
if ! rr_selected; then   # a chunk grades a part of the package, and the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$SCORED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
if [ "$PROG_RECORD" = 1 ]; then
    progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS ROWS NOT RECORDED (writer rc=$? above) -- a run that leaves the table untouched is a defect of that run (progress/README.md), not a red board" >&2
else echo "progress: scratch suite $SUITE -- $(grep -c . "$PROG_ROWS") row(s) NOT recorded (only the canonical suite, or S4E_PROGRESS_DB, records)"; fi
rr_selected && { rr_end testpgms; exit 0; }   # a chunk or a request writes its rows and no suite row (CEO-1802)
# ⛔ ZERO SCORED IS UNMEASURED, NEVER GREEN. If the oracle ever dies on all four, every counter above reads 0
# and the verdict `m3_fail=0 && m4_fail=0` would be a perfect green board over an empty population.
if [ "$SCORED" -eq 0 ]; then
    echo "⛔ REFUSE(rc=2): ZERO of $TOTAL programs were scored -- the oracle died on every one, so this run measured nothing."
    exit 2
fi
# ⭐ THE ROW, NAMING ITS OWN FRACTION (the shape test_snoflake_suite.sh uses, which this row's GOAL names).
# The --text below carries several distinct N/M, so util_score_row's fraction_from_text() would correctly
# decline to guess and abort the whole write -- which is why this cell was hand-recorded before and still
# showed retired --compat text. The table's reading is the ceo-372 AND per program over the SPITBOL
# baseline: both_modes_pass/baseline, never a per-mode count.
# ⛔ CEO-749 SHAPE (row snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749):
# PASS over SHIPPED ($TOTAL = graded plus the $UNSCR outside the SPITBOL baseline), OUTSIDE=$UNSCR named and stamped
# through lib_outside_shape.sh; the outside programs stay in the denominator as debt to cure.
. "$HERE/lib_outside_shape.sh" || exit 2
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(printf '%b' "$OUTSIDE_LIST" | cut -f1)")" || exit 2; DENOM=$((TOTAL - EXCL_D_N))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp testpgms "$DENOM" "$UNSCR" "$EXCL_D_N")" || exit 2
# ⛔ ONLY THE CANONICAL SUITE WRITES THE LEADERBOARD (the x64 and dotnet runners' guard; absent here until 2026-09-26, and
# harmless only while nothing was appended: a scratch suite graded under a scratch S4E_PROGRESS_DB now passes the write's
# DB check, so without this a fixture run would set the live testpgms row).
if [ "$SUITE" = "$CANON_SUITE" ]; then
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite testpgms --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" --suite-pass "$BOTH" --suite-total "$DENOM" --excluded "$EXCL_D_N" \
    --text "spitbol_testpgms both_modes_pass=$BOTH/$DENOM ($TOTAL shipped minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect -- all eight are SPITBOL's own test deck, CEO-1286) OUTSIDE=$UNSCR, graded $BOTH/$SCORED ($PM_GRADED of them graded through SPITBOL's fatal post-mortem, $PM_VOICE_ONLY of those on the error voice alone because sbl's whole stdout is the post-mortem and only $((PM_GRADED-PM_VOICE_ONLY)) compares a body, CEO-1316: they pass by stopping exactly where SPITBOL x64 stops, and running them to completion as Macro SPITBOL 370 would widen the dialect, Lon's call, not taken · $CR_GRADED graded by being REFUSED where SPITBOL x64 refuses them at compile, by the code and line of every diagnostic through the one error voice, CEO-1323 (test2: ERROR 214 at line 238) · $UNSCR outside the SPITBOL baseline, named with SPITBOL's own error and a source check in OUTSIDE_SPITBOL_BASELINE.tsv, Lon 2026-09-08) · masked_lines=$MASKED_TOTAL in $MASKED_FIX fixture(s) (CEO-409 in ALL.mask; test1's statement-137 trap is a CEO-1316 ORACLE-ONLY row for Lon's kept VALUE, CEO-1293) · m3 $M3P/$SCORED · m4 $M4P/$SCORED (of $TOTAL shipped · sbl -bf the one oracle, Lon 2026-09-07 · refs cut live)${INV_LINE:+ · $INV_LINE} (\`test_snobol4_spitbol_testpgms_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
else echo "SCORE.md: scratch suite $SUITE -- not written (only the canonical suite records the leaderboard)"; fi
[ "$M3F" = 0 ] && [ "$M4F" = 0 ]
