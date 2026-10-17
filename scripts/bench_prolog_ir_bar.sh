#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_ir_bar.sh -- THE LOAD-IMMUNE BAR FOR ONE PROLOG KERNEL: SCRIP mode-4 WORK (callgrind Ir per iteration of the bar's
# own angle-1 loop) against the rival's WORK on the SAME twin, and the multiple rival/SCRIP. Ruled CEO-1315 (Lon 2026-09-27, in-chat
# to hq_prolog, verbatim: "Yes, you are correct to use instruction counts. That is good enough."): a prolog-speed row may close on
# this reading, with the wall-clock bench_prolog_bar.sh reading reported beside it, self-stamping its load (CEO-743).
#   usage: bench_prolog_ir_bar.sh kernel K [gplc|gnu|swi] [BAR]     K = the kernel's file stem under corpus/benchmarks/prolog/bench
#          rival gplc (default; GNU Prolog compiled native, --no-top-level), gnu ("$(gprolog_bin)" --consult-file, the byte-code WAM) or swi.
#          BAR (default 1.0): exits 0 when rival WORK / SCRIP m4 WORK >= BAR (SCRIP retires no more instructions per iteration than
#          BAR times the rival's), 1 when below it, 2 when it could not measure (no valgrind, no rival, a twin that did not build,
#          a run that died -- an Ir from a run that died is not a measurement, lib_ir_measure.sh).
# THE TWO NUMBERS ARE NEVER SUBTRACTED ACROSS (bench_prolog_ir_slope.sh): WORK is the slope Ir(2n)-Ir(n) over n, startup cancelled
# exactly; the intercept is the engine's own startup and is not this bar's business. Linearity: slope(n,2n) vs slope(2n,4n) within
# LIN_TOL percent, else the reading says NONLINEAR and the bar refuses (rc 2) rather than grade a curve as a line.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
refuse() { echo "REFUSE(2) bench_prolog_ir_bar: $*" >&2; exit 2; }
[ "${1:-}" = kernel ] && [ -n "${2:-}" ] || refuse "usage: bench_prolog_ir_bar.sh kernel K [gplc|gnu|swi] [BAR]"
K="$2"; RIVAL="${3:-gplc}"; BAR="${4:-1.0}"; LIN_TOL="${LIN_TOL:-2}"; TARGET_IR="${TARGET_IR:-60000000}"
case "$RIVAL" in gplc|gnu|swi) ;; *) refuse "rival must be gplc, gnu or swi";; esac
SRC="$S4E/corpus/benchmarks/prolog/bench/$K.pl"; [ -f "$SRC" ] || refuse "no kernel $SRC"
SCRIP_BIN="${SCRIP:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"; [ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN"
. "$HERE/lib_ir_measure.sh" 2>/dev/null || refuse "cannot load lib_ir_measure.sh"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh"
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || refuse "cannot load lib_perf_fmt.sh -- the one authority for printing a multiple"
ir_have_valgrind || refuse "valgrind/callgrind_annotate absent"
case "$RIVAL" in
  gplc) GPLC="${GPLC:-$(gplc_bin 2>/dev/null)}"; [ -x "${GPLC:-/nonexistent}" ] || refuse "gplc absent (GNU Prolog's native compiler; test_bench_prolog_timed.sh refuses without it too)";;
  gnu)  GNU="$(gprolog_bin)" || refuse "gprolog oracle absent";;
  swi)  SWI="$(swipl_bin)" || refuse "swipl oracle absent";;
esac
W="$(mktemp -d "${TMPDIR:-/tmp}/irbar.XXXXXX")" || refuse "no workdir"; trap 'rm -rf "$W"' EXIT
DECL=""; if [ -f "$HERE/lib_declared_arena.sh" ]; then . "$HERE/lib_declared_arena.sh" 2>/dev/null && DECL="$(declared_switches_beside "$SRC" 2>/dev/null || true)"; fi
twin() { local n="$1" eng="$2"; local o="$W/k_${eng}_$n.pl"; bash "$HERE/bench_prolog_wrap.sh" "$SRC" -o "$o" --mode=iter --n="$n" --engine="$eng" >/dev/null 2>&1 && [ -s "$o" ] && echo "$o"; }
ir_num() { local v; v="$(ir_measure "$@")"; ir_is_number "$v" && echo "$v"; }
ir_m4() { local f="$1" d; d="$(mktemp -d "$W/m4.XXXXXX")"; "$SCRIP_BIN" --compile "$f" -o "$d/p.s" < /dev/null >/dev/null 2>&1 || return 0
  gcc -no-pie "$d/p.s" -o "$d/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread >/dev/null 2>&1 || return 0; ir_num "$d/p.bin" $DECL < /dev/null; }
ir_rival() { local f="$1" d; case "$RIVAL" in
  gplc) d="$(mktemp -d "$W/gplc.XXXXXX")"; (cd "$d" && timeout -k 5 300 "$GPLC" --no-top-level -o "$d/p.bin" "$f" >/dev/null 2>&1) && [ -x "$d/p.bin" ] || return 0; ir_num "$d/p.bin" < /dev/null;;
  gnu)  ir_num "$GNU" --quiet --consult-file "$f" < /dev/null;;
  swi)  ir_num "$SWI" -q -f "$f" -t halt < /dev/null;; esac; }
slope() { awk -v a="$1" -v b="$2" -v c="$3" -v n="$4" -v tol="$LIN_TOL" 'BEGIN{ s1=(b-a)/n; s2=(c-b)/(2*n); if (s1<=0||s2<=0) { print "0 NONLINEAR"; exit }
  d=(s1>s2?(s1-s2)/s2:(s2-s1)/s1)*100; printf "%d %s", s2, (d<=tol?"ok":"NONLINEAR") }'; }
pa="$(twin 4 scrip)"; pb="$(twin 12 scrip)"; n1="${BASE_N:-40}"
if [ -n "$pa" ] && [ -n "$pb" ]; then a="$(ir_m4 "$pa")"; b="$(ir_m4 "$pb")"
  [ -n "$a" ] && [ -n "$b" ] && n1="$(awk -v a="$a" -v b="$b" -v tgt="$TARGET_IR" -v dflt="$n1" 'BEGIN{ s=(b-a)/8; if (s<=0) { print dflt; exit } n=int(tgt/s); if (n<8) n=8; if (n>2000000) n=2000000; print n }')"; fi
n2=$((n1*2)); n3=$((n1*4)); reng=gnu; [ "$RIVAL" = swi ] && reng=swi
m1="$(twin "$n1" scrip)"; m2="$(twin "$n2" scrip)"; m3="$(twin "$n3" scrip)"; r1="$(twin "$n1" "$reng")"; r2="$(twin "$n2" "$reng")"; r3="$(twin "$n3" "$reng")"
[ -n "$m1" ] && [ -n "$m2" ] && [ -n "$m3" ] && [ -n "$r1" ] && [ -n "$r2" ] && [ -n "$r3" ] || refuse "a twin of $K did not build (scrip or $reng arm)"
ma="$(ir_m4 "$m1")"; mb="$(ir_m4 "$m2")"; mc="$(ir_m4 "$m3")"; [ -n "$ma" ] && [ -n "$mb" ] && [ -n "$mc" ] || refuse "SCRIP m4 run of $K died or did not link under callgrind"
ra="$(ir_rival "$r1")"; rb="$(ir_rival "$r2")"; rc_="$(ir_rival "$r3")"; [ -n "$ra" ] && [ -n "$rb" ] && [ -n "$rc_" ] || refuse "$RIVAL run of $K died under callgrind"
read -r mw ml <<<"$(slope "$ma" "$mb" "$mc" "$n1")"; read -r rw rl <<<"$(slope "$ra" "$rb" "$rc_" "$n1")"
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
[ "$ml" = ok ] && [ "$rl" = ok ] || { echo "IR_BAR kernel=$K rival=$RIVAL m4 WORK=$mw ($ml) $RIVAL WORK=$rw ($rl) N=$n1 tree=SCRIP $TREE -- NONLINEAR, not graded"; exit 2; }
mult="$(perf_mult "$rw" "$mw" "kernel $K: $RIVAL WORK over SCRIP m4 WORK")" || refuse "perf_mult refused the cell (rival WORK=$rw, m4 WORK=$mw)"
ok="$(awk -v r="$rw" -v m="$mw" -v bar="$BAR" 'BEGIN{ print (r / m >= bar + 0) ? 1 : 0 }')"
echo "IR_BAR kernel=$K rival=$RIVAL bar=$BAR multiple=$mult m4 WORK=$mw Ir/iter $RIVAL WORK=$rw Ir/iter N=$n1 tree=SCRIP $TREE (Ir is load-immune: instructions retired, not cycles; CEO-743 binds wall-clock numbers only) $([ "$ok" = 1 ] && echo AT-OR-ABOVE-BAR || echo BELOW-BAR)"
[ "$ok" = 1 ]
