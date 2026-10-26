#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_bench_snobol4_timed.sh -- run the TIME-BASED SNOBOL4 benchmark family and
# report THROUGHPUT (iterations per second) for sbl / scrip m3 / scrip m4.
#
# The legacy runner (test_bench_snobol4_modes.sh) reports wall(ms) for a fixed
# iteration count.  This one reports iterations for a fixed time budget, so:
#   * the numbers are directly comparable ACROSS engines (a ratio, not a delta);
#   * the suite's wall cost is bounded by construction (budget x programs x engines);
#   * a resolution-starved reading ("10 ms") cannot happen -- the elapsed window
#     is always ~BUDGET ms regardless of how fast the engine is.
# CORRECTNESS is gated here by CROSS-ENGINE AGREEMENT on the phase-1 "check:" line (sbl anchors it
# when sbl is among $ENGINES -- an absolute grade per RULES.md); a missing .ref is reported (/NO-REF)
# but its CONTENT is not diffed here. Only the measurement lines (iters:/ms:) are stripped before
# any comparison. STALE-COMMENT FIX (row bench-triangulation-3angle item 5, seat09 2026-08-27): this
# used to say ".ref diffed" -- true pre-s265, false since. The .ref itself is minted/graded
# separately by ../harness/scripts/util_mint_bench_refs.sh (see this file's own :171 note for why).
# ⛔ row bench-external-cpu-and-elapsed-clock: sbl/s, m3/s, m4/s are the ITERATION COUNT divided by
# tools/bench_rusage's EXTERNAL cpu(user+sys) time for the winning rep, not the engine's own
# self-reported "ms:" line -- self-timing is never again the cross-engine authority (FINDING-2026-08-22-s253).
#
# ⛔ THE NOISE FLOOR IS NOT GLOBAL.  It is a property of the (KERNEL, ENGINE,
# THP-arm) triple and is BAKED PER ROW in NOISE-FLOOR.tsv beside this corpus by
# ../harness/scripts/bake_noise_floor_snobol4_timed.sh.  Measured range: 0.2% .. 34.6% cv.
# An earlier draft of this file carried a single global "~4%" constant derived
# from one kernel (arith_loop); that is the s148 instrument error in new
# clothes and it is deleted.  The runner prints each row's min-detectable
# difference; a delta smaller than that is WEATHER, not a regression.
# ⛔ row bench-external-cpu-and-elapsed-clock (FINDING-2026-08-22-s253): min-det below reads
# NOISE-FLOOR.tsv's external-instrument columns (tools/bench_rusage, cpu = user+sys, elapsed =
# CLOCK_MONOTONIC, both outside either engine) -- NOT the self-timed TIME() column, which the two
# engines never measured in the same unit (SPITBOL CPU-time-patched, SCRIP wall-clock).  min-det(cpu)
# is the cross-engine authority; min-det(elap) prints alongside so the two are readable BY NAME.
#
# ⛔ MEASUREMENT CONDITION: SCRIP engines run with SCRIP_NOHUGE=1 by DEFAULT.
# Transparent huge pages make every allocating row unmeasurable in the shipping
# arm (table_access_t m3: cv 26.9%, min-detectable 80.7% -- you cannot see a 2x
# regression) AND cost throughput outright (2675/s -> 6042/s, 2.26x, with THP
# off).  Set NOHUGE=0 to reproduce the shipping-arm instability.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"  # BM-ONE (s153): timed family PROMOTED -- one copy, legacy retired, harness.inc is the driver
T="${TIMEOUT:-60}"; REPS="${REPS:-1}"; NOHUGE="${NOHUGE:-1}"
# ⛔ THE TWIN IS bench_wrap_snobol4.py's (ceo CEO-1984, Lon 2026-10-25: "Fix the S4 triangulation script since it is broken, duh!"): the kernels are
# PRISTINE since the kernel convention (CEO-1221/1267) and carry no `*BENCH kernel=... check=...` line, so bench_wrap.sh refused all 23 and this
# angle measured nothing. The one generator test_snobol4_bench_suite.sh uses writes the fixed-time twin (--mode time --bud-ms BUD_MS), whose
# stdout is the kernel's own output (the .ref) and whose TERMINAL line `BENCH mode=time ... iters=N ... mismatched=M value=V` carries the count
# and the check. BENCH_BUD_MS is the suite runner's own knob, 500 ms by default.
BUD_MS="${BENCH_BUD_MS:-500}"
# ⛔ GC-FREE WINDOW IS A MEASUREMENT PRECONDITION, NOT A TUNING KNOB (BM-3).  SCRIP's collector is
# EXHAUSTION-TRIGGERED (gc_heap.c: rt_gcheap_alloc collects only when the arena is full) and its cost
# scales with EVERY BLOCK EVER ALLOCATED, not with the live set: one measured regeneration walked
# 7,352,520 blocks to retain 1,548 and cost ~835 ms.  At the 512 MB default arena that single pause
# lands inside a 500 ms budget on the allocating rows and IS the reported number -- table_access read
# 0.23x of the oracle with the stall and 0.46x without, array_sum 0.34x -> 0.97x.  A benchmark window
# containing a collection is not a throughput reading, so the arena is sized past the window's total
# allocation and the regeneration count is COUNTED AND PRINTED per row: gc>0 marks the row untrusted
# rather than silently averaging a stall into it.  The oracle needs no equivalent (measured: sbl is
# insensitive to -d1024m on both allocating rows), so this equalises the condition, it does not favour.
# ⛔ SUPERSEDED 2026-09-28 (Lon, ceo CEO-1353, RULES.md hard-cap clause 8 (g)(4)): the 1 GB SCRIP_HEAP_MB window above is GONE -- a runner
# types no size of its own and never sets the collector's WINDOW. Each unit runs at the heap and stack declared beside it (<stem>.heap,
# <stem>.stack, read by lib_declared_arena.sh), in m3, in the m4 binary and on sbl alike; a collection inside the window is COUNTED
# (the gc column), never engineered away. An undeclared unit is named SIZE-UNDECLARED, not run at a default it did not ask for.
# -s16m: the json deserializer's recursive descent overflows the oracle's DEFAULT stack (ERROR 246)
# once its match runs inside ZBODY's frame.  Harmless to every other row; sizing a stack is not a
# throughput knob.  Larger values are refused by this container ("Stack memory unavailable").
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200). A private fallback would time a DIFFERENT LANGUAGE (s189: -bf is the only correct arm). Fix the checkout; do not work around this." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"   # BENCHMARK oracle (s255): x64/bin/sbl carries a monitor-IPC bridge that costs ~2.2-3.5x instructions -- timing must never use it
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_declared_arena.sh unloadable -- the one reader of a unit's declared heap and stack (CEO-1353)"; exit 2; }
FLOORTSV="${FLOORTSV:-$B/NOISE-FLOOR.tsv}"
ENGINES="${ENGINES:-sbl m3 m4}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -d "$B" ]     || { echo "⛔ REFUSED-TO-GRADE timed bench corpus missing ($B)"; exit 2; }
# row bench-external-cpu-and-elapsed-clock: every run below is forked through tools/bench_rusage --
# the sbl/s, m3/s, m4/s rates ARE the external cpu(user+sys) instrument now, not self-timed TIME().
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "FAIL build $WRAP" >&2; exit 1; }
NIVCSW_FLAG="${BENCH_NIVCSW_THRESHOLD:-20}"   # same knob/default as the other bench_rusage call sites
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
rate() { awk -v i="$1" -v m="$2" 'BEGIN{ if(m+0>0) printf "%.0f", i/m*1000; else printf "NA" }'; }
human() { awk -v v="$1" 'BEGIN{ if(v=="NA"){print "NA"; exit}
  if(v>=1e9) printf "%.2fG", v/1e9; else if(v>=1e6) printf "%.1fM", v/1e6;
  else if(v>=1e3) printf "%.1fK", v/1e3; else printf "%d", v }'; }
# ---- one measured run; echoes "iters cpu_ms nivcsw gc check" --------------
run1() {
  local eng="$1" sno="$2" run="${3:-$2}" s in; s=$(basename "${sno%.sno}")
  # DATA-DRIVEN ROWS (BM-4): a workload benchmark is fed its corpus on stdin from a sibling
  # <family>.dat, family = the program name minus any -match/-match-fence suffix, so the three
  # variants of one grammar provably read the SAME bytes.  Microbenchmarks have no .dat and keep
  # /dev/null -- a program that expects input and finds none must not silently "pass" on empty.
  in="$(dirname "$sno")/$(sed 's/-match\(-fence\)\?$//' <<<"$s").dat"; [ -f "$in" ] || in=/dev/null
  local sw; sw="$(declared_switches_beside "$sno")" || { echo "- - - - SIZE-REFUSED"; return; }
  [ -n "$sw" ] || { echo "- - - - SIZE-UNDECLARED"; return; }
  case "$eng" in
    sbl) [ -x "$SBL" ] || { echo "- - - - ORACLE-MISSING"; return; }
         out=$("$WRAP" timeout -k 5 "$T" "$SBL" $(sbl_lang_flags) $sw "$run" 2>"$W/gc.err" <"$in") ;;
    m3)  out=$(SCRIP_NOHUGE="$NOHUGE" SCRIP_ZETA_TELEM=1 "$WRAP" timeout -k 5 "$T" "$SCRIP" $sw --run "$run" 2>"$W/gc.err" <"$in") ;;
    m4)  "$SCRIP" --compile "$run" > "$W/$s.s" 2>/dev/null
         if [ ! -s "$W/$s.s" ] || ! gcc -no-pie "$W/$s.s" -L"$RT" -lscrip_rt -lm \
              -Wl,-rpath,"$RT" -o "$W/$s.prog" 2>/dev/null; then echo "- - - - BUILD-ERR"; return; fi
         out=$(cd "$W" && SCRIP_NOHUGE="$NOHUGE" SCRIP_ZETA_TELEM=1 "$WRAP" timeout -k 5 "$T" "./$s.prog" $sw 2>"$W/gc.err" <"$in") ;;
  esac
  local it ck gc rusage_line user_us sys_us nivcsw cpu_ms
  it=$(sed -n 's/^BENCH mode=time .* iters=\([0-9][0-9]*\) .*/\1/p' "$W/gc.err" | tail -1)
  ck=$(sed -n 's/^BENCH mode=time .* mismatched=0 value=//p' "$W/gc.err" | tail -1)
  local ref="${sno%.sno}.ref"; [ -n "$ck" ] && [ -f "$ref" ] && [ "$out" != "$(cat "$ref")" ] && ck="REF-DIFF:$ck"
  gc=$(grep -c 'regeneration #' "$W/gc.err" 2>/dev/null); gc="${gc:-0}"
  [ -n "$it" ] || { echo "- - - - CRASH"; return; }
  # gc.err carries BOTH the engine's own stderr (regeneration lines, counted above) and bench_rusage's
  # own BENCH_RUSAGE report (its stderr is the same fd the forked child inherits) -- one capture, two reads.
  rusage_line=$(grep '^BENCH_RUSAGE:' "$W/gc.err" | tail -1)
  user_us=$(echo "$rusage_line" | grep -oE 'user_us=[0-9]+' | cut -d= -f2)
  sys_us=$(echo "$rusage_line" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
  nivcsw=$(echo "$rusage_line" | grep -oE 'nivcsw=[0-9]+' | cut -d= -f2); nivcsw="${nivcsw:-0}"
  cpu_ms=$(awk -v u="${user_us:-0}" -v y="${sys_us:-0}" 'BEGIN{printf "%.1f", (u+y)/1000}')
  echo "$it $cpu_ms $nivcsw $gc ${ck:-NOCHECK}"
}
# ---- best of REPS (max throughput = least interference) --------------------
best() {
  local eng="$1" sno="$2" run="${3:-$2}" bi=0 bm=0 bn=0 bg=0 ck="" r i m n g c
  for _ in $(seq 1 "$REPS"); do
    r=$(run1 "$eng" "$sno" "$run"); i=$(awk '{print $1}' <<<"$r"); m=$(awk '{print $2}' <<<"$r")
    n=$(awk '{print $3}' <<<"$r"); g=$(awk '{print $4}' <<<"$r"); c=$(cut -d' ' -f5- <<<"$r")
    [ "$i" = "-" ] && { echo "- - - - $c"; return; }
    ck="$c"
    # the reported rep is the fastest one (by the SAME external cpu(ms) this now selects AND reports
    # with, row bench-external-cpu-and-elapsed-clock); its OWN gc/nivcsw travel with it, so a printed
    # rate and its gc flag always describe the same run (a suite-wide max would mark clean rows dirty)
    if [ "$(awk -v a="$i" -v b="$m" -v x="$bi" -v y="$bm" 'BEGIN{print (b>0 && (y<=0 || a/b > x/y))?1:0}')" = 1 ]; then bi=$i; bm=$m; bn=$n; bg=$g; fi
  done
  echo "$bi $bm $bn $bg $ck"
}
echo "TIME-BASED SNOBOL4 BENCHMARKS -- fixed time budget, iterations counted"
echo "engines: $ENGINES   reps: $REPS   corpus: $B"
echo "measurement condition: SCRIP_NOHUGE=$NOHUGE  heap and stack: each unit's declared .heap/.stack, the same switches to m3, m4 and sbl (CEO-1353)"
if [ -f "$FLOORTSV" ]; then echo "noise floor: $FLOORTSV (per-row; min-det = 3*cv; cpu = external authority, elap = external alongside)"
else echo "noise floor: NOT BAKED -- run ../harness/scripts/bake_noise_floor_snobol4_timed.sh"; fi
echo
printf "%-20s %12s %12s %12s   %8s %8s %5s %7s %12s %12s  %s\n" BENCHMARK "sbl/s" "m3/s" "m4/s" "m3:sbl" "m4:m3" "gc" "nivcsw" "min-det(cpu)" "min-det(elap)" "check"
printf "%-20s %12s %12s %12s   %8s %8s %5s %7s %12s %12s  %s\n" "--------------------" "------------" "------------" "------------" "--------" "--------" "-----" "-------" "------------" "------------" "-----"
tot_ok=0; tot_bad=0; tot_gc=0; tot_xf=0; tot_xp=0; tot_load=0; UNGRADED=""; XPASSED=""
for sno in "$B"/*.sno; do
  [ -e "$sno" ] || continue
  # ⛔ UNGRADED IS PRINTED BY NAME, NEVER SILENTLY SKIPPED (owed since s158, landed s170).
  # The guard grades only harness-driven programs, so a skipped program is INVISIBLE in the table
  # above -- which is how 12 legacy-shaped programs sat in this directory reading as "not measured"
  # and as "nothing to see". Its NAME now goes to the census under the summary. BM-2 finished s170:
  # the list is EMPTY, the suite FAILS if it ever is not, and that is the end state made mechanical.
  s=$(basename "${sno%.sno}"); ref="${sno%.sno}.ref"
  # ⭐ s265 STANDALONE REVAMP: the .sno is the APPLICATION now, not the wrapper.  What makes a program
  # timeable is its *BENCH marker, and the timed twin is BUILT HERE, on the fly, into $W.  The old gate
  # asked "does it include harness.inc" -- which after the revamp is false for every program in the
  # corpus, so the whole suite would have read as UNGRADED rather than failing loudly.
  if ! TWIN=$(python3 "$HERE/bench_wrap_snobol4.py" "$sno" --mode time --bud-ms "$BUD_MS" -o "$W/$s.bench.sno" 2>&1); then
    UNGRADED="$UNGRADED $s"; echo "  ⛔ $s: $TWIN" >&2; continue; fi
  TWIN="$W/$s.bench.sno"
  declare -A R=(); declare -A C=(); declare -A G=(); declare -A N=()
  for eng in $ENGINES; do
    res=$(best "$eng" "$sno" "$TWIN")
    i=$(awk '{print $1}' <<<"$res"); m=$(awk '{print $2}' <<<"$res")
    N[$eng]=$(awk '{print $3}' <<<"$res"); G[$eng]=$(awk '{print $4}' <<<"$res"); c=$(cut -d' ' -f5- <<<"$res")
    if [ "$i" = "-" ]; then R[$eng]="NA"; C[$eng]="$c"; else R[$eng]=$(rate "$i" "$m"); C[$eng]="$c"; fi
  done
  # a CRASHed/BUILD-ERR row reports "-" for its gc/nivcsw fields; coerce to 0 so one dead row cannot abort the board
  g3="${G[m3]:-0}"; g4="${G[m4]:-0}"
  case "$g3" in ''|*[!0-9]*) g3=0 ;; esac
  case "$g4" in ''|*[!0-9]*) g4=0 ;; esac
  gcn=$(( g3 + g4 )); [ "$gcn" -gt 0 ] && tot_gc=$((tot_gc+1))
  # row bench-external-cpu-and-elapsed-clock, DONE-WHEN item 2: nivcsw reported per row, worst of the
  # engines measured -- a row above the threshold is a candidate to re-measure, not silently trusted.
  nmax=0
  for eng in $ENGINES; do
    nv="${N[$eng]:-0}"; case "$nv" in ''|*[!0-9]*) nv=0 ;; esac
    [ "$nv" -gt "$nmax" ] && nmax=$nv
  done
  nivstr="$nmax"; if [ "$nmax" -gt "$NIVCSW_FLAG" ]; then nivstr="${nmax}!"; tot_load=$((tot_load+1)); fi
  # correctness: all engines must agree on the check line, and match the .ref
  ckstat="ok"; base=""
  for eng in $ENGINES; do
    [ "${C[$eng]}" = "CRASH" ] || [ "${C[$eng]}" = "BUILD-ERR" ] && { ckstat="${C[$eng]}"; break; }
    [ -z "$base" ] && base="${C[$eng]}"
    [ "${C[$eng]}" = "$base" ] || ckstat="DISAGREE"
  done
  # ⛔ THE .ref IS NO LONGER A CHECK PIN.  Since s265 it holds the STANDALONE program's real output and
  # is graded by ../harness/scripts/util_mint_bench_refs.sh and the scorecard, not here.  What anchors the check
  # line HERE is the ORACLE ITSELF: sbl is one of the engines, so "every engine agrees" already means
  # "every engine agrees with sbl" -- an absolute grade, by RULES.md's own authority.  When sbl is not
  # in ENGINES there is no anchor and the row says so rather than reading as verified.
  case " $ENGINES " in *" sbl "*) : ;; *) [ "$ckstat" = ok ] && ckstat="ok(x-eng)" ;; esac
  [ -f "$ref" ] || ckstat="${ckstat}/NO-REF"
  # XFAIL LANE -- the corpus-wide convention (CORPUS-LOCATIONS.md): a sibling .xfail marks
  # known-unimplemented territory and is counted XFAIL, not FAIL. A row that PASSES with a marker
  # present is an XPASS: printed loudly below so a stale marker cannot mask a later regression,
  # but it never reddens the suite -- a defect getting fixed is not a suite failure.
  if [ -f "${sno%.sno}.xfail" ]; then
    if [ "$ckstat" = ok ]; then ckstat=XPASS; tot_xp=$((tot_xp+1)); XPASSED="$XPASSED $s"
    else ckstat="XFAIL:$ckstat"; tot_xf=$((tot_xf+1)); fi
  elif [ "$ckstat" = ok ]; then tot_ok=$((tot_ok+1))
  else tot_bad=$((tot_bad+1)); fi
  sp3=$(awk -v a="${R[m3]:-NA}" -v b="${R[sbl]:-NA}" 'BEGIN{ if(a=="NA"||b=="NA"||b+0==0){print "-"} else printf "%.2fx", a/b }')
  sp4=$(awk -v a="${R[m4]:-NA}" -v b="${R[m3]:-NA}" 'BEGIN{ if(a=="NA"||b=="NA"||b+0==0){print "-"} else printf "%.2fx", a/b }')
  # columns 17/14 of NOISE-FLOOR.tsv (min_detectable_cpu_pct / min_detectable_elapsed_pct) -- see the
  # header note above; column 8 (self-timed) is still in the file for continuity but is not read here.
  md_cpu="-"; md_elap="-"
  if [ -f "$FLOORTSV" ]; then
    md_cpu=$(awk -F'\t' -v b="$s" -v h="nohuge=$NOHUGE" '$1==b && $2=="m3" && $3==h {printf "%s%%", $17}' "$FLOORTSV")
    md_elap=$(awk -F'\t' -v b="$s" -v h="nohuge=$NOHUGE" '$1==b && $2=="m3" && $3==h {printf "%s%%", $14}' "$FLOORTSV")
    [ -n "$md_cpu" ] || md_cpu="-"; [ -n "$md_elap" ] || md_elap="-"
  fi
  printf "%-20s %12s %12s %12s   %8s %8s %5s %7s %12s %12s  %s\n" "$s" \
    "$(human "${R[sbl]:-NA}")" "$(human "${R[m3]:-NA}")" "$(human "${R[m4]:-NA}")" "$sp3" "$sp4" \
    "$([ "$gcn" -gt 0 ] && echo "GC$gcn" || echo 0)" "$nivstr" "$md_cpu" "$md_elap" "$ckstat"
done
echo
echo "CHECK RESULT: ok=$tot_ok bad=$tot_bad xfail=$tot_xf xpass=$tot_xp"
if [ "$tot_load" -gt 0 ]; then
  echo "⛔ $tot_load row(s) have nivcsw > $NIVCSW_FLAG (marked '!' above) -- the winning rep was still"
  echo "   scheduler-contaminated; re-measure on a quieter box before quoting them as a headline number."
fi
[ -n "$XPASSED" ] && echo "⛔ XPASS:$XPASSED -- passes WITH a sibling .xfail present. Re-measure, then RETIRE the marker."
if [ -n "$UNGRADED" ]; then
  echo "⛔ UNGRADED (in $B, not harness-driven, absent from the table above):$UNGRADED"
  echo "   Every benchmark here is wrapped by ../harness/scripts/bench_wrap_snobol4.py (CEO-1984); a kernel it refuses is named here and"
  echo "   can build its timed twin -- convert it or delete it (BM-2, s265 shape). This is a FAILURE."
else
  echo "ungraded: none -- every .sno in $B is a standalone program with a *BENCH marker and was wrapped and graded (BM-2, s265)."
fi
if [ "$tot_gc" -gt 0 ]; then
  echo "⛔ $tot_gc row(s) COLLECTED inside the measurement window -- those rates are stall figures, not"
  echo "   throughput.  The heap is the unit's declared need (CEO-1353), never a window typed here: a gc>0 row is quoted as untrusted."
else
  echo "gc: 0 rows collected inside the window at the declared heaps -- every rate above is stall-free."
fi
[ "$tot_bad" -eq 0 ] && [ -z "$UNGRADED" ]
