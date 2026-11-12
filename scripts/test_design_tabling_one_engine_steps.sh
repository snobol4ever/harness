#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_design_tabling_one_engine_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: tabling-one-engine (the cio 2026-11-10, CIO-104 amended by
# CIO-105; skill prolog-tabling reference section 5: every table of every kind is evaluated by the one suspend-and-resume scheduler and the round
# engine is deleted). Written by the cfo 2026-11-11 (CIO-126, the row tabling-one-engine-the-plan-lands-...). The plan is
# harness/designs/tabling_one_engine/STEPS.tsv (a step table is an instrument, CIO-24); its witnesses are ENTRIES of the Prolog master
# corpus/tests/prolog/ALL.pl, family one_engine, each answer cut from swipl 9.0.4 by util_add_ladder_witness.py. A witness prints one line each time
# a rule body runs; the law is the number of body runs, so oe1 to oe7 sort their own output and the compare is the master's exact compare.
#
#   --list            print the steps and run nothing
#   --step N          grade step N: every witness in mode 3 and mode 4 through corpus_suite_harness.py run --partition entry:NAME (its readings go
#                     to a scratch store, never results.tsv), then the step's probe tokens:
#                       swi=FILE:N       results.tsv, suite swi, mode 3: the cases of FILE whose latest reading is PASS number at least N (read, never run)
#                       fam=FAMILY:N     results.tsv, suite xsb, mode 3: the programs of the XsbTests family whose latest reading is PASS number at least N
#                       nosym=FILE:A,B   none of the quoted atoms 'A', 'B' occurs in FILE (a path from the root)
#                       maxlines=FILE:N  FILE holds at most N lines
#                       none             no probe
#   --cut             the oracle's answer of every witness the table names, cut again and compared with the master's (corpus_suite_harness.py
#                     expect); rc 1 naming a difference; it writes nothing (an answer is replaced through the master's own tools)
#   --table FILE      read FILE in place of the plan's table      } the two doors by which the tokens are proven fail-once and pass-once on a
#   --results FILE    read FILE in place of results.tsv           } planted table and a planted store; no step row uses them
#   --out DIR         where the runs' logs go (default a fresh folder under /tmp/s4e/<seat>, deleted at a GREEN verdict)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token readings> -> GREEN|RED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
MASTER="$ROOT/corpus/tests/prolog"
STEPS="$ROOT/harness/designs/tabling_one_engine/STEPS.tsv"
RESULTS=/home/resources/progress/results.tsv
OUT=""
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --table) STEPS="${2:-}"; [ -n "$STEPS" ] || refuse "--table takes a file"; shift 2 ;;
        --results) RESULTS="${2:-}"; [ -n "$RESULTS" ] || refuse "--results takes a file"; shift 2 ;;
        --out) OUT="${2:-}"; [ -n "$OUT" ] || refuse "--out takes a folder"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --cut   [--table FILE] [--results FILE]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --cut   [--table FILE] [--results FILE]"
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
rows() { grep -v '^#' "$STEPS" | awk -F'\t' 'NF >= 6 && $1 ~ /^[0-9]+$/'; }
[ -n "$(rows)" ] || refuse "the step table $STEPS names no step"
if [ "$mode" = list ]; then
    rows | awk -F'\t' '{ printf "%-3s %-66s %-8s %-8s %s\n", $1, $2, $3, $4, $6 }'
    exit 0
fi
[ -f "$MASTER/ALL.csv" ] && python3 "$HERE/corpus_suite_harness.py" list "$MASTER/ALL.pl" "$MASTER/ALL.ref" --lang prolog > /dev/null 2>&1 || refuse "no Prolog master at $MASTER"   # the harness reads either container format through these names (CIO-24 f)
in_master() { awk -F, -v e="$1" 'NR > 1 && $2 == e { f = 1 } END { exit f ? 0 : 1 }' "$MASTER/ALL.csv"; }
if [ "$mode" = cut ]; then
    wits="$(rows | awk -F'\t' '{ print $6 }' | tr ' ' '\n' | grep -v '^$' | sort -u)"
    n=0; for w in $wits; do in_master "$w" || refuse "witness $w is no entry of $MASTER/ALL.csv"; n=$((n + 1)); done
    o="$(cd "$SC" && timeout -k 10 1200 python3 "$HERE/corpus_suite_harness.py" expect "$MASTER/ALL.pl" "$MASTER/ALL.ref" --lang prolog --only "$(echo $wits | tr ' ' ',')" 2>&1)"
    line="$(printf '%s\n' "$o" | grep '^EXPECT_CENSUS ' | tail -1)"
    [ -n "$line" ] || { printf '%s\n' "$o" | tail -5 >&2; refuse "the oracle census did not print its line"; }
    echo "$line"
    case "$line" in *" entries=$n "*) ;; *) refuse "the census read another count than the table's $n witnesses" ;; esac
    case "$line" in *" stdout_differs=0 "*) echo "CUT OK [test_design_tabling_one_engine_steps]: $n witnesses, every answer equals the oracle's"; exit 0 ;; esac
    printf '%s\n' "$o" | grep -v '=ref' | grep -P '^one_engine__\S+\t' | cut -c1-200
    echo "CUT FAIL [test_design_tabling_one_engine_steps]: an answer of the master differs from the oracle's"; exit 1
fi
row="$(rows | awk -F'\t' -v s="$step" '$1 == s')"
[ -n "$row" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(printf '%s' "$row" | cut -f2)"; probe="$(printf '%s' "$row" | cut -f5)"; wits="$(printf '%s' "$row" | cut -f6)"
[ -n "$wits" ] || refuse "step $step names no witness"
made=0
if [ -z "$OUT" ]; then OUT="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-x}/runner_out.one_engine.$$.XXXXXX" 2>/dev/null)" || { mkdir -p "/tmp/s4e/${S4E_SEAT:-x}" && OUT="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-x}/runner_out.one_engine.$$.XXXXXX")"; } || refuse "no scratch folder"; made=1; fi
mkdir -p "$OUT" || refuse "cannot make $OUT"
field() { printf '%s\n' "$1" | tr ' ' '\n' | awk -F= -v k="$2" '$1 == k { print $2; exit }'; }
m3p=0; m4p=0; n=0; reds=""
for w in $wits; do
    in_master "$w" || refuse "witness $w is no entry of $MASTER/ALL.csv"
    n=$((n + 1))
    log="$OUT/step$step.$w.log"
    ( cd "$SC" && S4E_HOME="$ROOT" S4E_MODE4=1 S4E_PROGRESS_DB="$OUT/progress.scratch.tsv" timeout -k 10 900 python3 "$HERE/corpus_suite_harness.py" run "$MASTER/ALL.pl" "$MASTER/ALL.ref" --lang prolog --modes m3,m4 --partition "entry:$w" ) > "$log" 2>&1
    board="$(grep '^SUITE_BOARD ' "$log" | tail -1)"
    [ -n "$board" ] || { tail -5 "$log" >&2; refuse "the run of $w printed no SUITE_BOARD line (log $log)"; }
    a="$(field "$board" m3_n)"; b="$(field "$board" m3_pass)"; c="$(field "$board" m4_n)"; d="$(field "$board" m4_pass)"
    [ "$a" = 1 ] && [ "$c" = 1 ] || refuse "the run of $w graded m3_n=${a:-?} m4_n=${c:-?}, not one entry in each mode (log $log)"
    [ "$b" = 1 ] && m3p=$((m3p + 1)) || reds="$reds m3:$w"
    [ "$d" = 1 ] && m4p=$((m4p + 1)) || reds="$reds m4:$w"
done
latest_pass() {
    awk -F'\t' -v suite="$1" -v key="$2" -v kind="$3" 'NR > 1 && $6 == suite && $9 == "m3" {
            if (kind == "file") { if (index($8, key ":") != 1) next }
            else { split($8, p, "_"); fam = (p[2] == "tests") ? p[1] "_tests" : p[1]; if (fam != key) next }
            if ($1 > ts[$8]) { ts[$8] = $1; o[$8] = $10 } }
        END { c = 0; for (k in o) if (o[k] == "PASS") c++; print c }' "$RESULTS"
}
readings=""; pgreen=1
for tok in $probe; do
    [ "$tok" = none ] && { readings="$readings none"; continue; }
    key="${tok%%=*}"; val="${tok#*=}"; f="${val%:*}"; arg="${val##*:}"
    [ "$key" != "$tok" ] && [ "$f" != "$val" ] && [ -n "$arg" ] || refuse "probe token $tok of step $step is not KIND=FILE:VALUE"
    case "$key" in
        swi|fam) [ -r "$RESULTS" ] || refuse "no readable store at $RESULTS"; case "$arg" in ''|*[!0-9]*) refuse "token $tok: the count is not a number" ;; esac
                 if [ "$key" = swi ]; then got="$(latest_pass swi "$f" file)"; else got="$(latest_pass xsb "$f" family)"; fi
                 readings="$readings $key[$f]=$got(need $arg)"; [ "$got" -ge "$arg" ] || pgreen=0 ;;
        nosym) [ -f "$ROOT/$f" ] || refuse "token $tok: no file $ROOT/$f"; cnt=0
               for s in $(printf '%s' "$arg" | tr ',' ' '); do k="$(grep -c -F -- "'$s'" "$ROOT/$f")"; cnt=$((cnt + k)); done
               readings="$readings nosym[$(basename "$f")]=$cnt"; [ "$cnt" = 0 ] || pgreen=0 ;;
        maxlines) [ -f "$ROOT/$f" ] || refuse "token $tok: no file $ROOT/$f"; case "$arg" in ''|*[!0-9]*) refuse "token $tok: the bound is not a number" ;; esac
                  got="$(wc -l < "$ROOT/$f")"; readings="$readings maxlines[$(basename "$f")]=$got(at most $arg)"; [ "$got" -le "$arg" ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && { [ "$made" = 1 ] && rm -rf "$OUT"; exit 0; }
[ "$made" = 1 ] && echo "  logs kept: $OUT"
exit 1
