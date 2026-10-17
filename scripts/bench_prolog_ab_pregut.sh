#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
# bench_prolog_ab_pregut.sh — PL-REGAIN-0 A/B parity rail (GOAL-PROLOG-BB.md, 2026-07-19).
# Three engines on IDENTICAL era-neutral wrappers: the PRE-GUTTING GZ engine (worktree pinned at
# 7ec7305a, the 2026-06-27 README-table tree; 63c666ba = documented last-green head, differs only by
# 6 SNOBOL4-side commits, Prolog-identical) vs CURRENT HEAD vs gprolog.
# Method (FINDING-2026-07-19-CLAUDE-PL-PREGUT-AB-OLD-ENGINE-7-27X-FASTER-MECHANISMS.md):
#   - failure-driven fact-table loop: l__ :- <conj of a/1,b/1 enumerations>, bench__main, fail.
#     (era-neutral: the GZ engine FENCES between/3; full solution enumeration per iteration,
#      identical work on every engine — the PL-SPEED-0 rail's own no-once method)
#   - N composed from a(1..8) x b(1..64) conjuncts: 8/64/512/4096/32768/262144
#   - GC_INITIAL_HEAP_SIZE=1G for the OLD engine per its README's own "pre-sized GC heap" method
#     note (unpresized fib measured 15x worse — collection storms, see FINDING)
#   - lpi column = output lines / N: catches silent truncation (the rail's banked abort-blindness)
#   - single run per cell; at these ratios +/-10-20% host noise is immaterial
# Env: PREGUT_REF (default 7ec7305a) PREGUT_DIR (default <root>/SCRIP-pregut)
#      BENCH_K (default <root>/corpus/benchmarks/prolog/bench -- the PRISTINE kernels)
#
# ⛔⭐ IT READS THE PRISTINE KERNELS NOW, NOT THE RETIRED vanroy/ (hq_P 2026-09-13, CEO-567). This rail never wanted the
#   checked-in wrapped form: mkwrap() below opened corpus/benchmarks/prolog/vanroy/<k>.pl only to STRIP the three generated
#   loop lines back off it (`main :- l__(N).`, `l__(N__) :- between...`, `l__(_).`) and recover the bare kernel, then wrapped
#   it in this rail's OWN era-neutral fact-table loop. So it was reading a derived artifact to undo the derivation. vanroy/ is
#   retired (its N values now live in fixed-iter-n.tsv, its wrapped form is generated on demand); the pristine kernel this rail
#   always wanted IS corpus/benchmarks/prolog/bench/<k>.pl, and mkwrap() now strips one line from it instead of three.
#   ⛔ THE CONTRACT PREDICATE CHANGED WITH THE CONVERSION and the rail must follow it: the work used to be reachable as
#   bench__main/0 (the generator's rename of the kernel's own main/0); in the pristine contract it is bench_work/1, and the
#   timing bracket and the write are no longer inside it. This rail brackets from OUTSIDE and discards the result, so calling
#   bench_work(_) is the faithful translation -- but it is a DIFFERENT CALL, so no number from before this change may be
#   compared against one from after it without re-measuring both arms.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; NEW="$(cd "$HERE/../../SCRIP" && pwd)"
PREGUT_REF="${PREGUT_REF:-7ec7305a}"; OLD="${PREGUT_DIR:-$S4E/SCRIP-pregut}"
K="${BENCH_K:-$S4E/corpus/benchmarks/prolog/bench}"
W=/tmp/ab_pregut.$$; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT
gprolog_bin >/dev/null || exit 2
[ -d "$K" ] || { echo "⛔ REFUSED-TO-GRADE: pristine kernel dir missing: $K"; exit 2; }
if [ ! -d "$OLD" ]; then (cd "$NEW" && git worktree add "$OLD" "$PREGUT_REF") || { echo "FAIL worktree"; exit 1; }; fi
[ -x "$OLD/scrip" ] || (cd "$OLD" && make -j4 scrip >/tmp/ab_build_old.log 2>&1) || { echo "FAIL old build (see /tmp/ab_build_old.log)"; exit 1; }
[ -f "$OLD/out/libscrip_rt.so" ] || (cd "$OLD" && make libscrip_rt >>/tmp/ab_build_old.log 2>&1) || { echo "FAIL old rt"; exit 1; }
[ -x "$NEW/scrip" ] || (cd "$NEW" && make -j4 scrip >/tmp/ab_build_new.log 2>&1) || { echo "FAIL new build"; exit 1; }
[ -f "$NEW/out/libscrip_rt.so" ] || (cd "$NEW" && make libscrip_rt >>/tmp/ab_build_new.log 2>&1) || { echo "FAIL new rt"; exit 1; }
conj(){ case $1 in 8)echo "a(_), ";;64)echo "b(_), ";;512)echo "a(_), b(_), ";;4096)echo "b(_), b(_), ";;32768)echo "a(_), b(_), b(_), ";;262144)echo "b(_), b(_), b(_), ";;esac; }
mkwrap(){ p=$1; n=$2; f="$W/${p}_${n}.pl"
  # ⛔ REFUSE rather than wrap a kernel that does not carry the contract -- a silently unwrapped source would compile,
  # run its own main/0 once, and be reported as a fast iteration rate (the loop-never-looped class, lib_prolog_bench.sh).
  grep -q '^bench_work(' "$K/$p.pl" || { echo "⛔ REFUSED-TO-GRADE: $K/$p.pl carries no bench_work/1 -- not a pristine kernel (CEO-567)" >&2; exit 2; }
  grep -vE '^main :- ' "$K/$p.pl" > "$f"
  for i in $(seq 1 8); do echo "a($i)."; done >> "$f"
  for i in $(seq 1 64); do echo "b($i)."; done >> "$f"
  printf 'main :- l__.\nl__ :- %sbench_work(_), fail.\nl__.\n' "$(conj $n)" >> "$f"; echo "$f"; }
tdiff(){ echo $(( ($2 - $1) / 1000000 )); }
build_m4(){ d=$1; f=$2; b=$3; xl=$4
  (cd "$W" && timeout -k 5 90 "$d/scrip" --compile --target=x86 "$f" </dev/null 2>"$b.err" > "$b.s") || { echo BUILDFAIL; return 1; }
  grep -q 'PL-GZ FENCE' "$b.err" && { echo FENCE; return 1; }
  (cd "$W" && as --64 -o "$b.o" "$b.s" 2>>"$b.err" && gcc -no-pie -o "$b" "$b.o" "$d/out/libscrip_rt.so" $xl -lm -lstdc++ -Wl,-rpath,"$d/out" 2>>"$b.err") || { echo LINKFAIL; return 1; }; return 0; }
run1(){ o="$W/out.$$"; t0=$(date +%s%N); timeout -k 5 90 "$@" </dev/null >"$o" 2>/dev/null; rc=$?; t1=$(date +%s%N)
  if [ $rc -eq 0 ]; then echo "$(tdiff $t0 $t1) $(wc -l < "$o")"; else echo "DNF$rc 0"; fi; rm -f "$o"; }
Ns="fib:512:64:64 tak:64:64:8 qsort:32768:4096:512 nrev:32768:4096:512 deriv:262144:32768:4096 queens_8:512:512:64"
getN(){ for e in $Ns; do case "$e" in $1:*) IFS=: read -r _ g o n <<<"$e"; case "$2" in gnu)echo $g;;old)echo $o;;new)echo $n;;esac;;esac; done; }
printf "%-9s | %9s %7s %4s | %9s %7s %4s | %9s %7s %4s\n" PROG GNUms/it N lpi OLDms/it N lpi NEWms/it N lpi
for p in fib tak qsort nrev deriv queens_8; do
  gn=$(getN $p gnu); on=$(getN $p old); nn=$(getN $p new)
  fg=$(mkwrap $p $gn); read gt gl <<<"$(run1 "$(gprolog_bin)" --consult-file "$fg" --query-goal halt)"
  case $gt in DNF*) gms=$gt; glpi=-;; *) gms=$(echo "scale=3;$gt/$gn"|bc); glpi=$(echo "scale=1;$gl/$gn"|bc);; esac
  fo=$(mkwrap $p $on); bo="$W/${p}_old"
  if build_m4 "$OLD" "$fo" "$bo" "-lgc" >/dev/null; then
    read ot ol <<<"$(GC_INITIAL_HEAP_SIZE=1073741824 run1 "$bo")"
    case $ot in DNF*) oms=$ot; olpi=-;; *) oms=$(echo "scale=3;$ot/$on"|bc); olpi=$(echo "scale=1;$ol/$on"|bc);; esac
  else oms=$(build_m4 "$OLD" "$fo" "$bo" "-lgc"); olpi=-; fi
  fn=$(mkwrap $p $nn); bn="$W/${p}_new"
  if build_m4 "$NEW" "$fn" "$bn" "" >/dev/null; then
    read nt nl <<<"$(run1 "$bn")"
    case $nt in DNF*) nms=$nt; nlpi=-;; *) nms=$(echo "scale=3;$nt/$nn"|bc); nlpi=$(echo "scale=1;$nl/$nn"|bc);; esac
  else nms=$(build_m4 "$NEW" "$fn" "$bn" ""); nlpi=-; fi
  printf "%-9s | %9s %7s %4s | %9s %7s %4s | %9s %7s %4s\n" "$p" "$gms" "$gn" "$glpi" "$oms" "$on" "$olpi" "$nms" "$nn" "$nlpi"
done
echo "ENGINES: OLD=$PREGUT_REF (pre-GZ#5)  NEW=$(cd "$NEW" && git rev-parse --short HEAD)  GNU=$("$(gprolog_bin)" --version </dev/null 2>&1 | head -1)"
