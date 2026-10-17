#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_icon_kernels.sh -- THE TEN ICON KERNELS, re-measured on the TWO-NUMBER BASIS against BOTH
# rivals: Arizona iconx (the reference implementation) and JCON jcont (Proebsting & Townsend's
# Icon-to-JVM compiler).  Written hq_P 2026-09-10 for ceo CEO-490, on Lon's question of 2026-09-10
# 09:1x, verbatim: "How does the speed of SCRIP compare to Arizona and JCON?"
#
# ⛔⭐⭐ WHAT THIS REPLACES, AND WHY THE OLD GRID COULD NOT SIMPLY BE RE-RUN.  README.md § Icon
# carried a ten-kernel `x vs iconx` grid (int_loop 5.64x ... concat_intvar 0.72x) dated 2026-08-27,
# measured on WHOLE-PROGRAM WALL CLOCK with no overhead term and no rival but Arizona.  Every one of
# those three properties is now a defect: the kernels run in 20-500 ms, /usr/bin/time resolves 10 ms,
# and process start is 1-4 ms for a native engine and ~70 ms for a JVM -- so a bare wall total on this
# set is a small number of ticks with a start-up constant baked into it, and the constant is 5% of one
# engine's reading and 50% of another's.  ⛔ A SINGLE-INSTRUMENT WALL GRID CANNOT BE FIXED BY RUNNING
# IT AGAIN; it has to be replaced by an instrument with no floor plus a basis that names the constant.
#
# ⭐⭐ TWO INSTRUMENTS, AND NO MULTIPLE EVER CROSSES THEM (RULES.md § FACT RULES, APPLES TO APPLES).
#   [A] callgrind Ir -- for iconx, m3 and m4.  DETERMINISTIC, and MEASURED HERE 2026-09-10 rather than
#       assumed, because the first draft of this header overclaimed it and the board caught the draft:
#         - SAME binary, SAME argv, SAME cwd, SAME environment, three runs -> 1,500,319,412 EXACTLY,
#           three times.  Byte-identical.  So ONE rep is the whole measurement, there is no spread to
#           report, and there is no tick floor to quantize against.
#         - CHANGE the path length or add an environment variable and it moves by ~1,000 Ir out of
#           1.5e9 (0.00009%): +1,305 for a longer .icx name, +1,007 for one extra env var, because the
#           process copies argv and environ at start-up.  ⛔ SO "byte-identical ACROSS RUNS" IS TOO
#           STRONG A CLAIM and this file no longer makes it -- the honest one is "byte-identical for a
#           FIXED argv and environment, and stable to five decimal places otherwise".  Every engine in
#           one board run shares one working directory, so that residue is common to the whole board
#           and is some six orders of magnitude below any multiple printed on it.
#       ⭐ Set that 0.00009% beside the JVM's 35% and the choice of instrument makes itself.
#       This is the instrument the README itself queued this re-measurement for.
#   [B] WALL and CPU ms -- for ALL FOUR engines, because it is the ONLY instrument the JVM arm can be
#       graded on at all.  ⛔ callgrind Ir REFUSES for jcont (ceo CEO-494): the same kernel measured
#       1,069,787,424 then 1,443,104,013 Ir, a 35% spread from JIT decisions alone.
#   ⛔ So `m4 x vs iconx` is an Ir multiple, `m4 x vs jcont` is a WALL multiple, each column says which,
#   and the two are never combined into a ranking.
#
# ⭐ THE THREE ANGLES on instrument [B] (ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE
# TRIANGULATION), which is how a 20 ms program is timed honestly with a 10 ms tick:
#   Angle 1 -- TIME-mode    : fixed wall budget, COUNT completed runs -> runs/s.
#   Angle 2 -- ITER-mode    : fixed run count, total external CPU     -> runs/s.
#   Angle 3 -- WRAPPER      : /usr/bin/time per run, MEDIAN of REPS after WARMUP discarded -> ms.
#   ⭐ Angles 1 and 2 AGGREGATE MANY PROCESS RUNS, so the 10 ms tick is divided away by the run count
#   instead of being carried into the answer -- that is their whole purpose on a set this fast.
#   ⛔ CROSS-PROVE OR VOID: angle 1 and angle 2 runs/s must agree within TOL_PCT for an (engine,kernel)
#   or the cell is printed VOID.  Two angles that disagree are not averaged; they are refused.
#
# ⭐ THE TWO-NUMBER BASIS: OVERHEAD is the EMPTY ICON PROGRAM measured per engine on the SAME
# instrument; WORK = total - OVERHEAD.  ⛔ THE JVM's WARM-UP IS OVERHEAD AND IS NEVER COUNTED AS WORK
# (CEO-490).  ⛔ CEO-173: where OVERHEAD reaches 50% of an arm's reading the WORK multiple is REFUSED
# and the labelled TOTAL-basis multiple prints in its place -- never both, never a quiet asterisk.
# Measured here: empty-program wall is iconx 1 ms, m4 2 ms, m3 4 ms, jcont ~70 ms, so the refusal is
# not hypothetical on this set -- it fires on the JVM arm of every short kernel.
#
# ⛔⭐ THE 790x TRAP (carried from bench_icon_classic_set.sh because it is the one that bites here).
# callgrind does NOT follow exec into a child unless --trace-children=yes.  A jcon program is a
# /bin/sh wrapper that execs java, so an untraced reading of an empty Icon program is 367,008 Ir where
# the truth is 291,132,178.  ⭐ The number is not malformed or suspicious -- it is a small, plausible,
# correctly measured count OF THE WRONG PROCESS, and on a board asking "who does less work" it reads
# as the rival winning by three orders of magnitude.
#
# ⛔⭐⭐ AND HERE IS THE GUARD THAT DOES **NOT** WORK, MEASURED ON THIS BOARD 2026-09-10 -- A MAGNITUDE
# FLOOR.  The first cut of this script refused any empty-program Ir under 1,000,000 as "too small to be
# real".  It fired IMMEDIATELY, on Arizona iconx, whose empty program reads 316,437 Ir -- and iconx is
# a stripped ELF binary that forks NOTHING.  ⭐ The reading was correct and the guard was wrong: Arizona's
# interpreter start-up is genuinely ~10x leaner than our runtime's (m4 empty = 2,932,358 Ir), which is a
# real and interesting fact about the rival, not an instrument fault.  ⛔ A MAGNITUDE FLOOR CANNOT TELL A
# LEAN ENGINE FROM A MISREAD ENGINE, because the wrapper's wrong number (367,008) and the lean engine's
# right number (316,437) are THE SAME SIZE.  Had the floor been set below iconx it would have passed
# jcont's misread too -- there is no threshold that separates them, so the whole shape is unfixable.
# ✅ THE DISCRIMINATOR THAT WORKS IS A DIRECT TEST OF THE CAUSE, NOT A PROXY FOR IT: run the empty
# program under callgrind twice, once plain and once --trace-children=yes, and count the `refs:` lines.
# A process that forks reports MORE THAN ONE refs line, or a different total when children are traced.
# MEASURED: iconx 316,437 == 316,437 and one line; m4 2,932,358 == 2,932,358 and one line; jcont prints
# TWO refs lines (298,665 and 366,447).  ⛔ An engine that fails this probe has its Ir arm REFUSED
# outright -- never silently corrected by adding --trace-children, because for a JVM the traced number
# is not a fixed reading, it is a different wrong reading (the JIT spread of CEO-494 is still there).
#
# CORRECTNESS GATES THE NUMBER: every kernel's stdout is byte-compared against an iconx cut taken AT
# RUN TIME.  An engine that answers differently gets NO multiple.  A wrong answer is never a fast one.
#
# EXIT: 0 = board printed, 1 = a kernel was RED, 2 = REFUSED (nothing measurable).  ⛔ It never prints
# an empty or partial grid as though it were a result.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ROOT="$HERE/../../SCRIP"
SCRIP_BIN="${SCRIP:-$ROOT/scrip}"
RTDIR="$ROOT/out"
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
REPS="${REPS:-5}"                 # angle 3: timed runs kept, median reported
WARMUP="${WARMUP:-2}"             # angle 3: runs discarded first (the JVM needs them; natives pay nothing)
BUDGET_A1="${BUDGET_A1:-2}"       # angle 1: fixed wall-clock budget in seconds
REPS_A2="${REPS_A2:-15}"          # angle 2: fixed run count
TOL_PCT="${TOL_PCT:-35}"          # angle1 vs angle2 agreement band; outside it the cell is VOID
RUN_TMO="${RUN_TMO:-120}"
IR_TMO="${IR_TMO:-600}"           # callgrind is ~50x native; every kernel here is under 1 s natively
TSV_OUT="${TSV_OUT:-}"
refuse() { echo "⛔ ICON KERNEL BOARD REFUSED (rc=2): $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- the ONE oracle-path authority (s200)."
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || refuse "lib_perf_fmt.sh unloadable -- the ONE authority for printing a multiple (s266)."
# CEO-743 welded a load stamp onto every standalone perf_mult/perf_pct. THIS SCRIPT COMPOSES ITS OWN CELLS
# from captured multiples, so the stamp must not land INSIDE a cell -- it is emitted once, above, with the
# shared axes, which is where the FACT RULE says a grid names anything it shares.
PERF_STAMP_OFF=1
[ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN -- a table printed without it would be plausible and false."
ICONT="$(icont_bin)" || refuse "no icont"
ICONX="$(iconx_bin)" || refuse "no iconx"
JCONT="$(jcont_bin 2>/dev/null)" || JCONT=""
HAVE_JCON=0; [ -n "$JCONT" ] && [ -x "$JCONT" ] && command -v java >/dev/null 2>&1 && HAVE_JCON=1
HAVE_IR=0;   command -v valgrind >/dev/null 2>&1 && HAVE_IR=1
[ -d "$CORPUS_SRC" ] || refuse "corpus dir $CORPUS_SRC not found."
command -v /usr/bin/time >/dev/null 2>&1 || refuse "/usr/bin/time missing -- it is what produces the CPU number."
W="$(mktemp -d "${TMPDIR:-/tmp}/icon_kernels.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
export PATH="$(dirname "$ICONT"):$PATH"   # jcont shells out to icont; without this it fails talking about icont
C="$W/c"; mkdir -p "$C"; cp "$CORPUS_SRC"/bench_icn*.icn "$C/" 2>/dev/null
printf 'procedure main()\nend\n' > "$C/zz_empty.icn"
KERNELS="${KERNELS:-$(cd "$C" && ls bench_icn*.icn 2>/dev/null | sed 's/\.icn$//' | sort)}"
[ -n "$KERNELS" ] || refuse "no bench_icn*.icn kernels under $CORPUS_SRC -- nothing to measure."

# ---------- per-engine builders: each echoes a runnable argv, or nothing ----------
build_iconx() { ( cd "$C" && "$ICONT" -s -o "$W/$1.icx" "$1.icn" ) >/dev/null 2>&1 && echo "$ICONX $W/$1.icx"; }
build_jcont() { [ "$HAVE_JCON" = 1 ] || return 0
  ( cd "$C" && bash "$JCONT" -s -o "$W/$1.jxe" "$1.icn" ) >/dev/null 2>&1 && [ -x "$W/$1.jxe" ] && echo "$W/$1.jxe"; }
build_m4()    { ( cd "$C" && "$SCRIP_BIN" --compile --target=x86 "$1.icn" > "$W/$1.s" ) 2>"$W/$1.m4c.err"
  [ -s "$W/$1.s" ] || return 0
  gcc -no-pie "$W/$1.s" -L"$RTDIR" -lscrip_rt -Wl,-rpath,"$RTDIR" -lm -lpthread -o "$W/$1.bin" 2>"$W/$1.m4l.err" || return 0
  echo "$W/$1.bin"; }
# ⛔ m3 COMPILES ON EVERY RUN BY CONSTRUCTION -- it is `scrip --run`, so its total carries the compile
# where m4's does not.  That is a real difference between the modes, not an instrument artefact, and it
# is why the m3 column is never read as m4's rival.  The empty-program overhead term absorbs the fixed
# part of that compile; what remains in m3's WORK is this kernel's own compile, honestly.
m3_argv() { echo "$SCRIP_BIN --run $C/$1.icn"; }
engine_argv() { case "$1" in iconx) build_iconx "$2";; jcont) build_jcont "$2";; m4) build_m4 "$2";; m3) m3_argv "$2";; esac; }

# ---------- instrument A: callgrind Ir (deterministic, one rep) ----------
# ⛔⭐⭐ AN Ir READING FROM A RUN THAT DIED IS REFUSED, AND THE REFUSAL PRINTS WITH ITS REASON --
# "not measured" and "measured and thrown away" must never look the same on a board.  MEASURED HERE
# 2026-09-10 on concat_table: the m4 binary runs CLEAN and CORRECT natively (answer 40000, rc=0) and
# SIGSEGVs under valgrind inside gc_zeta_frame (gc_heap.c:557), which our own handler then reclassifies
# as a stack overflow (rt_stack_overflow.c:21) and re-raises.  ⭐ callgrind STILL PRINTS AN Ir TOTAL for
# that run -- 330,078,095 one time and 330,079,909 the next -- so the trap is a number that LOOKS like
# every other cell on the board and is (a) from a crashed process and (b) NOT EVEN DETERMINISTIC, which
# is the one property the whole Ir instrument rests on.  ⛔ So a non-zero exit voids the reading: the
# cell prints REFUSED(rc=N), never a bare NA and never the number.  IR_RC carries the status out.
# ⛔ THE STATUS COMES OUT THROUGH STDOUT, NOT THROUGH A VARIABLE.  The first cut set a global IR_RC here
# and read it in the caller -- but the caller invokes this as v="$(ir_one ...)", and a COMMAND
# SUBSTITUTION IS A SUBSHELL: the assignment happened in a child and the parent never saw it, so every
# crashed arm read back as rc=0 with an empty value and printed a bare NA -- exactly the "not measured"
# vs "measured and refused" confusion this function exists to prevent.  It printed no warning either,
# because the warning was gated on the variable that could not survive.  ⭐ A status that has to cross a
# subshell boundary travels as OUTPUT or as the function's own EXIT CODE; a global does not travel.
ir_one() {  # argv... -> "<Ir>" on a clean run, or "RC:<rc>" when the run died
  local out rc
  out="$(timeout -k 5 "$IR_TMO" valgrind --tool=callgrind --callgrind-out-file=/dev/null "$@" 2>&1 </dev/null)"; rc=$?
  [ "$rc" = 0 ] || { echo "RC:$rc"; return 1; }
  echo "$out" | sed -n 's/.*refs:[[:space:]]*\([0-9,]*\).*/\1/p' | tr -d ',' | tail -1
}
# ⛔ THE CHILD-PROCESS PROBE -- run ONCE per engine on the empty program.  Echoes OK or CHILD.
# This is the 790x trap's tripwire, and it tests the CAUSE (did this process fork?) rather than a
# symptom (is the number small?) -- see the header for why the magnitude floor it replaced was unfixable.
ir_probe_children() {  # argv... -> OK | CHILD  (non-zero rc = could not probe)
  local plain nl pn tr
  plain="$(timeout -k 5 "$IR_TMO" valgrind --tool=callgrind --callgrind-out-file=/dev/null "$@" 2>&1 </dev/null)" || return 1
  nl="$(echo "$plain" | grep -c 'refs:')"
  pn="$(echo "$plain" | sed -n 's/.*refs:[[:space:]]*\([0-9,]*\).*/\1/p' | tr -d ',' | tail -1)"
  tr="$(timeout -k 5 "$IR_TMO" valgrind --tool=callgrind --trace-children=yes --callgrind-out-file=/dev/null "$@" 2>&1 </dev/null | sed -n 's/.*refs:[[:space:]]*\([0-9,]*\).*/\1/p' | tr -d ',' | tail -1)" || return 1
  if [ "${nl:-0}" -gt 1 ] || [ "$pn" != "$tr" ]; then echo CHILD; else echo OK; fi
}
# ---------- instrument B, angle 3: the process wrapper ----------
time_one() {  # argv... -> "<wall_ms> <cpu_ms> <rc>"
  local tf="$W/t.$$" rc
  /usr/bin/time -f '%e %U %S' -o "$tf" timeout -k 5 "$RUN_TMO" "$@" >"$W/run.out" 2>"$W/run.err" </dev/null; rc=$?
  awk -v rc="$rc" '{printf "%.0f %.0f %d\n", $1*1000, ($2+$3)*1000, rc}' "$tf" 2>/dev/null || echo "0 0 $rc"
}
# ⛔ THE SPREAD IS NEVER AVERAGED AWAY: it is the only thing on a timed board that tells a reader
# whether the median in front of them is a measurement or a coin flip.  On the JVM arm it is routinely
# tens of percent, and a board that hid it would read exactly like a deterministic one.
time_median() {  # argv... -> "<median_wall> <median_cpu> <spread_pct> <rc>"
  local i r w c rc; local ws=() cs=()
  for i in $(seq 1 "$WARMUP"); do time_one "$@" >/dev/null 2>&1; done
  for i in $(seq 1 "$REPS"); do
    r="$(time_one "$@")"; w="${r%% *}"; c="$(echo "$r"|awk '{print $2}')"; rc="$(echo "$r"|awk '{print $3}')"
    [ "$rc" = 0 ] || { echo "0 0 0 $rc"; return 0; }
    ws+=("$w"); cs+=("$c")
  done
  printf '%s\n' "${ws[@]}" | sort -n > "$W/ws"; printf '%s\n' "${cs[@]}" | sort -n > "$W/cs"
  local mw mc lo hi sp
  mw="$(awk -v n="$REPS" 'NR==int((n+1)/2)' "$W/ws")"; mc="$(awk -v n="$REPS" 'NR==int((n+1)/2)' "$W/cs")"
  lo="$(head -1 "$W/ws")"; hi="$(tail -1 "$W/ws")"
  sp="$(awk -v l="$lo" -v h="$hi" 'BEGIN{printf "%.0f",(l>0?(h-l)*100/l:0)}')"
  echo "${mw:-0} ${mc:-0} ${sp:-0} 0"
}
# ---------- instrument B, angle 1: fixed TIME budget -> runs/s ----------
# ⛔⭐ THE CLOCK HERE IS THE SHELL BUILTIN `SECONDS`, NOT `date` -- AND THAT IS NOT A MICRO-OPTIMISATION.
# The first cut of this loop called $(date +%s) as its while-condition, which FORKS AND EXECS /bin/date
# once per iteration.  On this kernel set a run is ~10 ms and a date fork is ~1-2 ms, so angle 1 was
# spending a large and program-dependent fraction of its fixed budget measuring /bin/date -- runs/s came
# out badly understated, angle 1 and angle 2 disagreed far outside TOL_PCT, and the cross-prove printed
# VOID on every fast row.  ⭐ THE GUARD DID ITS JOB: it refused ten numbers rather than publishing them,
# and the disagreement is what exposed the defect -- in the INSTRUMENT, not in any engine.  ⛔ An angle
# that shells out inside its own timing loop is not measuring the program; a counting loop must contain
# NO fork of its own, so the only work between two readings of the clock is the run being counted.
angle1() {  # argv... -> runs_per_s
  local n=0 start=$SECONDS
  while [ $((SECONDS - start)) -lt "$BUDGET_A1" ]; do timeout -k 5 "$RUN_TMO" "$@" >/dev/null 2>&1 </dev/null || return 1; n=$((n+1)); done
  awk -v n="$n" -v b="$BUDGET_A1" 'BEGIN{printf "%.2f", n/b}'
}
# ---------- instrument B, angle 2: fixed RUN count -> runs/s ----------
angle2() {  # argv... -> runs_per_s
  local i t0 t1
  t0=$(date +%s%N)
  for i in $(seq 1 "$REPS_A2"); do timeout -k 5 "$RUN_TMO" "$@" >/dev/null 2>&1 </dev/null || return 1; done
  t1=$(date +%s%N)
  awk -v n="$REPS_A2" -v d="$((t1-t0))" 'BEGIN{ if(d<=0){print "0";exit} printf "%.2f", n/(d/1000000000) }'
}

# ---------- OVERHEAD: the empty program, per engine, on BOTH instruments ----------
declare -A OVW OVC OVIR AV_EMPTY IR_REFUSED
for eng in iconx jcont m3 m4; do
  [ "$eng" = jcont ] && [ "$HAVE_JCON" != 1 ] && continue
  av="$(engine_argv "$eng" zz_empty)"; [ -n "$av" ] || continue
  AV_EMPTY[$eng]="$av"
  r="$(time_median $av)"; OVW[$eng]="$(echo "$r"|awk '{print $1}')"; OVC[$eng]="$(echo "$r"|awk '{print $2}')"
  if [ "$HAVE_IR" = 1 ] && [ "$eng" != jcont ]; then
    ch="$(ir_probe_children $av)" || ch=""
    if [ "$ch" != OK ]; then
      IR_REFUSED[$eng]="${ch:-probe-failed}"
      echo "⚠ Ir arm REFUSED for $eng: the child-process probe reports ${ch:-probe-failed} -- callgrind would be counting the wrong process (the 790x trap). Its wall columns still stand." >&2
    else
      v="$(ir_one $av)" || v=""; [ -n "$v" ] && OVIR[$eng]="$v"
    fi
  fi
done

# ⛔⭐ THE BOX IS SHARED AND THE LOAD IS PART OF THE READING.  Nine other seats run boards on this
# machine; measured 2026-09-10 the 1-minute load average sat between 7 and 12 while this board ran, and
# the jcont wall spread moved from 8-31% to 50-72% between two runs of the SAME binaries on the SAME
# tree.  ⭐ THAT IS THE NEIGHBOURS BEING MEASURED, NOT THE JVM CHANGING.  Instrument [A] is immune --
# an instruction count does not depend on who else is running, and these ten Ir readings reproduced
# BYTE-IDENTICALLY across three separate invocations taken at different load levels.  Instrument [B]
# is not immune, so the load average is PRINTED WITH THE BOARD and the wall multiples are read with it.
LOADAVG="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo '?')"
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
CTREE="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
NK="$(echo "$KERNELS" | wc -w)"
echo "ICON_KERNEL_SET tree=SCRIP $TREE corpus $CTREE RT_OPT=-O0 date=$(date -u +%Y-%m-%dT%H:%MZ) kernels=$NK reps=$REPS warmup=$WARMUP loadavg=$LOADAVG"
echo "  ⚠ SHARED BOX: 1/5/15-min load average at start = $LOADAVG. Instrument [A] Ir is IMMUNE to it (an instruction count does not"
echo "    depend on the neighbours, and these readings reproduce byte-identically across runs); instrument [B] wall is NOT -- read"
echo "    every ms column and every 'x vs jcont' cell against the spread beside it, and prefer the Ir column where the two disagree."
echo "  ⛔ SHARED AXES (RULES.md § FACT RULES, APPLES TO APPLES) -- every row below shares ALL of these:"
echo "     load at start = $(perf_load_stamp)  (CEO-743: a wall-clock row shares a basis only with rows at a like load)"
echo "     basis = two-number; OVERHEAD is the EMPTY ICON PROGRAM per engine on the SAME instrument; WORK = total - OVERHEAD"
echo "     RT_OPT=-O0 · mode m3=--run (compiles every run) m4=--compile+gcc · oracle = $ICONX · rival = ${JCONT:-<absent>} · corpus $CTREE · one box, one sitting"
echo "     [A] Ir  = callgrind instruction reads, ONE rep, DETERMINISTIC (byte-identical for fixed argv+env; ~0.0001% otherwise) -- iconx, m3, m4"
echo "     [B] ms  = WALL and CPU (user+sys) from /usr/bin/time, MEDIAN of $REPS after $WARMUP warm-ups -- all four engines"
echo "     ⛔ NO MULTIPLE CROSSES INSTRUMENTS: 'x vs iconx' is Ir, 'x vs jcont' is WALL, and neither is a ranking of the other."
echo "     ⛔ callgrind Ir REFUSES on the jcont arm (ceo CEO-494): JIT makes a JVM's Ir vary ~35% run to run."
echo "     ⛔ THE JVM's WARM-UP IS OVERHEAD, NEVER WORK (CEO-490); CEO-173: OVERHEAD >= 50% of an arm => that multiple is TOTAL-basis."
echo "     ⭐ THREE ANGLES on [B]: A1 fixed ${BUDGET_A1}s budget -> runs/s · A2 fixed $REPS_A2 runs -> runs/s · A3 wrapper median ms."
echo "        A1 and A2 aggregate many runs, dividing the 10 ms tick away; they must agree within ${TOL_PCT}% or the cell prints VOID."
echo "  OVERHEAD empty program: wall/cpu ms  iconx ${OVW[iconx]:-NA}/${OVC[iconx]:-NA} · jcont ${OVW[jcont]:-NA}/${OVC[jcont]:-NA} · m3 ${OVW[m3]:-NA}/${OVC[m3]:-NA} · m4 ${OVW[m4]:-NA}/${OVC[m4]:-NA}"
echo "  OVERHEAD empty program: Ir           iconx ${OVIR[iconx]:-NA} · m3 ${OVIR[m3]:-NA} · m4 ${OVIR[m4]:-NA} · jcont REFUSED(JIT)"
[ "$HAVE_JCON" = 1 ] || echo "  ⚠ JCON RIVAL ABSENT -- every jcont cell is EMPTY BECAUSE IT WAS NOT MEASURED, not because jcont was slow: jcont=${JCONT:-<accessor refused>} java=$(command -v java || echo '<not on PATH>')"
[ "$HAVE_IR"   = 1 ] || echo "  ⚠ valgrind ABSENT -- every Ir cell is EMPTY BECAUSE IT WAS NOT MEASURED. The wall columns still stand."
printf '%-34s %-8s %14s %14s %14s %12s %8s %8s %8s %8s %10s %14s %10s\n' \
  kernel verdict iconx_Ir m3_Ir m4_Ir 'm4 x iconx' ix_ms jc_ms m3_ms m4_ms jc_spread 'm4 x jcont' A1/A2
if [ -n "$TSV_OUT" ]; then
  # ⛔ THE COLUMN HEADER IS LINE 1, NOT A COMMENT BLOCK.  Every reader of a .tsv -- awk, pandas, a
  # DONE-WHEN's `head -1` -- takes line 1 as the header, and a leading `#` preamble silently hands it a
  # prose sentence instead: the check then reports "no iconx column" about a file whose iconx column is
  # four lines down.  Provenance is real and is kept, as TRAILING `#` lines.
  printf 'kernel\tverdict\ticonx_Ir\tm3_Ir\tm4_Ir\ticonx_WORK_Ir\tm4_WORK_Ir\tbasis_Ir\tm4_x_vs_iconx_Ir\ticonx_wall_ms\tjcont_wall_ms\tm3_wall_ms\tm4_wall_ms\ticonx_spread_pct\tjcont_spread_pct\tm3_spread_pct\tm4_spread_pct\ticonx_WORK_wall\tjcont_WORK_wall\tm4_WORK_wall\tbasis_wall\tm4_x_vs_jcont_wall\tm4_A1_runs_s\tm4_A2_runs_s\tjcont_A1_runs_s\tjcont_A2_runs_s\tcrossprove\n' > "$TSV_OUT"
fi

work() { local t="$1" o="$2"; case "$t" in ''|NA|*[!0-9]*) echo ""; return;; esac; case "$o" in ''|*[!0-9]*) echo ""; return;; esac; echo $((t-o)); }
frac() { awk -v o="$1" -v t="$2" 'BEGIN{printf "%d",(t>0?o*100/t:100)}'; }
cross() { # a1 a2 -> OK | VOID | -
  local a="$1" b="$2"; case "$a$b" in ''|*NA*) echo "-"; return;; esac
  awk -v a="$a" -v b="$b" -v t="$TOL_PCT" 'BEGIN{ if(a<=0||b<=0){print "-";exit} d=(a>b?a-b:b-a)*100/(a<b?a:b); print (d<=t?"OK":"VOID") }'
}
RC=0; N=0
for k in $KERNELS; do
  ix_av="$(build_iconx "$k")"
  if [ -z "$ix_av" ]; then printf '%-34s %-8s  ORACLE-COMPILE-FAILED -- no ground truth, nothing graded\n' "$k" UNPROVEN; RC=1; continue; fi
  timeout -k 5 "$RUN_TMO" $ix_av >"$W/$k.oracle" 2>"$W/$k.oracle.err" </dev/null; orc=$?
  if [ "$orc" != 0 ]; then printf '%-34s %-8s  ORACLE-RAN-RED rc=%s -- no ground truth, nothing graded\n' "$k" UNPROVEN "$orc"; RC=1; continue; fi
  if [ ! -s "$W/$k.oracle" ]; then printf '%-34s %-8s  ORACLE-ANSWER-EMPTY -- a green here would be two empty files agreeing\n' "$k" UNPROVEN; RC=1; continue; fi
  declare -A AV OUTOK
  AV[iconx]="$ix_av"; AV[jcont]="$(build_jcont "$k")"; AV[m4]="$(build_m4 "$k")"; AV[m3]="$(m3_argv "$k")"
  for eng in jcont m3 m4; do
    OUTOK[$eng]="-"; av="${AV[$eng]}"; [ -n "$av" ] || { OUTOK[$eng]=BUILDFAIL; continue; }
    timeout -k 5 "$RUN_TMO" $av >"$W/$k.$eng" 2>"$W/$k.$eng.err" </dev/null; erc=$?
    if   [ "$erc" != 0 ]; then OUTOK[$eng]="rc=$erc"
    elif cmp -s "$W/$k.$eng" "$W/$k.oracle"; then OUTOK[$eng]=PASS
    else OUTOK[$eng]=DIFF; fi
  done
  verdict=PASS; { [ "${OUTOK[m3]}" = PASS ] && [ "${OUTOK[m4]}" = PASS ]; } || { verdict=RED; RC=1; }
  # ---- instrument A: Ir, one rep, only on arms that answered correctly ----
  declare -A IR
  for eng in iconx m3 m4; do IR[$eng]=NA
    [ "$HAVE_IR" = 1 ] || continue
    [ -z "${IR_REFUSED[$eng]:-}" ] || { IR[$eng]="REFUSED(${IR_REFUSED[$eng]})"; continue; }
    [ "$eng" = iconx ] || [ "${OUTOK[$eng]}" = PASS ] || continue
    v="$(ir_one ${AV[$eng]})"
    case "$v" in
      RC:*) IR[$eng]="REFUSED(rc=${v#RC:})"
            echo "⚠ Ir REFUSED for $eng on $k: the run exited rc=${v#RC:}. callgrind still printed a total, but a count from a process that died is not a measurement -- and its reruns disagree -- so it is voided, not recorded." >&2;;
      ''|*[!0-9]*) ;;
      *) IR[$eng]="$v";;
    esac
  done
  ixir="$(work "${IR[iconx]}" "${OVIR[iconx]:-}")"; m4ir="$(work "${IR[m4]}" "${OVIR[m4]:-}")"
  # ⛔⭐ CEO-173 IS A FALLBACK, NOT A FILTER -- AND THE FIRST CUT OF THIS WROTE IT AS A FILTER.
  # It required WORK > 0 on both arms BEFORE choosing a basis, so an arm whose OVERHEAD had eaten the
  # entire reading (WORK <= 0, which is precisely the >= 50% case, only worse) fell through every branch
  # and printed a bare "-".  ⭐ That is the CEO-173 case reading as NO MEASUREMENT AT ALL, when the rule
  # exists exactly to say what to print there: the labelled TOTAL.  The overhead test now comes FIRST and
  # a non-positive WORK routes into it rather than past it.
  bir="-"; mxir=" - "
  if [ -n "$ixir" ] && [ -n "$m4ir" ]; then
    if [ "$(frac "${OVIR[m4]:-0}" "${IR[m4]}")" -ge 50 ] || [ "$(frac "${OVIR[iconx]:-0}" "${IR[iconx]}")" -ge 50 ] || [ "$ixir" -le 0 ] || [ "$m4ir" -le 0 ]; then
      bir=TOTAL; mxir="TOTAL:$(perf_mult "${IR[iconx]}" "${IR[m4]}")"
    else bir=WORK; mxir="$(perf_mult "$ixir" "$m4ir")"; fi
  fi
  # ---- instrument B: angle 3 medians, only on arms that answered correctly ----
  declare -A MW MC MS A1 A2
  for eng in iconx jcont m3 m4; do MW[$eng]=NA; MC[$eng]=NA; MS[$eng]="-"; A1[$eng]=NA; A2[$eng]=NA
    [ "$eng" = iconx ] || [ "${OUTOK[$eng]}" = PASS ] || continue
    [ -n "${AV[$eng]}" ] || continue
    r="$(time_median ${AV[$eng]})"
    MW[$eng]="$(echo "$r"|awk '{print $1}')"; MC[$eng]="$(echo "$r"|awk '{print $2}')"; MS[$eng]="$(echo "$r"|awk '{print $3}')"
    a="$(angle1 ${AV[$eng]})" || a=""; [ -n "$a" ] && A1[$eng]="$a"
    b="$(angle2 ${AV[$eng]})" || b=""; [ -n "$b" ] && A2[$eng]="$b"
  done
  ixw="$(work "${MW[iconx]}" "${OVW[iconx]:-}")"; jcw="$(work "${MW[jcont]}" "${OVW[jcont]:-}")"; m4w="$(work "${MW[m4]}" "${OVW[m4]:-}")"
  # Same fallback-not-filter correction as the Ir side above.  It bites HARDER here: the JVM's start-up
  # is ~100-140 ms against whole-kernel totals of 150-450 ms, so jcont WORK goes non-positive routinely
  # and four cells printed "-" on the 15:5x run where the honest answer was a labelled TOTAL.
  bw="-"; mjw=" - "
  if [ -n "$m4w" ] && [ -n "$jcw" ]; then
    if [ "$(frac "${OVW[m4]:-0}" "${MW[m4]}")" -ge 50 ] || [ "$(frac "${OVW[jcont]:-0}" "${MW[jcont]}")" -ge 50 ] || [ "$m4w" -le 0 ] || [ "$jcw" -le 0 ]; then
      if [ "${MW[m4]}" = 0 ] || [ "${MW[m4]}" = NA ]; then bw="-"; mjw="<1 tick"   # ⛔ a 0 ms arm is BELOW the instrument, not infinitely fast: perf_mult would print n/a and "TOTAL:n/a" reads like a measurement that failed rather than a program the timer cannot see.
      else bw=TOTAL; mjw="TOTAL:$(perf_mult "${MW[jcont]}" "${MW[m4]}")"; fi
    else bw=WORK; mjw="$(perf_mult "$jcw" "$m4w")"; fi
  elif [ "${OUTOK[jcont]}" != PASS ]; then mjw="(jcont ${OUTOK[jcont]})"; fi
  xp="$(cross "${A1[m4]}" "${A2[m4]}")"
  case "$verdict" in PASS) ;; *) mxir="(m3 ${OUTOK[m3]} m4 ${OUTOK[m4]})"; mjw="-";; esac
  printf '%-34s %-8s %14s %14s %14s %12s %8s %8s %8s %8s %8s%% %14s %10s\n' \
    "$k" "$verdict" "${IR[iconx]}" "${IR[m3]}" "${IR[m4]}" "$mxir" "${MW[iconx]}" "${MW[jcont]}" "${MW[m3]}" "${MW[m4]}" "${MS[jcont]}" "$mjw" "$xp"
  [ -z "$TSV_OUT" ] || printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$k" "$verdict" "${IR[iconx]}" "${IR[m3]}" "${IR[m4]}" "${ixir:-NA}" "${m4ir:-NA}" "$bir" "$mxir" \
    "${MW[iconx]}" "${MW[jcont]}" "${MW[m3]}" "${MW[m4]}" "${MS[iconx]}" "${MS[jcont]}" "${MS[m3]}" "${MS[m4]}" \
    "${ixw:-NA}" "${jcw:-NA}" "${m4w:-NA}" "$bw" "$mjw" "${A1[m4]}" "${A2[m4]}" "${A1[jcont]}" "${A2[jcont]}" "$xp" >> "$TSV_OUT"
  N=$((N+1))
done
if [ -n "$TSV_OUT" ]; then
  {
    printf '# ICON KERNEL SET -- tree=SCRIP %s corpus %s RT_OPT=-O0 date=%s kernels=%s reps=%s warmup=%s loadavg_at_start=%s\n' "$TREE" "$CTREE" "$(date -u +%Y-%m-%d)" "$N" "$REPS" "$WARMUP" "$LOADAVG"
    printf '# SHARED BOX: instrument A (Ir) is immune to load and reproduced byte-identically across three runs; instrument B (wall/cpu) is NOT. Read every ms column against its spread.\n'
    printf '# instrument A: callgrind Ir, ONE rep, deterministic -- byte-identical for a FIXED argv+environment (measured 3/3), ~0.0001%% residue when path or env length changes. iconx, m3, m4. Ir REFUSES for jcont (JIT, ~35%% spread, CEO-494).\n'
    printf '# instrument B: WALL/CPU ms from /usr/bin/time, median of %s after %s warm-ups -- all four engines. Spread%%=(max-min)/min on wall.\n' "$REPS" "$WARMUP"
    printf '# basis: two-number. OVERHEAD = empty Icon program per engine PER INSTRUMENT. WORK = total - OVERHEAD. CEO-173: OVERHEAD >= 50%% of an arm => basis=TOTAL.\n'
    printf '# OVERHEAD wall/cpu ms: iconx %s/%s jcont %s/%s m3 %s/%s m4 %s/%s   OVERHEAD Ir: iconx %s m3 %s m4 %s (jcont REFUSED)\n' "${OVW[iconx]:-NA}" "${OVC[iconx]:-NA}" "${OVW[jcont]:-NA}" "${OVC[jcont]:-NA}" "${OVW[m3]:-NA}" "${OVC[m3]:-NA}" "${OVW[m4]:-NA}" "${OVC[m4]:-NA}" "${OVIR[iconx]:-NA}" "${OVIR[m3]:-NA}" "${OVIR[m4]:-NA}"
    printf '# multiple = rival WORK / SCRIP m4 WORK on the SAME instrument (FASTER axis, >1 = SCRIP ahead). x_vs_iconx is Ir; x_vs_jcont is WALL. NO multiple crosses instruments.\n'
    printf '# three angles on B: A1 fixed %ss budget -> runs/s; A2 fixed %s runs -> runs/s; A3 wrapper median (the ms columns). crossprove OK = A1 and A2 within %s%%; VOID = refused.\n' "$BUDGET_A1" "$REPS_A2" "$TOL_PCT"
    printf '# verdict: stdout byte-compared against an iconx cut taken AT RUN TIME. A wrong answer gets no multiple.\n'
  } >> "$TSV_OUT"
fi
echo "ICON_KERNEL_BOARD kernels=$N of $NK graded"
[ "$N" -gt 0 ] || refuse "no kernel measured -- a grid of nothing is not a measurement."
exit $RC
