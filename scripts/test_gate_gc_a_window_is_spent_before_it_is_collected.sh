#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_a_window_is_spent_before_it_is_collected.sh -- THE COLLECTOR SPENDS ITS WINDOW AS SPITBOL SPENDS ITS -i (ceo 2026-09-25,
# CEO-1264; Lon 2026-09-25 10:06, in-chat to the ceo: "continue getting all demos and benchmarks running faster than SPITBOL").
# SPITBOL's alloc (sbl.min aloc1..aloc4) collects only when an allocation does not fit its dynamic area, and grows the area by -i when
# a collection leaves less than e_fsp = 15 percent free. SCRIP collected at HALF its free window and grew only when an allocation
# overran it, so under the demo grid's -d512m -i64m treebank collected once (110 ms) where SPITBOL collected zero times, and a program
# whose live set outgrows the window thrashed. Since this landing the line leaves one sixteenth of the free window as burst room and a
# collection that leaves under 15 percent free grows the window at once (gc_heap.c GC_FREE_PCT).
# THE ORACLE IS SPITBOL's OWN COUNT: sbl -bf -x prints REGENERATIONS; both engines run at their shipped defaults (-i1m for both).
# ARMS: (1) fit.sno -- garbage that fits the window -- collects exactly as often as SPITBOL (0), in m3 and m4; (2) grow.sno -- a live
# set that outgrows the window by seven times -- collects at most twice SPITBOL's count plus two, in m3 and m4; (3) both answer the
# oracle in both modes.
# FAIL_ONCE (recorded): the pre-pacing runtime at d566528fa read fit 1 collection in both modes and grow 100 in m3 and 72 in m4 (SPITBOL 0
# and 10); this tree reads fit 0 and grow 11 in m3 and 10 in m4.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (the oracle, its count or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/fit.sno" <<'SNO'
        I = 0
LOOP    S = DUPL('x', 100) I
        I = LT(I, 3000) I + 1                           :S(LOOP)
        OUTPUT = SIZE(S) ' ' I
END
SNO
cat > "$W/grow.sno" <<'SNO'
        T = TABLE()
        I = 0
LOOP    T[I] = DUPL('y', 200) I
        I = LT(I, 20000) I + 1                          :S(LOOP)
        OUTPUT = SIZE(T[7]) ' ' SIZE(T[19999])
END
SNO
red=0
for p in fit grow; do
  ref="$( cd "$W" && "$SBL" $(sbl_lang_flags) $p.sno < /dev/null 2>/dev/null )"; [ -n "$ref" ] || { echo "REFUSED(2): the oracle printed nothing for $p.sno"; exit 2; }
  rg="$( cd "$W" && "$SBL" $(sbl_lang_flags) -x $p.sno < /dev/null 2>/dev/null | grep -m1 'REGENERATIONS' | grep -oE '[0-9]+$' )"; [ -n "$rg" ] || { echo "REFUSED(2): sbl -x printed no REGENERATIONS for $p.sno"; exit 2; }
  ( cd "$W" && "$ROOT/scrip" --compile --out=$p.s $p.sno < /dev/null > /dev/null 2>&1 && gcc $p.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o $p.bin 2>/dev/null ) || { echo "REFUSED(2): $p.sno did not build in mode 4"; exit 2; }
  if [ $p = fit ]; then bound=$rg; else bound=$((2 * rg + 2)); fi
  for m in m3 m4; do
    if [ $m = m3 ]; then run=( "$ROOT/scrip" $p.sno ); else run=( ./$p.bin ); fi
    out="$( cd "$W" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB -u SCRIP_GC_STRESS -u SCRIP_GC_LINE_MB SCRIP_GC_EXERCISE=1 timeout -k 5 60 "${run[@]}" < /dev/null 2>"$W/$p.$m.err" )"
    n="$(grep -m1 '^\[GC-EXERCISE\]' "$W/$p.$m.err" | grep -oE 'collections=[0-9]+' | cut -d= -f2)"; [ -n "$n" ] || { echo "REFUSED(2): $p $m printed no [GC-EXERCISE] collections= line"; exit 2; }
    [ "$out" = "$ref" ] && echo "ok  (3) $p $m answers the oracle" || { echo "RED (3) $p $m: [$out] against the oracle's [$ref]"; red=1; }
    if [ "$n" -le "$bound" ]; then echo "ok  ($([ $p = fit ] && echo 1 || echo 2)) $p $m collects $n times at the shipped window; SPITBOL at its -i1m regenerates $rg (bound $bound)"
    else echo "RED ($([ $p = fit ] && echo 1 || echo 2)) $p $m collects $n times at the shipped window where SPITBOL regenerates $rg (bound $bound) -- the collector is not spending its window"; red=1; fi
  done
done
[ "$red" -eq 0 ] && { echo "GATE OK: the collector spends its window before collecting it and grows a window a collection leaves nearly full, as SPITBOL does"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
