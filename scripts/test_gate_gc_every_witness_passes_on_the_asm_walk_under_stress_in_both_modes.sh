#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_every_witness_passes_on_the_asm_walk_under_stress_in_both_modes.sh -- THE ROAD THE BENCHMARKS SHIP IS THE ROAD A RED
# REACHES (the cto's review of dc4596a7e, f8ab07a92 and 485c7c910, 2026-10-17, item (1); hq_runtime's landing; CEO-1793).
#
# ⛔ WHY THIS EXISTS. gc_sw_run takes the asm stack-walk step (rt_gc_sw_step_a, rtx_gc.s) only when the collector's census is off,
# and the census follows SCRIP_DIAG, which is ON unless a runner turns it off. Every suite pass, every gate and every
# SCRIP_GC_CHAIN_CHECK run therefore graded the C walk, while every benchmark (CEO-1262: diagnostics off) shipped the asm walk --
# the cto's gdb break on rt_gc_sw_step_a never fired on hb_coexpr_parked at the default. MEASURED when this gate was cut (SCRIP
# 43552a85a): 760 entries into the step at SCRIP_DIAG=0, none at SCRIP_DIAG=1, on one binary.
#
# ARM (a): every witness of ../harness/scripts/gc_witnesses with a committed ref (refs are cut from the oracle), at SCRIP_DIAG=0
# SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 (a collection at every safe point in a window that forces growth), mode 3 and mode 4, at the
# witness's declared stack (<stem>.stack) and compile switches (<stem>.cmdline, read by declared_compile_args_beside and placed after
# scrip and after --compile: hb_label_trace_hook declares --stlimit, the switch label TRACE belongs to, Lon CEO-1243), stdin from <stem>.in, its stdout with the ^GC- lines dropped against its ref with the
# same lines dropped. A witness that fails on every road is a line of ../harness/scripts/gc_witness_asm_walk_floor.tsv naming its live row:
# printed DECLARED, never silenced, and RED when it passes in both modes (the cure moves the line out in the same commit).
# ARM (b): the asm step is entered -- gdb counts the hits of a breakpoint on rt_gc_sw_step_a over $STEPW in both modes at
# SCRIP_DIAG=0 (must be above zero) and at SCRIP_DIAG=1 (the control, must be zero: a counter that reads the same on both roads
# cannot tell them apart, so a nonzero control REFUSES rather than passes). GC_ASMWALK_FLOOR and GC_ASMWALK_STEP_WITNESS are this
# instrument's own switches (a scratch floor, another step witness), for proving each arm reads red.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; SCRIP="$ROOT/scrip"; LIBDIR="$ROOT/out"; WITDIR="$ROOT/../harness/scripts/gc_witnesses"; FLOOR="${GC_ASMWALK_FLOOR:-$ROOT/../harness/scripts/gc_witness_asm_walk_floor.tsv}"
STEPW="${GC_ASMWALK_STEP_WITNESS:-hb_coexpr_parked.icn}"; MIN_WITS=50
refuse() { echo "⛔ GATE REFUSED(2) [gc_every_witness_passes_on_the_asm_walk]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the mode-4 arms would measure nothing"
[ -d "$WITDIR" ] || refuse "no witness directory at $WITDIR"
[ -f "$FLOOR" ] || refuse "no declared floor at $FLOOR"
[ -f "$WITDIR/$STEPW" ] || refuse "the step witness $STEPW is not in $WITDIR"
command -v gdb >/dev/null 2>&1 || refuse "gdb is not installed -- arm (b) cannot prove the asm step ran"
. "$ROOT/../harness/scripts/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- a run at undeclared sizes is not the witness's run"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FLOORED="$(grep -v '^#' "$FLOOR" | cut -f1 | sed '/^$/d')"
for f in $FLOORED; do [ -f "$WITDIR/$f" ] && [ -r "$WITDIR/${f%.*}.ref" ] || refuse "the floor names $f, which the witness set does not carry with a ref -- a line for a witness this gate never grades could never read stale"; done
in_floor() { printf '%s\n' $FLOORED | grep -qx -- "$1"; }
ENVW="env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=0 SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64"
grade() {
  local out="$1" ref="$2" rc="$3"
  [ "$rc" = 124 ] && { echo HANG; return; }
  [ "$rc" -ge 128 ] && { echo "CRASH(rc=$rc)"; return; }
  if cmp -s <(grep -v '^GC-' "$out") <(grep -v '^GC-' "$ref"); then echo PASS; else echo "DIFF(rc=$rc)"; fi
}
graded=0; pass_both=0; declared=""; stale=""; newbad=""
for src in "$WITDIR"/*.icn "$WITDIR"/*.sno "$WITDIR"/*.pl "$WITDIR"/*.raku "$WITDIR"/*.sc "$WITDIR"/*.pas; do
  [ -e "$src" ] || continue
  ref="${src%.*}.ref"; [ -r "$ref" ] || continue
  w="$(basename "$src")"; ext="${w##*.}"; inp="${src%.*}.in"; [ -r "$inp" ] || inp=/dev/null
  st="$(declared_stack_kb_beside "$src")" || refuse "$w: its .stack sidecar declares nothing readable"
  stk=""; [ -n "$st" ] && stk="SCRIP_STACK=${st}k"
  ca="$(declared_compile_args_beside "$src")" || refuse "$w: its .cmdline sidecar declares no command line readable for it"
  graded=$((graded+1))
  ( $ENVW $stk timeout -k 5 60s "$SCRIP" $ca "$src" < "$inp" > "$T/m3.out" 2> "$T/m3.err" ) 2> /dev/null; rc=$?; v3="$(grade "$T/m3.out" "$ref" "$rc")"
  rm -f "$T/w".* "$T/w.x"; cp "$src" "$T/w.$ext"
  if ( cd "$T" && timeout -k 5 90s "$SCRIP" --compile $ca -o w.s "w.$ext" < /dev/null > /dev/null 2> w.cerr \
      && gcc -m64 w.s -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o w.x 2>> w.cerr ); then
    ( $ENVW $stk timeout -k 5 60s "$T/w.x" < "$inp" > "$T/m4.out" 2> "$T/m4.err" ) 2> /dev/null; rc=$?; v4="$(grade "$T/m4.out" "$ref" "$rc")"
  else
    v4="COMPILE"
  fi
  if [ "$v3" = PASS ] && [ "$v4" = PASS ]; then
    pass_both=$((pass_both+1)); in_floor "$w" && stale="$stale $w"
  elif in_floor "$w"; then
    declared="$declared $w(m3=$v3,m4=$v4)"
  else
    newbad="$newbad $w(m3=$v3,m4=$v4)"
  fi
done
[ "$graded" -ge "$MIN_WITS" ] || refuse "only $graded witnesses with refs were graded (floor $MIN_WITS) -- a shrunken population is not a pass"
for sym in rt_gc_sw_step_a gc_collect_ex gc_collect_ex_c; do
cat > "$T/count.$sym.gdb" <<GDB
set pagination off
set confirm off
set breakpoint pending on
break $sym
commands
silent
continue
end
run
info breakpoints
GDB
done
step_hits() {
  local sym="$1" log="$T/gdb.$1.$2.$3"
  shift 3
  timeout -k 5 300s "$@" < /dev/null > "$log" 2>&1
  grep -q "in $sym at" "$log" || { echo "UNRESOLVED"; return; }
  local n; n="$(sed -n 's/.*breakpoint already hit \([0-9]*\) time.*/\1/p' "$log" | head -1)"
  echo "${n:-0}"
}
sext="${STEPW##*.}"; cp "$WITDIR/$STEPW" "$T/s.$sext"
( cd "$T" && "$SCRIP" --compile -o s.s "s.$sext" < /dev/null > /dev/null 2>&1 && gcc -m64 s.s -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o s.x ) \
  || refuse "the step witness $STEPW does not compile and link in mode 4"
step_red=""
for d in 0 1; do
  h3="$(step_hits rt_gc_sw_step_a m3 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.rt_gc_sw_step_a.gdb" --args "$SCRIP" "$WITDIR/$STEPW")"
  h4="$(step_hits rt_gc_sw_step_a m4 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.rt_gc_sw_step_a.gdb" "$T/s.x")"
  echo "STEP SCRIP_DIAG=$d $STEPW: rt_gc_sw_step_a entered m3=$h3 m4=$h4"
  for h in "$h3" "$h4"; do [ "$h" = UNRESOLVED ] && refuse "gdb could not place a breakpoint on rt_gc_sw_step_a -- the asm step was renamed or deleted; re-cut arm (b) in that landing"; done
  if [ "$d" = 0 ]; then
    [ "$h3" -gt 0 ] || step_red="$step_red m3"
    [ "$h4" -gt 0 ] || step_red="$step_red m4"
  else
    { [ "$h3" = 0 ] && [ "$h4" = 0 ]; } || refuse "the control (SCRIP_DIAG=1, the C walk) entered the asm step (m3=$h3 m4=$h4) -- the counter can no longer tell the two roads apart; re-cut the control"
  fi
done
fast_red=""
for d in 0 1; do
  f3="$(step_hits gc_collect_ex m3 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.gc_collect_ex.gdb" --args "$SCRIP" "$WITDIR/$STEPW")"
  f4="$(step_hits gc_collect_ex m4 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.gc_collect_ex.gdb" "$T/s.x")"
  c3="$(step_hits gc_collect_ex_c m3 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.gc_collect_ex_c.gdb" --args "$SCRIP" "$WITDIR/$STEPW")"
  c4="$(step_hits gc_collect_ex_c m4 "$d" env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB SCRIP_DIAG=$d SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64 gdb -q -batch -x "$T/count.gc_collect_ex_c.gdb" "$T/s.x")"
  echo "FUNNEL SCRIP_DIAG=$d $STEPW: gc_collect_ex entered m3=$f3 m4=$f4, its C instruments road gc_collect_ex_c entered m3=$c3 m4=$c4"
  for h in "$f3" "$f4" "$c3" "$c4"; do [ "$h" = UNRESOLVED ] && refuse "gdb could not place a breakpoint on the collection funnel or its C road -- re-cut arm (c) in the landing that renamed them"; done
  { [ "$f3" -gt 0 ] && [ "$f4" -gt 0 ]; } || refuse "the funnel gc_collect_ex was never entered at SCRIP_DIAG=$d (m3=$f3 m4=$f4) -- the witness collects nothing, so arm (c) measures nothing"
  if [ "$d" = 0 ]; then
    { [ "$c3" = 0 ] && [ "$c4" = 0 ]; } || fast_red="$fast_red m3=$c3,m4=$c4"
  else
    { [ "$c3" -gt 0 ] && [ "$c4" -gt 0 ]; } || refuse "the control (SCRIP_DIAG=1) never took the C instruments road (m3=$c3 m4=$c4) -- the counter can no longer tell the two roads apart; re-cut the control"
  fi
done
nd=0; for x in $declared; do nd=$((nd+1)); done
ns=0; for x in $stale; do ns=$((ns+1)); done
nn=0; for x in $newbad; do nn=$((nn+1)); done
echo "GC-ASM-WALK witnesses=$graded pass_both_modes=$pass_both declared=$nd stale=$ns new=$nn (SCRIP_DIAG=0 SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=64, ^GC- lines dropped)"
[ "$nd" = 0 ] || { echo "  DECLARED (each a line of $(basename "$FLOOR") naming its live row; counted, not silenced):"; for x in $declared; do echo "    $x"; done; }
red=0
if [ "$ns" != 0 ]; then echo "  ⛔ STALE floor line(s) -- the witness passes in both modes, so the line would silence its next regression:"; for x in $stale; do echo "    $x"; done; red=1; fi
if [ "$nn" != 0 ]; then echo "  ⛔ NEW red witness(es) on the asm walk:"; for x in $newbad; do echo "    $x"; done; red=1; fi
if [ -n "$step_red" ]; then echo "  ⛔ the asm step was never entered at SCRIP_DIAG=0 in:$step_red -- the shipped road went ungraded"; red=1; fi
if [ -n "$fast_red" ]; then echo "  ⛔ the asm collection funnel handed a SCRIP_DIAG=0 collection to its C instruments road (gc_collect_ex_c):$fast_red -- the shipped road is not the asm funnel"; red=1; fi
if [ "$red" = 1 ]; then echo "GATE RED [gc_every_witness_passes_on_the_asm_walk]"; exit 1; fi
echo "GATE PASS [gc_every_witness_passes_on_the_asm_walk]: $pass_both of $graded witnesses match their refs in both modes on the road the benchmarks ship, $nd declared on the floor with their rows, and the asm step ran and the asm funnel took every SCRIP_DIAG=0 collection"
exit 0
