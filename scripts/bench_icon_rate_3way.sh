#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_icon_rate_3way.sh — FIXED-TIME RATE comparison: SCRIP m3/m4 vs Arizona iconx vs JCON.
#
# ⭐ WHY FIXED-TIME AND NOT FIXED-ITERATION (Lon, 2026-08-21, in-chat: "flip the tests to loop on a
# fixed time and report iterations, versus looping on a fixed iteration and reporting time").  The
# fixed-iteration form is what this project used before and it is NOT trustworthy on this corpus:
#   (1) its runs are 12-80ms, so PROCESS STARTUP is a large fraction and has to be hand-subtracted;
#   (2) it never lets a JIT warm — it measured JCON cold and reported it ~2.9x behind SCRIP, when a
#       warm JCON is actually AHEAD of SCRIP on 7 of 9 scored benchmarks;
#   (3) at those durations, machine contention swings a single sample by 50%+ (measured: the iconx
#       oracle, an unchanged binary, read 26,560 then 17,312 ops/ms on two consecutive runs).
# Fixed-time fixes all three: each program reads its own &time (so startup is excluded BY
# CONSTRUCTION on every engine), warms untimed, then counts whole UNITs until the budget expires.
# Rate = units * UNIT / ms.  Verified: &time has the same meaning on all three engines (SCRIP 21ms
# internal / 25ms wall; iconx 170/175; JCON 90/162 — the JCON gap is exactly its JVM startup).
#
# ⛔ EVERY RUN ALSO CHECKS CORRECTNESS.  Each program prints a PER-UNIT checksum, which is identical
# on every engine no matter how many units each completed, so rate and cross-engine agreement come
# out of the same run.  ⛔ BUT A MATCHING CHECKSUM DOES NOT PROVE THE WORK HAPPENED: SCRIP CONSTANT-
# FOLDS `"abcdefgh" || "ijklmnop"` in rate_concat_dispatch (measured: ZERO concat calls in its
# emitted .s, against 2 in every other concat benchmark), and the folded constant still has the
# right length.  Audit the emitted asm for the operation under test before trusting any row.
#
# ⛔ RT_OPT: -O0, always -- there is no -O2 arm to build.  Lon's s262 FACT RULE (RULES.md § NO -O2
# BUILDS) makes -O0 the arm for development AND benchmarks AND demos: an -O2 figure grades gcc's
# optimizer over a C runtime being deleted in favour of register-aware ASM.  This header used to
# instruct the opposite (O0-DEV-O2-BENCH) and that instruction is RETIRED -- following it now voids
# the run.  Label every row RT_OPT=-O0; against optimized oracles that understatement is real, known,
# and accepted, never corrected for by rebuilding.
#
# Usage: [REPS=3] [WARM=500] [BUD=1500] bash ../harness/scripts/bench_icon_rate_3way.sh
# Oracles: icont_bin()/iconx_bin() and jcon_path_export() -- all three from lib_oracle_flags.sh, the ONE authority.
# ⛔ RETIRED 2026-09-23 -- see the refusal on the next line; the header below is kept as the record of what this measured.
echo "⛔ RETIRED(2) bench_icon_rate_3way.sh: superseded 2026-09-23 by ../harness/scripts/bench_triangulate_icon.sh (hq_icon, CEO-567 THE KERNEL CONVENTION, CEO-1221). It read timing the KERNEL printed itself -- rate/*.icn self-timed with &time, rtx/*.icn wrote ms: -- and every Icon benchmark is now a pristine kernel with a .ref and no clock in its source; the harness generates the wrapper and times it (fixed iterations, fixed time, tools/bench_rusage)." >&2; exit 2
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root
R="$S4E/SCRIP"; SCRIP=$R/scrip; RT=$R/out
ICONT_BIN="$(icont_bin)" || exit 2
iconx_bin >/dev/null || exit 2
I="$(dirname "$ICONT_BIN")"
export PATH="$I:$PATH"
# ⛔ SCRIP/refs IS DELETED ORG-WIDE (CEO-765) -- this line used to read J=$R/refs/jcon-master/bin, putting a DEAD
# directory on PATH. MEASURED, and it is worse than a blank column: jcont failed silently, jcon timed 0, vs-jcon
# read "-", and the empty jcon checksum made CHECKSUMS print MISMATCH on EVERY ROW while the board still EXITED 0.
# jcon_path_export() is the ONE authority (lib_oracle_flags.sh) and it EXPORTS PATH rather than handing back a
# path, because jcon re-execs BY NAME and resolves its siblings off PATH -- an absolute path alone is not enough.
eval "$(jcon_path_export)" || { echo "REFUSING(2): the jcon rival is unreachable -- this board prints a jcon column and must never print it blank." >&2; exit 2; }
S=${S4E_RATE:-$S4E/corpus/benchmarks/icon/rate}
WARM=${WARM:-500}; BUD=${BUD:-1500}; REPS=${REPS:-3}
LOAD0=$(cut -d" " -f1-3 /proc/loadavg)
W=$(mktemp -d /tmp/rate3_XXXXXX); cd "$W"; cp $S/*.icn .
declare -A UNIT=( [int_loop]=20000 [int_mod]=20000 [concat_dispatch]=20000 [concat_int_dispatch]=20000 \
  [concat_intvar]=20000 [concat_strvar]=20000 [concat_table]=10000 [sub_list]=20000 \
  [sub_table_miss]=20000 [table_semantics]=15000 )
printf "%-22s %12s %12s %12s %12s   %8s %8s   %s\n" BENCHMARK "iconx" "jcon" "SCRIP-m3" "SCRIP-m4" "vs-iconx" "vs-jcon" "CHECKSUMS"
printf -- "---------------------- ------------ ------------ ------------ ------------   -------- --------   ---------\n"
for f in rate_*.icn; do
  n=${f%.icn}; k=${n#rate_}; u=${UNIT[$k]}
  "$I/icont" -s -o "$n.icx" "$f" >/dev/null 2>&1
  jcont -s -o "$n.jx" "$f" >/dev/null 2>&1
  "$SCRIP" --compile "$f" > "$n.s" 2>/dev/null </dev/null
  gcc -no-pie "$n.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -o "$n.bin" 2>/dev/null
  bestrate() { local u=$1; shift; local b=0 r x; for r in $(seq $REPS); do x=$("$@" $WARM $BUD 2>/dev/null </dev/null); x=$(awk -v u=$u '{ if ($2>0) printf "%.0f", ($1*u)/$2; else print 0 }' <<< "$x"); [ "${x:-0}" -gt "$b" ] && b=$x; done; echo $b; }
  onecks()  { "$@" $WARM $BUD 2>/dev/null </dev/null | awk '{print $3}'; }
  ai=$(bestrate $u "$I/iconx" "$n.icx");     ci=$(onecks "$I/iconx" "$n.icx")
  aj=$(bestrate $u ./"$n.jx");               cj=$(onecks ./"$n.jx")
  a3=$(bestrate $u "$SCRIP" --run "$f" --);  c3=$(onecks "$SCRIP" --run "$f" --)
  a4=$(bestrate $u ./"$n.bin");              c4=$(onecks ./"$n.bin")
  if [ "$ci" = "$cj" ] && [ "$ci" = "$c3" ] && [ "$ci" = "$c4" ] && [ -n "$ci" ]; then cs="OK($ci)"; else cs="MISMATCH i=$ci j=$cj m3=$c3 m4=$c4"; fi
  vi=$(awk -v a=$a4 -v b=$ai 'BEGIN{ if(b>0) printf "%.2fx", a/b; else printf "-" }')
  vj=$(awk -v a=$a4 -v b=$aj 'BEGIN{ if(b>0) printf "%.2fx", a/b; else printf "-" }')
  printf "%-22s %12s %12s %12s %12s   %8s %8s   %s\n" "$k" "$ai" "$aj" "$a3" "$a4" "$vi" "$vj" "$cs"
done
echo "(ops/ms, higher is better; BEST of ${REPS}; warm=${WARM}ms budget=${BUD}ms; vs-* compare SCRIP m4)"
echo "load before/after: $LOAD0 / $(cut -d' ' -f1-3 /proc/loadavg)"
echo "workdir: $W"
