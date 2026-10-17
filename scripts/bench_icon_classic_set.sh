#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_icon_classic_set.sh -- THE CLASSIC ICON BENCHMARK SET: concord deal ipxref queens rsg geddump,
# graded for CORRECTNESS against an iconx cut taken AT RUN TIME, then TIMED against Arizona iconx and
# JCON jcont on the two-number basis.  Lon 2026-09-10, verbatim via ceo CEO-493: "Get the classic Icon
# benchmark set working. Duh!!!"  Basis ruled by ceo CEO-494; written hq_P 2026-09-10.
#
# ⛔⭐⭐ WHY THIS IS NOT A callgrind Ir BOARD, AND THE RULING IS NOT A PREFERENCE (ceo CEO-494).
# Every other benchmark in this tree measures Ir, because Ir is DETERMINISTIC: bench_two_number_ir.sh's
# own header cites three consecutive runs returning byte-identical counts, and that property is what
# buys the economy of a single rep.  ⛔ IT DOES NOT HOLD FOR A JVM.  Measured here 2026-09-10 on the
# int_loop kernel under jcon: 1,069,787,424 Ir then 1,443,104,013 Ir -- a 35% spread on the same program
# and the same box, because JIT compilation decisions vary run to run.  So Ir REFUSES for the jcont arm,
# and jcont is measured on the two remaining angles (fixed iterations, and the process wrapper) by WALL
# and CPU, warm-up discarded, MEDIAN of at least five runs, the spread PRINTED beside every median.
# ⛔ NO MULTIPLE EVER CROSSES INSTRUMENTS: a wall multiple is computed against a wall number and a cpu
# multiple against a cpu number, and every column says which instrument produced it.
#
# ⛔⭐⭐ THE 790x TRAP, RECORDED HERE BECAUSE THIS IS THE FILE THAT MEASURES A JVM (hq_P 2026-09-10).
# If you ever DO put jcont under callgrind: callgrind does NOT follow exec into a child process unless
# --trace-children=yes.  A jcon program is a /bin/sh wrapper that execs java, so an untraced reading of
# an empty Icon program is 367,008 Ir where the truth is 291,132,178.  ⭐ The number it returns is not
# malformed, missing or suspicious -- it is a small, plausible, correctly measured count OF THE WRONG
# PROCESS, and on a board whose whole question is "who does less work" it reads as the rival winning by
# three orders of magnitude.  Every guard on that board -- the client exit-status check, the CEO-173
# overhead refusal -- passes it.
#
# THE TWO-NUMBER BASIS: OVERHEAD is the empty-program constant per engine, measured by this same
# protocol; WORK = median_total - median_overhead.  ⛔ CEO-173: when OVERHEAD is >= 50% of an arm's
# reading, the WORK multiple is REFUSED for that program and the labelled TOTAL-basis multiple is
# printed in its place -- never both, never a work number with a quiet asterisk.
#
# CORRECTNESS GATES THE NUMBER: the oracle output is cut at run time by iconx, and an engine whose
# output differs byte-for-byte gets NO multiple.  A wrong answer is never a fast answer.
#
# EXIT: 0 = board printed, 1 = a program was RED (wrong answer or did not run), 2 = REFUSED (nothing
# measurable -- an empty or plausible table is the failure this guards against, so it never prints one).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ROOT="$HERE/../../SCRIP"
SCRIP_BIN="${SCRIP:-$ROOT/scrip}"
RTDIR="$ROOT/out"
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
REPS="${REPS:-5}"          # CEO-494: at least five timed runs, median reported
WARMUP="${WARMUP:-2}"      # CEO-494: warm-up runs discarded (the JVM needs them; everyone else pays nothing)
RUN_TMO="${RUN_TMO:-120}"
TSV_OUT="${TSV_OUT:-}"
TICK_MS="${TICK_MS:-10}"   # /usr/bin/time %e resolution on this box: 10 ms. Measured, not assumed -- every
                           # median on this board is a multiple of it.
QUANT_TICKS="${QUANT_TICKS:-5}"  # below this many ticks a multiple is QUANTIZED and is labelled so
refuse() { echo "⛔ CLASSIC-SET BOARD REFUSED (rc=2): $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- the ONE oracle-path authority (s200)."
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || refuse "lib_perf_fmt.sh unloadable -- the ONE authority for printing a multiple (s266)."
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "lib_icon_ipl_isolation.sh unloadable -- the ONE argv-sidecar reader."
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "lib_declared_arena.sh unloadable -- the ONE declared-arena reader (CEO-1353)."
# CEO-743 welded a load stamp onto every standalone perf_mult/perf_pct. THIS SCRIPT COMPOSES ITS OWN CELLS
# from captured multiples, so the stamp must not land INSIDE a cell -- it is emitted once, above, with the
# shared axes, which is where the FACT RULE says a grid names anything it shares.
PERF_STAMP_OFF=1
[ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN -- a table printed without it would be plausible and false."
ICONT="$(icont_bin)" || refuse "no icont"
ICONX="$(iconx_bin)" || refuse "no iconx"
JCONT="$(jcont_bin 2>/dev/null)" || JCONT=""
HAVE_JCON=0
if [ -n "$JCONT" ] && [ -x "$JCONT" ] && command -v java >/dev/null 2>&1; then HAVE_JCON=1; fi
[ -d "$CORPUS_SRC" ] || refuse "corpus dir $CORPUS_SRC not found."
command -v /usr/bin/time >/dev/null 2>&1 || refuse "/usr/bin/time missing -- it is what produces the CPU number; bash's builtin cannot be trusted across engines."
WORK="$(mktemp -d "${TMPDIR:-/tmp}/icon_classic.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$WORK"' EXIT
export PATH="$(dirname "$ICONT"):$PATH"   # jcont shells out to icont; without this it fails talking about icont

# ---------- staging ----------
# ⛔⭐ THE KERNELS ARE SELF-CONTAINED SINCE corpus 5a128a38d (2026-09-23): options and shuffle are inlined in every kernel that used
# them and the post.icn harness left for reference/icon/icont-bench, so there is no link unit, no answer cut and no per-program table
# typed here. This file staged that harness until 2026-10-07 and so graded every program RED (m3 rc=1, m4 BUILDFAIL: scrip was handed
# an options.icn that no longer exists) -- an instrument that types a population's settings goes stale the day the population moves.
# Each kernel carries its own stdin (NAME.in, NAME.stdin, else NAME.dat, else /dev/null), argv (NAME.argv), memory (NAME.heap and
# NAME.stack, as switches) and oracle knobs (NAME.oracle_env), read through the ONE readers the IcnBench runner reads (CEO-1281, CEO-1353).
PROGS="${PROGS:-concord deal ipxref queens rsg geddump}"
C="$WORK/corpus"; mkdir -p "$C"
cp "$CORPUS_SRC"/*.icn "$C/" 2>/dev/null
declare -A STDIN ARGS SWS OENVS
for p in $PROGS; do f="$CORPUS_SRC/$p.icn"; [ -f "$f" ] || refuse "kernel $f is not in the corpus."
  STDIN[$p]=/dev/null; for x in in stdin dat; do [ -f "$CORPUS_SRC/$p.$x" ] && { STDIN[$p]="$CORPUS_SRC/$p.$x"; break; }; done
  declare -a AV=(); arc=0; ipl_argv_read "$f" AV || arc=$?; [ "$arc" = 2 ] && refuse "$p.argv is malformed (the reader said why above)."
  for a in ${AV[@]+"${AV[@]}"}; do case "$a" in *[[:space:]]*) refuse "$p.argv carries an argument with white space, which this board's word-split argv cannot pass byte for byte.";; esac; done
  ARGS[$p]="${AV[*]:-}"
  SWS[$p]="$(declared_switches_beside "$f")" || refuse "$p.heap or $p.stack is malformed (the reader said why above)."
  OENVS[$p]="$(declared_oracle_env_beside "$f")" || refuse "$p.oracle_env is malformed (the reader said why above)."
done

# ---------- the timing primitive ----------
# Echoes "<wall_ms> <cpu_ms> <rc>" for ONE run.  CPU is user+sys from /usr/bin/time, which is the only
# number that survives a busy box honestly -- wall on a shared machine measures the neighbours too.
time_one() {  # $1 = stdin file or empty; $2.. = argv
  local sin="$1"; shift
  local tf="$WORK/t.$$"; local rc
  if [ -n "$sin" ]; then
    /usr/bin/time -f '%e %U %S' -o "$tf" timeout -k 5 "$RUN_TMO" "$@" >"$WORK/run.out" 2>"$WORK/run.err" <"$sin"; rc=$?
  else
    /usr/bin/time -f '%e %U %S' -o "$tf" timeout -k 5 "$RUN_TMO" "$@" >"$WORK/run.out" 2>"$WORK/run.err" </dev/null; rc=$?
  fi
  awk -v rc="$rc" '{printf "%.0f %.0f %d\n", $1*1000, ($2+$3)*1000, rc}' "$tf" 2>/dev/null || echo "0 0 $rc"
}
# Echoes "<median_wall> <median_cpu> <spread_pct> <rc>" over WARMUP+REPS runs, warm-up discarded.
# ⛔ THE SPREAD IS NOT DECORATION AND IS NEVER AVERAGED AWAY: it is the only thing on this board that
# tells a reader whether the median in front of them is a measurement or a coin flip, and on the JVM arm
# it is routinely tens of percent (CEO-494).  A board that hid it would read exactly like a deterministic one.
time_median() {  # $1 = stdin, $2.. = argv
  local sin="$1"; shift
  local i r w c rc lastrc=0
  local ws=() cs=()
  for i in $(seq 1 "$WARMUP"); do time_one "$sin" "$@" >/dev/null 2>&1; done
  for i in $(seq 1 "$REPS"); do
    r="$(time_one "$sin" "$@")"; w="${r%% *}"; c="$(echo "$r" | awk '{print $2}')"; rc="$(echo "$r" | awk '{print $3}')"
    lastrc="$rc"; [ "$rc" = "0" ] || { echo "0 0 0 $rc"; return 0; }
    ws+=("$w"); cs+=("$c")
  done
  printf '%s\n' "${ws[@]}" | sort -n > "$WORK/ws.txt"; printf '%s\n' "${cs[@]}" | sort -n > "$WORK/cs.txt"
  local mw mc lo hi sp
  mw="$(awk 'NR==int((n+1)/2)' n="$REPS" "$WORK/ws.txt")"; mc="$(awk 'NR==int((n+1)/2)' n="$REPS" "$WORK/cs.txt")"
  lo="$(head -1 "$WORK/ws.txt")"; hi="$(tail -1 "$WORK/ws.txt")"
  sp="$(awk -v l="$lo" -v h="$hi" 'BEGIN{printf "%.0f", (l>0? (h-l)*100/l : 0)}')"
  echo "${mw:-0} ${mc:-0} ${sp:-0} $lastrc"
}
# ⛔ TIMING IS RUN WITHOUT OUTPUT TO A TERMINAL -- stdout goes to a file -- so the timed arm measures computation and the
# answer is graded on a separate run; the two arms therefore run the program twice, on purpose.

# ---------- per-engine builders: each echoes a runnable argv, or nothing ----------
build_iconx() { ( cd "$C" && "$ICONT" -s -o "$WORK/$1.icx" "$1.icn" ) >/dev/null 2>&1 && echo "$ICONX $WORK/$1.icx"; }
build_jcont() { [ "$HAVE_JCON" = "1" ] || return 0
  ( cd "$C" && bash "$JCONT" -s -o "$WORK/$1.jxe" "$1.icn" ) >/dev/null 2>&1 && [ -x "$WORK/$1.jxe" ] && echo "$WORK/$1.jxe"; }
build_m4()    {
  ( cd "$C" && "$SCRIP_BIN" --compile --target=x86 "$1.icn" > "$WORK/$1.s" ) 2>"$WORK/$1.m4c.err"
  [ -s "$WORK/$1.s" ] || return 0
  gcc "$WORK/$1.s" -L"$RTDIR" -lscrip_rt -Wl,-rpath,"$RTDIR" -lm -lpthread -o "$WORK/$1.bin" 2>"$WORK/$1.m4l.err" || return 0
  echo "$WORK/$1.bin${SWS[$1]:+ ${SWS[$1]}}"; }
# ⛔ m3 COMPILES ON EVERY RUN BY CONSTRUCTION -- it is `scrip --run`, so its total carries the compile
# where m4's does not.  That is a real difference between the modes, not an instrument artefact, and it
# is why the m3 column is labelled compile+run and may not be read as m4's rival.
m3_argv() { echo "$SCRIP_BIN${SWS[$1]:+ ${SWS[$1]}} --run $C/$1.icn"; }

# ---------- OVERHEAD: the empty-program constant, per engine, same protocol ----------
printf 'procedure main()\nend\n' > "$C/zz_empty.icn"
STDIN[zz_empty]=/dev/null; ARGS[zz_empty]=""; SWS[zz_empty]=""; OENVS[zz_empty]=""
declare -A OVW OVC
for eng in iconx jcont m3 m4; do OVW[$eng]="" ; OVC[$eng]=""; done
ov_probe() {  # $1 = engine
  local av
  case "$1" in
    iconx) av="$(build_iconx zz_empty)";;
    jcont) av="$(build_jcont zz_empty)";;
    m4)    av="$(build_m4 zz_empty)";;
    m3)    av="$(m3_argv zz_empty)";;
  esac
  [ -n "$av" ] || return 0
  local r; r="$(time_median "" $av)"
  [ "$(echo "$r" | awk '{print $4}')" = "0" ] || return 0
  OVW[$1]="$(echo "$r" | awk '{print $1}')"; OVC[$1]="$(echo "$r" | awk '{print $2}')"
}
for eng in iconx jcont m3 m4; do [ "$eng" = jcont ] && [ "$HAVE_JCON" != 1 ] && continue; ov_probe "$eng"; done

TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
CTREE="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "ICON_CLASSIC_SET tree=SCRIP $TREE corpus $CTREE RT_OPT=-O0 date=$(date -u +%Y-%m-%dT%H:%MZ) reps=$REPS warmup=$WARMUP"
echo "  ⛔ SHARED AXES (RULES.md § FACT RULES, APPLES TO APPLES) -- every row below shares ALL of these:"
echo "     instrument = WALL ms and CPU ms (user+sys) from /usr/bin/time, MEDIAN of $REPS runs after $WARMUP discarded warm-ups"
echo "     basis = two-number; OVERHEAD is the empty-program constant per engine; WORK = median - OVERHEAD"
echo "     RT_OPT=-O0 · oracle = $ICONX · rival = ${JCONT:-<absent>} · corpus $CTREE · one box, one sitting"
echo "     load at start = $(perf_load_stamp)  ⛔ CEO-743: a wall-clock multiple is NOT comparable across loads --"
echo "        one unchanged binary read 0.549x at load 6.96 and 0.384x at load 29.84, so load does not cancel out of a ratio."
echo "     ⛔ CORRECTNESS is the program's whole stdout against an iconx run taken AT RUN TIME, and that run against the kernel's"
echo "        own .ref (REF DRIFT refuses the row); stdin, argv, heap and stack are the kernel's own sidecars (CEO-1281, CEO-1353)."
echo "     ⛔ TIMING runs with stdout to a file, never a terminal, so it measures computation not terminal I/O."
echo "     ⛔ RESOLUTION: /usr/bin/time reports wall to ${TICK_MS} ms. A multiple whose arms are under $QUANT_TICKS ticks"
echo "        (${qf:-$((TICK_MS*QUANT_TICKS))} ms) is printed with a QNT: prefix -- the figure is real, the precision it"
echo "        LOOKS like is not. Off this floor by a bigger input or a self-timed hook, never by a tighter format."
echo "     ⛔ callgrind Ir REFUSES on the jcont arm (ceo CEO-494): JIT makes a JVM's Ir vary ~35% run to run,"
echo "        so Ir is the SCRIP-vs-iconx instrument only and NO multiple here crosses instruments."
echo "  OVERHEAD (empty Icon program): iconx ${OVW[iconx]:-NA}ms/${OVC[iconx]:-NA}ms · jcont ${OVW[jcont]:-NA}ms/${OVC[jcont]:-NA}ms · m3 ${OVW[m3]:-NA}ms/${OVC[m3]:-NA}ms · m4 ${OVW[m4]:-NA}ms/${OVC[m4]:-NA}ms  (wall/cpu)"
if [ "$HAVE_JCON" != "1" ]; then
  echo "  ⚠ JCON RIVAL ABSENT -- every jcont cell below is EMPTY BECAUSE IT WAS NOT MEASURED, not because"
  echo "    jcont was slow: jcont=${JCONT:-<accessor refused>} java=$(command -v java || echo '<not on PATH>')"
fi
printf '%-9s %-7s %10s %10s %8s %10s %10s %8s %10s %10s %8s %10s %10s %8s %8s %14s %14s\n' \
  program verdict ix_wall ix_cpu ix_sp jc_wall jc_cpu jc_sp m3_wall m3_cpu m3_sp m4_wall m4_cpu m4_sp basis 'm4 x vs iconx' 'm4 x vs jcont'
if [ -n "$TSV_OUT" ]; then
  {
    printf '# ICON CLASSIC SET -- tree=SCRIP %s corpus %s RT_OPT=-O0 date=%s reps=%s warmup=%s\n' "$TREE" "$CTREE" "$(date -u +%Y-%m-%d)" "$REPS" "$WARMUP"
    printf '# instrument: WALL ms and CPU ms (user+sys), MEDIAN of %s runs after %s discarded warm-ups. Spread%%=(max-min)/min on wall.\n' "$REPS" "$WARMUP"
    printf '# basis: two-number. OVERHEAD = empty Icon program per engine (wall/cpu ms): iconx %s/%s jcont %s/%s m3 %s/%s m4 %s/%s. WORK = median - OVERHEAD.\n' "${OVW[iconx]:-NA}" "${OVC[iconx]:-NA}" "${OVW[jcont]:-NA}" "${OVC[jcont]:-NA}" "${OVW[m3]:-NA}" "${OVC[m3]:-NA}" "${OVW[m4]:-NA}" "${OVC[m4]:-NA}"
    printf '# multiple = rival WORK / SCRIP m4 WORK on the SAME instrument (FASTER axis, >1 = SCRIP ahead). CEO-173: OVERHEAD >= 50%% of an arm => basis=TOTAL.\n'
    printf '# ⛔ callgrind Ir REFUSES for the jcont arm (ceo CEO-494): a JVM Ir varies ~35%% run to run. No multiple crosses instruments.\n'
    printf '# verdict: output byte-compared against an iconx cut taken AT RUN TIME. A wrong answer gets no multiple.\n'
    printf 'program\tverdict\ticonx_wall_ms\ticonx_cpu_ms\ticonx_spread_pct\tjcont_wall_ms\tjcont_cpu_ms\tjcont_spread_pct\tm3_wall_ms\tm3_cpu_ms\tm3_spread_pct\tm4_wall_ms\tm4_cpu_ms\tm4_spread_pct\ticonx_WORK_wall\tjcont_WORK_wall\tm4_WORK_wall\tbasis\tm4_x_vs_iconx\tm4_x_vs_jcont\n'
  } > "$TSV_OUT"
fi

RC=0; N=0
for p in $PROGS; do
  sin="${STDIN[$p]}"; av_args="${ARGS[$p]}"
  # ⛔ m4's declared switches lead the binary's arguments, so a -- ends them before the kernel's own argv (Lon's CEO-1261 convention);
  # m3 takes the kernel's argv after -- always.  The oracle gets NAME.oracle_env and none of SCRIP's switches.
  m4_args="$av_args"; [ -n "${SWS[$p]}" ] && [ -n "$av_args" ] && m4_args="-- $av_args"
  # ---- the oracle, AT RUN TIME, checked against the kernel's own .ref ----
  ix_av="$(build_iconx "$p")"
  if [ -z "$ix_av" ]; then printf '%-9s %-7s  ORACLE-COMPILE-FAILED -- no ground truth, nothing graded\n' "$p" "UNPROVEN"; RC=1; continue; fi
  [ -n "${OENVS[$p]}" ] && ix_av="env ${OENVS[$p]} $ix_av"
  timeout -k 5 "$RUN_TMO" $ix_av $av_args >"$WORK/$p.oracle.out" 2>"$WORK/$p.oracle.err" <"$sin"
  orc=$?
  if [ "$orc" != "0" ]; then printf '%-9s %-7s  ORACLE-RAN-RED rc=%s -- no ground truth, nothing graded\n' "$p" "UNPROVEN" "$orc"; RC=1; continue; fi
  if [ ! -s "$WORK/$p.oracle.out" ]; then
    printf '%-9s %-7s  ORACLE-ANSWER-EMPTY -- nothing to grade; a green here would be two empty files agreeing\n' "$p" "UNPROVEN"; RC=1; continue
  fi
  if ! cmp -s "$WORK/$p.oracle.out" "$CORPUS_SRC/$p.ref"; then
    printf '%-9s %-7s  REF DRIFT -- the oracle run under the kernel'"'"'s own sidecars does not print %s.ref\n' "$p" "UNPROVEN" "$p"; RC=1; continue
  fi
  # ---- build the other engines and grade each against the oracle ----
  jc_av="$(build_jcont "$p")"; m4_av="$(build_m4 "$p")"; m3_av="$(m3_argv "$p")"
  declare -A OUTOK
  for eng in jcont m3 m4; do
    case "$eng" in jcont) av="$jc_av";; m3) av="$m3_av";; m4) av="$m4_av";; esac
    OUTOK[$eng]="-"
    [ -n "$av" ] || { OUTOK[$eng]="BUILDFAIL"; continue; }
    case "$eng" in m3) run_av="$av -- $av_args";; m4) run_av="$av $m4_args";; *) run_av="$av $av_args";; esac
    timeout -k 5 "$RUN_TMO" $run_av >"$WORK/$p.$eng.out" 2>"$WORK/$p.$eng.err" <"$sin"
    erc=$?
    if [ "$erc" != "0" ]; then OUTOK[$eng]="rc=$erc"
    elif cmp -s "$WORK/$p.$eng.out" "$WORK/$p.oracle.out"; then OUTOK[$eng]="PASS"
    else OUTOK[$eng]="DIFF"; fi
  done
  verdict="PASS"; { [ "${OUTOK[m3]}" = PASS ] && [ "${OUTOK[m4]}" = PASS ]; } || { verdict="RED"; RC=1; }
  # ---- timing, only on arms that answered correctly (a wrong answer is never a fast answer) ----
  ixr="$(time_median "$sin" $ix_av $av_args)"
  ix_w="$(echo "$ixr"|awk '{print $1}')"; ix_c="$(echo "$ixr"|awk '{print $2}')"; ix_s="$(echo "$ixr"|awk '{print $3}')"
  jc_w=NA; jc_c=NA; jc_s="-"; if [ "${OUTOK[jcont]}" = PASS ]; then r="$(time_median "$sin" $jc_av $av_args)"; jc_w="$(echo "$r"|awk '{print $1}')"; jc_c="$(echo "$r"|awk '{print $2}')"; jc_s="$(echo "$r"|awk '{print $3}')"; fi
  m3_w=NA; m3_c=NA; m3_s="-"; if [ "${OUTOK[m3]}"    = PASS ]; then r="$(time_median "$sin" $m3_av -- $av_args)"; m3_w="$(echo "$r"|awk '{print $1}')"; m3_c="$(echo "$r"|awk '{print $2}')"; m3_s="$(echo "$r"|awk '{print $3}')"; fi
  m4_w=NA; m4_c=NA; m4_s="-"; if [ "${OUTOK[m4]}"    = PASS ]; then r="$(time_median "$sin" $m4_av $m4_args)"; m4_w="$(echo "$r"|awk '{print $1}')"; m4_c="$(echo "$r"|awk '{print $2}')"; m4_s="$(echo "$r"|awk '{print $3}')"; fi
  # ---- the two-number basis and the CEO-173 refusal, per arm, on WALL ----
  work() { local t="$1" o="$2"; case "$t" in NA|''|*[!0-9]*) echo ""; return;; esac; case "$o" in ''|*[!0-9]*) echo ""; return;; esac; echo $((t - o)); }
  ixw="$(work "$ix_w" "${OVW[iconx]:-}")"; jcw="$(work "$jc_w" "${OVW[jcont]:-}")"; m4w="$(work "$m4_w" "${OVW[m4]:-}")"
  frac() { awk -v o="$1" -v t="$2" 'BEGIN{printf "%d", (t>0? o*100/t : 100)}'; }
  # ⛔⭐⭐ THE INSTRUMENT'S FLOOR IS NAMED PER ROW, BECAUSE FOUR OF THESE SIX PROGRAMS SIT ON IT.
  # /usr/bin/time reports wall to 10 ms, so a 20 ms reading is TWO TICKS and a 10 ms reading is ONE.
  # A multiple built from 20 ms against 40 ms prints as a clean 2.000x and is really "two ticks against
  # four, plus or minus a tick either way" -- which spans 1.5x to 3x. ⭐ The number is not wrong; the
  # PRECISION a bare multiple implies is, and a reader has no way to see it from the multiple alone.
  # So any row where either arm is under QUANT_TICKS ticks is labelled QNT: the figure still prints (the
  # number is the number, ceo CEO-494) and it prints wearing its own error bar. ⛔ The way off this floor
  # is a BIGGER INPUT or a self-timed hook in the program -- never a tighter-looking format.
  quant=""; qfloor=$((TICK_MS * QUANT_TICKS))
  case "$ix_w" in ''|*[!0-9]*) ;; *) [ "$ix_w" -lt "$qfloor" ] && quant="QNT:";; esac
  case "$m4_w" in ''|*[!0-9]*) ;; *) [ "$m4_w" -lt "$qfloor" ] && quant="QNT:";; esac
  basis="-"; mx=" - "; mj=" - "
  if [ -n "$m4w" ] && [ -n "$ixw" ] && [ "$m4w" -gt 0 ] && [ "$ixw" -gt 0 ]; then
    if [ "$(frac "${OVW[m4]:-0}" "$m4_w")" -ge 50 ] || [ "$(frac "${OVW[iconx]:-0}" "$ix_w")" -ge 50 ]; then
      basis="TOTAL"; mx="$quant$(perf_mult "$ix_w" "$m4_w")"
    else basis="WORK"; mx="$quant$(perf_mult "$ixw" "$m4w")"; fi
  fi
  if [ -n "$m4w" ] && [ -n "$jcw" ] && [ "$m4w" -gt 0 ] && [ "$jcw" -gt 0 ]; then
    if [ "$(frac "${OVW[m4]:-0}" "$m4_w")" -ge 50 ] || [ "$(frac "${OVW[jcont]:-0}" "$jc_w")" -ge 50 ]; then
      mj="${quant}TOTAL:$(perf_mult "$jc_w" "$m4_w")"
    else mj="$quant$(perf_mult "$jcw" "$m4w")"; fi
  elif [ "${OUTOK[jcont]}" != PASS ]; then mj="(jcont ${OUTOK[jcont]})"; fi
  case "$verdict" in PASS) ;; *) mx="(m3 ${OUTOK[m3]} m4 ${OUTOK[m4]})"; mj="-";; esac
  printf '%-9s %-7s %10s %10s %8s %10s %10s %8s %10s %10s %8s %10s %10s %8s %8s %14s %14s\n' \
    "$p" "$verdict" "$ix_w" "$ix_c" "$ix_s" "$jc_w" "$jc_c" "$jc_s" "$m3_w" "$m3_c" "$m3_s" "$m4_w" "$m4_c" "$m4_s" "$basis" "$mx" "$mj"
  [ -z "$TSV_OUT" ] || printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$p" "$verdict" "$ix_w" "$ix_c" "$ix_s" "$jc_w" "$jc_c" "$jc_s" "$m3_w" "$m3_c" "$m3_s" "$m4_w" "$m4_c" "$m4_s" "${ixw:-NA}" "${jcw:-NA}" "${m4w:-NA}" "$basis" "$mx" "$mj" >> "$TSV_OUT"
  N=$((N+1))
done
echo "ICON_CLASSIC_BOARD programs=$N of $(echo $PROGS|wc -w) graded"
[ "$N" -gt 0 ] || refuse "no program measured -- a grid of nothing is not a measurement."
exit $RC
