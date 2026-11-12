#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_design_prolog_gnu_gaps_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: prolog-gnu-gaps (the cto, 2026-11-07, CTO-543; skill prolog
# reference section 8). The plan is harness/designs/prolog_gnu_gaps/STEPS.tsv; a witness W is the entry gnu_gaps__W of the Prolog master
# (corpus/tests/prolog, dialect cell gnu), extracted by lib_design_witness.sh into the step's scratch, or the loose corpus/tests/prolog/gnu_gaps/W.pl
# while the master has not absorbed it (gg_listing_0: listing/0 prints its file's absolute path, so its answer is no stable entry; the cto
# 2026-11-12, row tests-folder-consolidation-cto). Each answer is cut from
# GNU Prolog 1.6.0 through gprolog_bin() (lib_oracle_flags.sh: --consult-file W --query-goal halt, the output through gprolog_output_filter, run
# TWICE and refused on a disagreement), the one GNU-dialect oracle. Every witness is a GNU-dialect program (R-1810: a gprolog-graded program
# declares --dialect=gnu), run from a scratch folder so a file a witness writes never lands under the root; the witness folder's path is written
# DIR in every reading (listing/0 prints "% file: PATH").
#
#   --list         print the steps and run nothing
#   --step N       grade step N: every witness of the step in mode 3 (scrip --run --dialect=gnu W) and mode 4 (--compile, gcc, run), byte-equal
#                  to its .ref with rc 0; probe 'witnesses' is green when every witness passes both modes
#   --cut [W...]   re-cut the .ref of every witness (or the named ones) from gprolog, twice; a disagreement between the two runs refuses
#   --out DIR      where the .s, binaries, logs and the witnesses' scratch files go (default /tmp/s4e/${S4E_SEAT:-cto}/design-prolog-gnu-gaps)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<reading> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (no ./scrip,
# no witness, no ref, no oracle). It grades no corpus population: a witness folder is not a suite (R-1342).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/prolog/gnu_gaps"
STEPS="$ROOT/harness/designs/prolog_gnu_gaps/STEPS.tsv"
. "$HERE/lib_design_witness.sh"
OUT="/tmp/s4e/${S4E_SEAT:-cto}/design-prolog-gnu-gaps"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""; cutlist=()
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do cutlist+=("$1"); shift; done ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N | --cut [W...] [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --cut [W...] [--out DIR]"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
steps() { awk -F'\t' '!/^#/ && $1 != "step" && NF > 1 {print $1}' "$STEPS"; }
norm() { sed "s#$WD#DIR#g"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: prolog-gnu-gaps -- $(steps | wc -l) steps (STEPS.tsv); witnesses in $WD; oracle gprolog 1.6.0 (gprolog_bin)"
    printf '%-4s %-28s %-8s %-10s %s\n' step slug executor probe witnesses
    for n in $(steps); do printf '%-4s %-28s %-8s %-10s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 5)" "$(col "$n" 6)"; done
    exit 0
fi
if [ "$mode" = cut ]; then
    . "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable"
    GP="$(gprolog_bin)" || refuse "no gprolog oracle (gprolog_bin)"
    [ "${#cutlist[@]}" -gt 0 ] || { for n in $(steps); do for w in $(col "$n" 6); do cutlist+=("$w"); done; done; }
    mkdir -p "$OUT/cut" || refuse "cannot make $OUT/cut"
    for w in "${cutlist[@]}"; do
        design_witness_has prolog "gnu_gaps__$w" && refuse "$w is the entry gnu_gaps__$w of the master: its answer is re-cut by util_add_ladder_witness.py, never here"
        src="$WD/$w.pl"; [ -f "$src" ] || refuse "no witness $src"
        d="$OUT/cut/$w"; rm -rf "$d"; mkdir -p "$d"
        a="$(cd "$d" && timeout -k 5 60 "$GP" --consult-file "$src" --query-goal halt < /dev/null 2>/dev/null | gprolog_output_filter | norm)"
        rm -rf "$d"; mkdir -p "$d"
        b="$(cd "$d" && timeout -k 5 60 "$GP" --consult-file "$src" --query-goal halt < /dev/null 2>/dev/null | gprolog_output_filter | norm)"
        [ "$a" = "$b" ] || refuse "gprolog answered $w differently on two runs -- the witness is not deterministic"
        [ -n "$a" ] || refuse "gprolog printed nothing for $w -- an empty ref is no ref"
        printf '%s\n' "$a" > "$WD/$w.ref"
        echo "CUT $w.ref $(wc -l < "$WD/$w.ref") lines from gprolog"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
[ -f "$SC/out/libscrip_rt.so" ] || refuse "no $SC/out/libscrip_rt.so -- mode 4 cannot link"
[ -n "$wits" ] || refuse "step $step names no witnesses"
mkdir -p "$OUT/step$step" || refuse "cannot make $OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ] && [ -f "$HERE/lib_slots.sh" ]; then . "$HERE/lib_slots.sh"; s4e_slot_hold run || true; fi
m3p=0; m4p=0; n=0; reds=""
for w in $wits; do
    n=$((n + 1)); src="$WD/$w.pl"; ref="$WD/$w.ref"; o="$OUT/step$step/$w"; d="$OUT/step$step/run-$w"
    if design_witness_has prolog "gnu_gaps__$w"; then
        design_witness_extract prolog "gnu_gaps__$w" "$OUT/step$step/wit" > /dev/null || refuse "the master would not extract gnu_gaps__$w"
        src="$OUT/step$step/wit/gnu_gaps__$w.pl"; ref="$OUT/step$step/wit/gnu_gaps__$w.ref"
    fi
    [ -f "$src" ] && [ -f "$ref" ] || refuse "witness $w has no .pl or .ref (neither the entry gnu_gaps__$w nor the loose pair in $WD)"
    rm -rf "$d"; mkdir -p "$d"
    ( cd "$d" && timeout -k 5 60 "$SC/scrip" --run --dialect=gnu "$src" < /dev/null 2> "$o.m3.err" | norm > "$o.m3.out"; exit "${PIPESTATUS[0]}" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then m3p=$((m3p + 1)); else reds="$reds m3:$w(rc$rc)"; fi
    [ "${S4E_MODE4:-0}" = 1 ] || continue   # mode 3 ONLY (Lon, COO-487): mode 4 is graded only under S4E_MODE4=1
    rm -rf "$d"; mkdir -p "$d"
    if ( cd "$d" && timeout -k 5 120 "$SC/scrip" --compile --dialect=gnu --out="$o.s" "$src" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$d" && timeout -k 5 60 "$o.bin" < /dev/null 2> "$o.m4.err" | norm > "$o.m4.out"; exit "${PIPESTATUS[0]}" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then m4p=$((m4p + 1)); else reds="$reds m4:$w(rc$rc)"; fi
    else reds="$reds m4:$w(nocompile)"; fi
done
reading="witnesses $m3p/$n+$m4p/$n"
if [ "$m3p" = "$n" ] && { [ "${S4E_MODE4:-0}" != 1 ] || [ "$m4p" = "$n" ]; }; then echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=$probe:$reading -> GREEN"; exit 0; fi
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=$probe:$reading red:$reds -> RED (diffs under $OUT/step$step)"; exit 1
