#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_design_pascal_packed_arrays_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: pascal-packed-arrays (the cto, 2026-11-04, R-2119; the design
# text is the pascal skill's section 8). The plan is harness/designs/packed_arrays/STEPS.tsv; a witness NAME is the entry packed_arrays__NAME of
# the pascal master corpus/tests/pascal, its ref cut from fpc 3.2.2 twice by util_add_ladder_witness.py, extracted to the step's scratch to run.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 at the step's declared heap (heap=KB, default 131072; -s4096k; stdout compared
#                exactly with the ref), under SCRIP_GC_STRESS=1 in mode 3 too when the probe says stress=1 ([GC- lines filtered), then the step's
#                probe tokens: sym=a,b (out/libscrip_rt.so exports each name), kind=NAME (gc_heap.h defines NAME and HB_KIND_NAME names it),
#                irgrep=REGEX@W:N (scrip --dump-ir of witness W prints at least N lines matching REGEX), irzero=REGEX@W (none), entries=a,b (the
#                named rosetta-pascal entries through corpus_suite_harness.py smoke under the feature writeln, no progress row, at most eight,
#                R-1677), hdrfield=NAME (gc_heap.h's rt_hblk_t declares a field uint32_t NAME). Red before the step lands, green after.
#   --cut        retired (refuses rc 2): a witness's ref is the master entry's, cut by util_add_ladder_witness.py (CIO-37)
#   --out DIR    where the runs go (default a fresh /tmp/s4e/<seat>/runner_out.pascal_packed_arrays.<pid>.* deleted at the verdict, lib_runner_out.sh; an explicit DIR is kept)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> [st=<pass>/<n>] probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
STEPS="$HERE/../designs/packed_arrays/STEPS.tsv"   # moved from corpus/tests/pascal/packed_arrays (the coo 2026-11-10, CIO-24 c, CIO-55, CIO-56: a language folder is its container alone)
OUT=""
HEAP_H="$SC/src/runtime/rt/gc_heap.h"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --cut"
[ -n "$OUT" ] || { . "$HERE/lib_runner_out.sh" && runner_out_default pascal_packed_arrays; } || refuse "no output directory under /tmp/s4e (lib_runner_out.sh)"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: pascal-packed-arrays -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (harness/designs/packed_arrays/STEPS.tsv); a witness is the entry packed_arrays__<name> of the pascal master (refs from fpc 3.2.2)"
    printf '%-4s %-54s %-12s %-8s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-54s %-12s %-8s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
. "$HERE/lib_design_witness.sh" || refuse "lib_design_witness.sh unloadable"
# ⭐ A WITNESS IS AN ENTRY OF THE PASCAL MASTER (CIO-24 c, CIO-56; the coo 2026-11-10): witness NAME DIR extracts the entry packed_arrays__NAME
# into DIR and sets WP (its .pas) and WR (its ref); the step's own runs below (its heap, stress and probes) read those files, so a step
# measures what it measured when the witness was a loose pair.
witness() {
    local d="$2"; mkdir -p "$d"
    design_witness_has pascal "packed_arrays__$1" || refuse "witness $1: no entry packed_arrays__$1 in corpus/tests/pascal"
    design_witness_extract pascal "packed_arrays__$1" "$d" > /dev/null 2>&1 || refuse "witness $1: its entry packed_arrays__$1 did not extract"
    WP="$d/packed_arrays__$1.pas"; WR="$d/packed_arrays__$1.ref"
}
if [ "$mode" = cut ]; then
    refuse "--cut retired: the witnesses are entries of corpus/tests/pascal, each ref cut from fpc twice by util_add_ladder_witness.py --lang pascal --family packed_arrays (CIO-37)"
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    . "$HERE/lib_slots.sh"; s4e_slot_hold run || true
fi
[ "$probe" = "-" ] && probe=""
heap=131072; stress=0
for tok in $probe; do case "$tok" in heap=*) heap="${tok#heap=}" ;; stress=1) stress=1 ;; esac; done
m3p=0; m4p=0; stp=0; n=0; reds=""
[ "$wits" = "-" ] && wits=""
run_m3() { ( cd "$1" && timeout -k 5 300 "$SC/scrip" -d"${heap}k" -s4096k "$2.pas" < /dev/null > "$1/out" 2> "$1/err" ); }
for w in $wits; do
    witness "$w" "$OUT/step$step/wit"; ref="$WR"
    [ -f "$WP" ] && [ -f "$ref" ] || refuse "witness $w: no .pas or .ref after extracting packed_arrays__$w"
    n=$((n + 1))
    for m in m3 m4 st; do
        [ "$m" = st ] && [ "$stress" = 0 ] && continue
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WP" "$d/$w.pas"
        if [ "$m" = m3 ]; then
            run_m3 "$d" "$w"; rc=$?
        elif [ "$m" = st ]; then
            SCRIP_GC_STRESS=1 run_m3 "$d" "$w"; rc=$?; grep -v '^\[GC-' "$d/out" > "$d/out.f"; mv "$d/out.f" "$d/out"
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile --out="$d/run.s" "$w.pas" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 300 "$d/run.bin" -d"${heap}k" -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then
            case "$m" in m3) m3p=$((m3p + 1)) ;; m4) m4p=$((m4p + 1)) ;; st) stp=$((stp + 1)) ;; esac
        else reds="$reds $m:$w(rc$rc)"; fi
    done
done
readings=""; pgreen=1
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        heap|stress) ;;
        sym) so="$SC/out/libscrip_rt.so"; [ -f "$so" ] || refuse "no $so"; miss=0; for s in ${val//,/ }; do nm -D "$so" 2> /dev/null | grep -q " T $s\$" || miss=$((miss + 1)); done
             readings="$readings sym_missing=$miss"; [ "$miss" = 0 ] || pgreen=0 ;;
        kind) [ -f "$HEAP_H" ] || refuse "no $HEAP_H"; ok=0; grep -q "^#define $val " "$HEAP_H" && grep -q "== $val ? \"$val\"" "$HEAP_H" && ok=1
              readings="$readings kind_$val=$ok"; [ "$ok" = 1 ] || pgreen=0 ;;
        irgrep|irzero) re="${val%@*}"; rest="${val#*@}"; w="${rest%%:*}"; need="${rest#*:}"; [ "$key" = irzero ] && need=0
              d="$OUT/step$step/$w.ir"; mkdir -p "$d"; witness "$w" "$d"; cp "$WP" "$d/$w.pas"
              ( cd "$d" && timeout -k 5 300 "$SC/scrip" --dump-ir "$d/$w.pas" < /dev/null > "$d/ir" 2> "$d/err" ); cnt="$(grep -c -E -- "$re" "$d/ir")"
              if [ "$key" = irzero ]; then readings="$readings irzero_$w=$cnt"; [ "$cnt" = 0 ] || pgreen=0
              else readings="$readings irgrep_$w=$cnt(need $need)"; [ "$cnt" -ge "$need" ] || pgreen=0; fi ;;
        entries) es="${val//,/ }"; cnt=0; for e in $es; do cnt=$((cnt + 1)); done; [ "$cnt" -le 8 ] || refuse "step $step names $cnt entries; the handful is at most eight (R-1677)"
                 sm="$(cd "$ROOT" && S4E_HOME="$ROOT" timeout -k 10 1500 python3 "$HERE/corpus_suite_harness.py" smoke writeln --tables packages/pascal/rosetta-pascal --entries "$es" --modes m3,m4 2>&1)"
                 printf '%s\n' "$sm" > "$OUT/step$step/smoke.log"
                 ok=0; for e in $es; do printf '%s\n' "$sm" | grep -E "^AREA_SMOKE_ENTRY .*entry=$e .*m3=PASS.*m4=PASS" > /dev/null && ok=$((ok + 1)); done
                 readings="$readings entries=$ok/$cnt"; [ "$ok" = "$cnt" ] || pgreen=0 ;;
        hdrfield) [ -f "$HEAP_H" ] || refuse "no $HEAP_H"; ok=0; grep -q "^typedef struct rt_hblk_t {.* uint32_t $val;" "$HEAP_H" && ok=1
                  readings="$readings hdrfield_$val=$ok"; [ "$ok" = 1 ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
[ "$stress" = 1 ] && { [ "$stp" = "$n" ] || verdict=RED; }
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n$([ "$stress" = 1 ] && echo " st=$stp/$n") probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
