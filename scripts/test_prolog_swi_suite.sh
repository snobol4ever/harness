#!/usr/bin/env bash
S4E_ONE_RUNNER_SINGLE_FILE=""; _sf_prev=""; for _sf_a in "$@"; do [ "$_sf_prev" = --file ] && S4E_ONE_RUNNER_SINGLE_FILE="$_sf_a"; _sf_prev="$_sf_a"; done; source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${S4E_CORPUS:-${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus}/packages/prolog/swi_tests" || exit 2
# test_prolog_swi_suite.sh -- THE SWI-PROLOG TEST SUITE BOARD: every plunit CASE the vendored swipl-devel src/Tests tree
# declares, graded by AGREEMENT with real swipl's own verdict, in mode 3 and mode 4.
#
# Lon 2026-09-12, in-chat to cto, verbatim: "Get all SWI tests graded."  Row
# prolog-swi-tests-all-2879-cases-graded-per-case-against-swipl-by-path (cto).  Before this the runner graded the ten
# files that had a top-level .ref (59 plunit UNITS, one verdict per unit) and named the other 230 files in EXCLUDED.md
# with a scrip-side reason -- a red moved out of the denominator (lib_inventory.sh).
#
# THE POPULATION is every *.pl under corpus/packages/prolog/swi_tests that declares a begin_tests( unit, addressed BY
# PATH (basenames repeat across subdirectories).  Beside each sits <file>.ref, cut by ../harness/scripts/util_swi_cut_refs.sh from
# swipl 9.0.4 running its OWN library(plunit), one line per CASE.  A case is graded when the oracle gave it PASS or FAIL;
# a BLOCKED case, an EMPTY unit and an UNGRADABLE unit (the oracle crashed, aborted or timed out -- ITS reason, never
# ours) are UNGRADED, named per case with the reason, never dropped and never a pass.  The declared population is read
# from the SOURCE (test/2 clause heads), so the identity graded + ungraded == declared holds per file and per board.
#
# THE VERDICT per case is agreement: oracle PASS and scrip pass, or oracle FAIL and scrip FAIL (an agreement control,
# counted separately as hit_fail_agree).  A case passes the SUITE when it agrees in EVERY mode graded (AND per case,
# CEO-372); the SUITES.tsv row states that number over the declared population.
#
# A run is a BOARD (RULES.md ONE RUNNER, ONE BOARD): only the coo runs it, on origin HEAD, once per landing batch.
#
# Usage: bash ../harness/scripts/test_prolog_swi_suite.sh [--modes m3|m4|m3,m4] [--jobs N] [--file REL.pl] [--name-reds] [--verbose]
#   --file REL.pl   grade one file (a development aid, never a board; writes no row)
#   --name-reds     print every disagreeing case with both verdicts -- ALL of them, and it prints its own count first.
#                   ⛔ IT USED TO PRINT AT MOST 2000, SILENTLY, while this line said 'every': the board reports ~3580
#                   disagreements, so a base-vs-head red-NAME-SET diff over that window showed 22 cures leaving it and
#                   22 untouched pre-existing reds ENTERING it, which reads exactly like 22 regressions (measured on the
#                   rung 3(f) arm, hq_prolog 2026-09-17). SWI_NAME_REDS_MAX=N re-imposes a cap and the header line says so.
#   --verbose       also print scrip's raw output for a disagreeing file
set -uo pipefail
GATE_NAME=test_prolog_swi_suite
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIT="${S4E_CORPUS:-$S4E/corpus}/packages/prolog/swi_tests"   # the expression line 2 hands the guard, so it judges the suite graded here
PLUNIT="$S4E/corpus/tests/prolog/plunit.pl"
MATCH_PY="$HERE/util_swi_match.py"
STO_PY="$HERE/util_swi_sto_merge.py"   # each deferred sto(rational_trees) case's ALONE verdict, put where the file's run deferred it (CEO-1684)
MODES="m3,m4"; JOBS="${SWI_JOBS:-}"; ONLY_FILE=""; NAME_REDS=0; VERBOSE=0
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --modes) MODES="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --file) ONLY_FILE="$2"; shift 2 ;;
        --name-reds) NAME_REDS=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        *) refuse "unknown argument '$1' -- this runner has no silent fall-through" ;;
    esac
done
# ⛔ THE FAN-OUT CEILING (ceo CEO-1333; the ceo's word to the coo 2026-10-01 12:1x CDT, a Logtalk pass at 12 jobs put load1 at 18 on a
# shared box): the default width is lib_fanout.sh's fanout_width, max(2, min(4, cores - demand)), read at launch; a --jobs or SWI_JOBS above
# it is CLAMPED and the clamp is printed, never silent -- the shape run_blocking_set.sh gives --shards. This runner defaulted to 12.
. "$HERE/lib_fanout.sh" || refuse "../harness/scripts/lib_fanout.sh is missing -- the fan-out ceiling has no instrument"
_fw=$(fanout_width)
case "$JOBS" in
    '') JOBS=$_fw ;;
    *[!0-9]*|0) refuse "--jobs takes a count of 1 or more (got '$JOBS')" ;;
    *) if [ "$JOBS" -gt "$_fw" ]; then echo "fanout: --jobs $JOBS clamped to $_fw at CPU demand $(fanout_demand) ($(fanout_source)) on $(fanout_cores) cores (CEO-1333/1394: max(2, min(4, cores - demand)), never load1)"; JOBS=$_fw; fi ;;
esac
[ -d "$SWIT" ] || refuse "no vendored package at $SWIT -- a package that is absent is not a package that is failing"
[ -f "$PLUNIT" ] || refuse "$PLUNIT missing"
[ -x "$SCRIP" ] || refuse "scrip not built"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
. "$HERE/lib_gate.sh"
. "$HERE/lib_inventory.sh"
[ -f "$HERE/lib_progress.sh" ] && . "$HERE/lib_progress.sh"
# ⭐ DECLARED MEMORY, BOTH HALVES (Lon 2026-09-23 18:3x, CEO-1225; the coo): each case file runs at the heap and the stack its row
# in ALL.csv declares -- heap_kb, stack_kb, read through lib_declared_arena.sh, the one reader -- for THAT file only. This board read
# neither until now. Every cell is checked here, once, before anything is graded: a refused cell refuses the board rather than
# quietly grading its program at the default.
. "$HERE/lib_declared_arena.sh" || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"
_decl_rcpt="$(declared_arena_receipt "$SWIT/ALL.csv")"; printf '%s\n' "$_decl_rcpt"
case "$_decl_rcpt" in *REFUSED*) refuse "a declared-memory cell in $SWIT/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it";; esac
WORK="$(mktemp -d /tmp/swi_board_XXXXXX)"; trap 'rm -rf "$WORK"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$WORK/wrap.pl"
FILES="$WORK/files.txt"
grep -rl --include='*.pl' 'begin_tests(' "$SWIT" | sort > "$FILES"
if [ -n "$ONLY_FILE" ]; then grep -F -- "/$ONLY_FILE" "$FILES" > "$FILES.one" || refuse "--file $ONLY_FILE matches no shipped test file"; _nf=$(wc -l < "$FILES.one"); [ "$_nf" = 1 ] || refuse "--file $ONLY_FILE matches $_nf shipped test files -- it grades exactly one (CEO-1664)"; mv "$FILES.one" "$FILES"; fi
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1805/1806): under S4E_CHUNK only the part's files (keyed dir/test_x, as ALL.csv and PARTITION.tsv key them) are
# graded, their cases' rows are appended as a whole run appends them, and no suite row is written (rr_end below). A part grades one file at a time, both
# modes, and stops between two files when a request waits or its S4E_RR_BUDGET is spent (RR_YIELD; the loop resumes the part at the next file).
. "$HERE/lib_rr.sh" && rr_load "$SWIT" || exit 2
if rr_selected; then
    rr_entries | while IFS= read -r _e; do grep -xF -- "$SWIT/$_e.pl" "$FILES"; done > "$FILES.rr"; mv "$FILES.rr" "$FILES"   # the partition's order, so a resume skips nothing
fi
NFILES=$(wc -l < "$FILES")
[ "$NFILES" -gt 0 ] || refuse "no plunit files found under $SWIT"
cat > "$WORK/grade_one.sh" <<'GEOF'
#!/usr/bin/env bash
f="$1"; mode="$2"
. "$LIB_DECL" || exit 2
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(dirname "$LIB_DECL")/util_timeout_retry.sh}"   # the runner exports it; a lifted grade_one finds it beside LIB_DECL (CEO-1335)
rel="${f#"$SWIT"/}"; ref="${f%.pl}.ref"; od="$WORK/out/${rel%.pl}"; mkdir -p "$od"
export S4E_TIMEOUT_KEY="$rel"   # the unit a retried timeout's stamp names (CEO-1335)
act="$od/$mode.actual"; : > "$act"
if [ ! -f "$ref" ]; then echo "NOREF" > "$od/$mode.tsv"; exit 0; fi
# ⛔ THE RUN'S EXIT STATUS TRAVELS WITH ITS OUTPUT (the coo 2026-09-27, ceo CEO-1309): the matcher saw the output alone, so a run killed
# by a signal part-way left its unreported cases reading FAIL -- a crash graded as a wrong answer, which the verdict ladder forbids (CRASH
# never collapses into FAIL). rc is the run's own status (timeout passes a child's signal on as 128+N and answers 124 itself); a mode-4
# program that never compiled has no run, and keeps rc 0 and its FAIL.
rc=0
_t0="${EPOCHREALTIME/,/.}"   # the process's own wall (CEO-1676 (c)): the aggregator divides it over the case rows this process produced
if [ "$mode" = "m4" ]; then
    if "$TIMEOUT_RETRY" 60 "$SCRIP" --compile "$PLUNIT" "$f" "$WORK/wrap.pl" > "$od/m4.s" 2>"$od/m4.err" && [ -s "$od/m4.s" ] \
       && gcc -no-pie "$od/m4.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$od/m4.bin" 2>>"$od/m4.err"; then
        # ⛔ UNBUFFERED, AS THE HARNESS RUNS EVERY MODE-4 BINARY (stdbuf -o0 -e0; the coo 2026-10-04, on hq_prolog's measurement): a mode-4
        # binary block-buffers stdout to the pipe, so a file killed at the timeout lost EVERY case it had printed and read HANG throughout,
        # while mode 3 writes as it goes and kept them -- core/test_acyclic read 41 m3-PASS and 0 m4-PASS for one hang in both modes, a
        # per-mode split made by the flush, not the program (measured: a print-then-loop witness keeps its two lines under stdbuf, none bare).
        run_at_declared_arena "$SWIT/ALL.csv" "${rel%.pl}" -- "$TIMEOUT_RETRY" 60 ${STDBUF:+$STDBUF -o0 -e0} "$od/m4.bin" < /dev/null > "$act" 2>"$od/m4.run.err"; rc=$?
    fi
else
    run_at_declared_arena "$SWIT/ALL.csv" "${rel%.pl}" -- "$TIMEOUT_RETRY" 60 "$SCRIP" --run "$PLUNIT" "$f" "$WORK/wrap.pl" < /dev/null > "$act" 2>"$od/m3.err"; rc=$?
fi
# ⭐ EACH sto(rational_trees) CASE ALONE (ceo CEO-1684): the shim defers every such case in the file's run, so a cyclic-term case that loops
# or exhausts the stack can no longer end its whole file (core/test_arith 221 cases -> 61, core/test_term 52 -> 9 when run in line, measured
# on 4783ee83e); here each deferred spec runs ALONE in the same program -- m4 the same binary -- from its own directory, whose pj_sto_only.pl
# names it, under its own 30 s timeout, and util_swi_sto_merge.py puts its verdict where the file's run deferred it: a case that loops or
# dies reads FAIL with the loop named, and costs that case only. Its seconds join the mode's (the aggregator divides them over the cases).
if grep -q '\[sto-deferred only(' "$act"; then
    grep -oE '\[sto-deferred only\(.*\)\]$' "$act" | sed -E 's/^\[sto-deferred (.*)\]$/\1/' | awk '!s[$0]++' > "$od/$mode.sto"
    k=0
    while IFS= read -r spec; do
        k=$((k+1)); sd="$od/$mode.sto.$k"; mkdir -p "$sd"; printf '%s.\n' "$spec" > "$sd/pj_sto_only.pl"
        if [ "$mode" = "m4" ]; then
            if [ -x "$od/m4.bin" ]; then (cd "$sd" && run_at_declared_arena "$SWIT/ALL.csv" "${rel%.pl}" -- "$TIMEOUT_RETRY" 30 ${STDBUF:+$STDBUF -o0 -e0} "$od/m4.bin" < /dev/null > out 2> err); echo $? > "$sd/rc"; else echo 2 > "$sd/rc"; fi
        else
            (cd "$sd" && run_at_declared_arena "$SWIT/ALL.csv" "${rel%.pl}" -- "$TIMEOUT_RETRY" 30 "$SCRIP" --run "$PLUNIT" "$f" "$WORK/wrap.pl" < /dev/null > out 2> err); echo $? > "$sd/rc"
        fi
    done < "$od/$mode.sto"
    python3 "$STO_PY" "$act" "$od/$mode.sto" "$od/$mode.sto." 30 > "$act.sto" && mv "$act.sto" "$act"
fi
# only the m4 job removes its own .s and binary: the m3 and m4 jobs of one file share $od and run in parallel, and an m3 job that removed
# them unconditionally deleted the m4 job's .s mid-compile -- every m4 case of core/test_term read "no verdict" (the coo's control arm)
[ "$mode" = "m4" ] && rm -f "$od/m4.s" "$od/m4.bin"
awk -v a="$_t0" -v b="${EPOCHREALTIME/,/.}" 'BEGIN { printf "%.3f\n", b - a }' > "$od/$mode.secs"
python3 "$MATCH_PY" "$f" "$ref" "$act" "$rc" > "$od/$mode.tsv"
GEOF
chmod +x "$WORK/grade_one.sh"
: > "$WORK/jobs.txt"
for m in ${MODES//,/ }; do while IFS= read -r f; do printf '%s %s\n' "$f" "$m" >> "$WORK/jobs.txt"; done < "$FILES"; done
echo "grading $NFILES file(s) x modes=$MODES with $JOBS job(s), oracle refs beside the sources"
LIB_DECL="$HERE/lib_declared_arena.sh"
STDBUF="$(command -v stdbuf 2>/dev/null)"   # the mode-4 binary runs unbuffered when stdbuf exists, as the harness's do (grade_one.sh)
export SCRIP RT PLUNIT WORK SWIT MATCH_PY STO_PY LIB_DECL STDBUF
if rr_selected; then
    : > "$FILES.done"
    while IFS= read -r _f; do
        _r="${_f#"$SWIT"/}"; _r="${_r%.pl}"
        { rr_yield "$_r" || rr_over_budget "$_r"; } && break
        for m in ${MODES//,/ }; do printf '%s %s\n' "$_f" "$m"; done | xargs -P "$JOBS" -n 2 bash "$WORK/grade_one.sh"
        printf '%s\n' "$_f" >> "$FILES.done"
    done < "$FILES"
    mv "$FILES.done" "$FILES"; NFILES=$(wc -l < "$FILES"); echo "graded $NFILES file(s) of the part"
else
    xargs -P "$JOBS" -n 2 -a "$WORK/jobs.txt" bash "$WORK/grade_one.sh"
fi
python3 - "$WORK" "$FILES" "$MODES" "$SWIT" "$NAME_REDS" <<'PY'
import sys, os, collections
work, files, modes, swit, name_reds = sys.argv[1], sys.argv[2], sys.argv[3].split(','), sys.argv[4], sys.argv[5] == '1'
tot = {m: collections.Counter() for m in modes}
declared = 0; ungraded_reason = collections.Counter(); ungraded_cases = 0
both = 0; graded_cases = 0; noref = []
# ⛔⭐ EXCLUDED_CASES.tsv -- ONE CASE OUT OF THE DENOMINATOR BY RULING, NAMED (ceo CEO-1710, Lon 2026-10-14 13:3x CDT, verbatim: "We want
# dynamic growing everything. So if another oracle has fixed and we can do better and go longer. That we should."; and CEO-1696). A row is
# file<TAB>case<TAB>class<TAB>measurement: file as the board prints it (db/test_db.pl), case the board's label (unit:test#k for one
# instance, unit:test for every instance), class SCRIP_EXCEEDS_ORACLE (the oracle's answer comes from a fixed limit SCRIP grows past, or
# from an oracle defect its own upstream has fixed), NO_ORACLE_ANSWER, or THREADS_EXCLUDED_BY_LON (ceo CEO-1766, Lon 2026-10-15, in-chat to
# the ceo, verbatim: "Put the multi-threaded Prolog work as excluded for now."): a case whose body reaches a thread builtin, its measurement
# naming the builtin; the 14 engine cases stay in the denominator. Such a case writes no progress row and leaves the denominator
# as Excl, counted under its class beside the oracle's own NO_ORACLE_ANSWER cases. A row with another class refuses rc 2; a row naming a
# case the file does not declare is STALE and reads the run red, so a declaration can never outlive what it names.
EXCL_CLASSES = ('SCRIP_EXCEEDS_ORACLE', 'NO_ORACLE_ANSWER', 'THREADS_EXCLUDED_BY_LON')
excl_cases = {}; excl_used = set()
_ex = os.path.join(swit, 'EXCLUDED_CASES.tsv')
if os.path.exists(_ex):
    for _n, _l in enumerate(open(_ex, encoding='utf-8').read().split('\n'), 1):
        if not _l.strip() or _l.startswith('#'): continue
        _c = _l.split('\t')
        if len(_c) < 4 or _c[2] not in EXCL_CLASSES or not _c[3].strip():
            print('⛔ REFUSED (rc 2): %s line %d is not file<TAB>case<TAB>%s<TAB>measurement: %r' % (_ex, _n, '|'.join(EXCL_CLASSES), _l[:160]))
            sys.exit(2)
        excl_cases[(_c[0], _c[1])] = _c[2]
def excluded_class(rel, label):
    for k in ((rel, label), (rel, label.rsplit('#', 1)[0])):
        if k in excl_cases: excl_used.add(k); return excl_cases[k]
    return None
rows = []; reds = []; perfile = []
for f in open(files).read().split('\n'):
    if not f: continue
    rel = f[len(swit) + 1:]; od = os.path.join(work, 'out', rel[:-3])
    per = {}
    for m in modes:
        p = os.path.join(od, m + '.tsv')
        txt = open(p).read() if os.path.exists(p) else ''
        if txt.startswith('NOREF'): noref.append(rel); per = None; break
        per[m] = [l.split('\t') for l in txt.split('\n') if l and '\t' in l]
    if per is None: continue
    first = per[modes[0]]
    n_decl = len(first); declared += n_decl
    # each case row's secs: its mode's process wall over the case rows that process produced, so the suite's summed secs is its wall
    def _secs(m):
        try:
            return float(open(os.path.join(od, m + '.secs')).read().strip() or 0) / max(1, n_decl)
        except (OSError, ValueError):
            return 0.0
    csecs = {m: '%.3f' % _secs(m) for m in modes}
    fpass = 0; fgraded = 0
    for i, row in enumerate(first):
        label, verdict = row[0], row[1]
        if verdict == 'UNGRADED':
            # ⛔⭐ THE 77 ARE APPENDED, NOT SKIPPED (coo COO-84 4d / CEO-779, 2026-09-16). They were counted, classified
            # and PRINTED on the board line and then dropped on this `continue`, so the DB carried 2858 programs for a
            # row whose denominator is 2935 and the CEO-749 identity -- PASS+FAIL+OUTSIDE+UNGRADABLE+UNGRADED+DEFERRED
            # == population -- could not be checked from the DB at all. ⭐ A case NAMED on the board and ABSENT from the
            # table is worse than one that is simply missing: the board says the denominator is whole, and the only
            # instrument that could contradict it has no row to do it with.
            # The vocabulary already carries both words (util_progress_append.py OUTCOMES), so nothing is invented here:
            # the 45 the ORACLE refuses are UNGRADABLE -- its reason, never ours -- and the 30 EMPTY plus 2 BLOCKED are
            # UNGRADED. The reason travels in the note column so the class stays checkable case by case.
            # ⛔⭐ SINCE CEO-1696 THEY ARE EXCLUDED, NEVER DEBT (Lon 2026-10-11 16:0x CDT, in-chat to the ceo, verbatim: "Exclude any program in
            # which we have no way to get output from an oracle, or in which we do not know the answer."): every one of the 77 is the oracle's
            # (it refuses the unit, runs it to an EMPTY unit, or plunit BLOCKS the case), so each is NO_ORACLE_ANSWER -- named on the board by
            # its reason, out of the denominator as Excl, and, like a container's fragment, it writes no row: the identity the DB checks is
            # PASS+FAIL+... == the graded cases the row now divides by.
            _why = row[2].split(' ')[0] if len(row) > 2 else '?'
            ungraded_cases += 1; ungraded_reason[_why] += 1
            continue
        _cls = excluded_class(rel, label)
        if _cls:
            ungraded_cases += 1; ungraded_reason[_cls + '(EXCLUDED_CASES.tsv)'] += 1
            continue
        fgraded += 1; graded_cases += 1
        ok_all = True
        for m in modes:
            r = per[m][i] if i < len(per[m]) else [label, 'FAIL', 'no row']
            # ⛔ CRASH AND HANG STAY THEMSELVES (coo 2026-09-27, CEO-1309): every non-PASS was counted and recorded as FAIL.
            v = r[1] if r[1] in ('PASS', 'FAIL', 'CRASH', 'HANG') else 'FAIL'
            tot[m][v] += 1
            if r[1] == 'PASS' and 'agreement control' in (r[2] if len(r) > 2 else ''): tot[m]['agree_fail'] += 1
            if r[1] != 'PASS':
                ok_all = False
                if name_reds: reds.append('RED %s:%s:%s:%s' % (rel, label, m, (r[2] if len(r) > 2 else '')[:120]))
            rows.append('package\tswi\tprolog\t%s:%s\t%s\t%s\t%s\tcase of %s%s' % (rel, label, m, v, csecs[m], rel, ('' if v in ('PASS', 'FAIL') else ' -- ' + (r[2] if len(r) > 2 else '')[:40])))
        if ok_all: both += 1; fpass += 1
    perfile.append((rel, fpass, fgraded, n_decl - fgraded))
for rel, p, g, u in perfile:
    print('  %-48s %4d/%-4d agree (AND per case)%s' % (rel, p, g, ('  ungraded=%d' % u) if u else ''))
print('SWI_BOARD declared=%d graded=%d %s ungraded=%d' % (declared, graded_cases,
      ' '.join('%s_pass=%d %s_fail=%d %s_agree_fail=%d %s_crash=%d %s_hang=%d' % (m, tot[m]['PASS'], m, tot[m]['FAIL'], m, tot[m]['agree_fail'], m, tot[m]['CRASH'], m, tot[m]['HANG']) for m in modes), ungraded_cases))
print('  AND per case (agrees with the oracle in EVERY mode graded, the number the suite row states): %d/%d graded (%d declared, %d EXCLUDED: NO_ORACLE_ANSWER CEO-1696, EXCLUDED_CASES.tsv CEO-1710 and CEO-1766)' % (both, graded_cases, declared, ungraded_cases))
print('  identity: graded %d + ungraded %d == declared %d %s' % (graded_cases, ungraded_cases, declared, '✓' if graded_cases + ungraded_cases == declared else '⛔ DOES NOT SUM'))
print('  EXCLUDED (CEO-1696 NO_ORACLE_ANSWER by the oracle\'s reason; CEO-1710 and CEO-1766 EXCLUDED_CASES.tsv by class) -- named, never a pass, out of the denominator: ' + ', '.join('%s=%d' % kv for kv in sorted(ungraded_reason.items(), key=lambda kv: -kv[1])))
graded_files = {pf[0] for pf in perfile}
stale = sorted(k for k in set(excl_cases) - excl_used if k[0] in graded_files)   # a row for a file this run did not grade is not judged
if excl_cases: print('  EXCLUDED_CASES.tsv: %d row(s), %d applied, %d STALE%s' % (len(excl_cases), len(excl_used), len(stale), (' -- ' + ' '.join('%s:%s' % k for k in stale)) if stale else ''))
if noref: print('  ⛔ %d file(s) with no .ref beside them (UNGRADED, REF_NOT_CUT): %s' % (len(noref), ' '.join(noref)))
cap = int(os.environ.get('SWI_NAME_REDS_MAX', '0') or '0')
shown = reds if cap <= 0 else reds[:cap]
print('    RED-NAME-SET total=%d shown=%d%s' % (len(reds), len(shown), '' if len(shown) == len(reds) else ' ⛔ TRUNCATED by SWI_NAME_REDS_MAX=%d -- a base-vs-head diff over a truncated window shows cures ENTERING it, not regressions' % cap))
for r in shown: print('    ' + r)
open(os.path.join(work, 'rows.tsv'), 'w').write('\n'.join(rows) + ('\n' if rows else ''))
open(os.path.join(work, 'summary.txt'), 'w').write('%d %d %d %d %d\n' % (both, declared, graded_cases, len(noref), len(stale)))
PY
_aggrc=$?; [ "$_aggrc" = 0 ] || exit "$_aggrc"   # a refusal inside the aggregation (rc 2: a malformed EXCLUDED_CASES.tsv) is the run's; checked here, not on the heredoc's line, which test_gate_swi_runner_grades_a_signal_death_crash_never_fail lifts by its exact text
read -r BOTH DECLARED GRADED NOREF STALE < "$WORK/summary.txt"
if command -v progress_append_rows_tsv >/dev/null 2>&1 && [ -s "$WORK/rows.tsv" ] && [ -z "$ONLY_FILE" ]; then
    progress_append_rows_tsv "$WORK/rows.tsv" >/dev/null || echo "⚠ progress rows NOT recorded"
fi
rr_selected && { rr_end swi; exit 0; }   # a part or a request writes its cases' rows and no suite row (CEO-1802)
INV_PACKAGE=swi_tests; INV_DIR="$SWIT"; INV_EXT=".pl"
_shipped_tests=$(wc -l < "$FILES")
_iv="$(inventory_line "$((_shipped_tests - NOREF))" 0)"; _ivrc=$?
[ "$_ivrc" -eq 0 ] && echo "$_iv" || echo "⚠ the package inventory refused (rc=$_ivrc) -- the case board above stands on its own measurement; the FILE census does not"
if [ -n "$ONLY_FILE" ]; then
    echo "SUITES.tsv NOT UPDATED (by design): --file grades one file and cannot produce a suite-wide number."
else
    # the denominator is the GRADED cases (CEO-1696): DECLARED - GRADED are NO_ORACLE_ANSWER cases, shown as Excl
    printf 'SUITE_BOARD suite=swi lang=prolog tier=run pass=%s total=%s excluded=%s runner=test_prolog_swi_suite.sh\n' "$BOTH" "$GRADED" "$((DECLARED - GRADED))"
    python3 "$HERE/util_score_row.py" write --lang prolog --column vendor --suite SWI \
        --measurer "${S4E_SEAT:-}" --suite-pass "$BOTH" --suite-total "$GRADED" --excluded "$((DECLARED - GRADED))" \
        --text "swi_tests (swipl-devel src/Tests, every plunit case, agreement with swipl 9.0.4 per case) $BOTH/$GRADED by the AND PER CASE, $((DECLARED - GRADED)) case(s) EXCLUDED, NO_ORACLE_ANSWER (CEO-1696) and EXCLUDED_CASES.tsv's SCRIP_EXCEEDS_ORACLE (CEO-1710) and THREADS_EXCLUDED_BY_LON (CEO-1766), over modes $MODES (\`test_prolog_swi_suite.sh\`)${_iv:+ · $_iv (\`test_prolog_swi_suite.sh\`)}" \
        || echo "⚠ SUITES.tsv NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi
[ "${STALE:-0}" -eq 0 ] || { echo "⛔ $STALE EXCLUDED_CASES.tsv row(s) name a case no graded file declares -- STALE (named above); a declaration may not outlive what it names"; exit 1; }
[ "$NOREF" -eq 0 ] || { echo "⛔ $NOREF shipped test file(s) carry no oracle ref: cut them with ../harness/scripts/util_swi_cut_refs.sh --write"; exit 1; }
exit 0
