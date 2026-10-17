#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_two_number_ir.sh -- THE TWO-NUMBER (WORK / OVERHEAD) BOARD, MEASURED IN CALLGRIND Ir.
# Row readme-perf-grids-three-angles-all-seven (I26), hq_P 2026-09-03, after ceo's CEO-192 audit
# reopened the row: every README grid must be RE-MEASURED on the two-number basis, tree-labelled.
#
# WHY Ir AND NOT WALL CLOCK -- THIS IS THE WHOLE POINT OF THE SCRIPT, NOT AN OPTIMISATION.
# RULES.md § THE TWO-NUMBER BENCHMARK BASIS wants WORK and OVERHEAD as separate numbers, and CEO-173
# added the refusal that follows from measuring them badly: on a short program the subtraction
# total-minus-overhead is a difference of two similar noisy numbers, so it is dominated by its own
# error bars and can INVERT the verdict. That failure mode is a property of the INSTRUMENT (wall
# clock on a shared box), not of the basis. Callgrind Ir has no such error bars: it counts
# instructions retired, deterministically, and is immune to what else the box is doing.
# ⭐ MEASURED, NOT ASSUMED (hq_P 2026-09-03, this row): three consecutive m3 runs of snocone
# fib_recur returned 34405531 / 34405531 / 34405531 -- byte-identical, and the empty-program probe
# repeated to 2790800 twice. That determinism is what buys the economy: ONE rep is the whole
# measurement, where a wall-clock arm needs best-of-N and still cannot separate a 5% engine change
# from a 5% neighbour on the box.  ⛔ It is NOT a wall-clock predictor: Ir counts instructions, not
# cycles, so it cannot see cache misses, branch mispredicts or memory stalls.  It answers "how much
# work does the engine do", which is precisely the question the WORK column asks; it does not answer
# "how long does it take on this box today".  Every grid it feeds says so.
#
# THE OVERHEAD NUMBER: the marked interim of the law -- EMPTY-PROGRAM SUBTRACTION, per engine.
# A do-nothing program in the same language on the same engine is measured once; that Ir is process
# startup (dynamic link, runtime init, teardown) and is the OVERHEAD. WORK = total - overhead.
# ⛔ THE CEO-173 REFUSAL IS IMPLEMENTED HERE AND FIRES ON DATA, NOT ON OPINION: if OVERHEAD is >= 50%
# of the reading on EITHER arm, the WORK multiple is REFUSED for that kernel and the labelled
# TOTAL-basis multiple is printed in its place -- never both, never a work number with a quiet
# asterisk.
#
# EXIT: 0 = board printed, 1 = a kernel was UNPROVEN, 2 = REFUSED (nothing measurable -- an empty or
# plausible table is the failure this guards against, so it never prints one).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$HERE/../../SCRIP/out"
B="$S4E/corpus/benchmarks"
TMO="${IR_TIMEOUT:-600}"
LANG_ARG="${1:-}"
refuse() { echo "⛔ TWO-NUMBER BOARD REFUSED (rc=2): $*" >&2; exit 2; }
[ -n "$LANG_ARG" ] || refuse "usage: bench_two_number_ir.sh <snobol4|snocone|rebus|icon|prolog|pascal|raku>"
[ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN -- a table printed without it would be plausible and false."
command -v valgrind >/dev/null 2>&1 || refuse "valgrind not on PATH."
. "$HERE/lib_ir_measure.sh" 2>/dev/null || refuse "cannot load lib_ir_measure.sh -- this board will not read Ir by hand."
command -v callgrind_annotate >/dev/null 2>&1 || refuse "callgrind_annotate not on PATH."
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || refuse "lib_perf_fmt.sh unloadable -- it is the ONE authority for printing a multiple (s266)."
# CEO-743 welded a load stamp onto every standalone perf_mult/perf_pct. THIS SCRIPT COMPOSES ITS OWN CELLS
# from captured multiples, so the stamp must not land INSIDE a cell -- it is emitted once, above, with the
# shared axes, which is where the FACT RULE says a grid names anything it shares.
PERF_STAMP_OFF=1
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- the ONE oracle-path authority (s200)."
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/two_number.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$WORKDIR"' EXIT
ir_of() {  # $1.. = argv -> echoes PROGRAM TOTALS Ir, or NOTHING if the program did not exit 0
  # ⛔⭐ THE EXIT-STATUS CHECK IS NOT DEFENSIVE PADDING -- IT IS THE WHOLE DIFFERENCE BETWEEN A
  # MEASUREMENT AND A PLAUSIBLE NUMBER, AND IT COST A WRONG BOARD TO LEARN (hq_P, this row).
  # callgrind counts instructions whatever the client does, so a program that PARSE-ERRORS still
  # returns a perfectly well-formed Ir -- the count of its error path. The first run of this script
  # measured Snocone's "empty program" as `END` (valid SNOBOL4, a SYNTAX ERROR in Snocone) and
  # happily reported OVERHEAD=2875710 Ir: a real number, measured correctly, off a program that
  # never ran. Every Snocone WORK figure derived from it would have been silently wrong, and nothing
  # in the output would have said so. valgrind propagates the client's exit code, so requiring 0 is
  # the cheap guard; a non-zero arm returns empty and surfaces as NA/UNPROVEN, never as a number.
  # ⭐ THE CHECK ABOVE IS NOW THE TREE'S RULE, NOT THIS SCRIPT'S HABIT: it lives in lib_ir_measure.sh and
  # every Ir cell in the tree goes through it (hq_P 2026-09-10, on hq_U's ask).  What is added here is the
  # REASON -- a silently empty arm read as `NA` downstream, the same NA printed when valgrind is absent.
  local v; v="$(IR_TMO="$TMO" ir_measure "$@")"
  if ir_is_number "$v"; then echo "$v"; return 0; fi
  echo "⚠ Ir arm voided: $(ir_cell "$v") for [$*] -- $(ir_reason "$v")" >&2
  return 0
}
# ---- per-language adapters ---------------------------------------------------------------------
# Each sets: KDIR EXT RIVAL_NAME; and defines empty_src(), rival_ir(file), plus m3/m4 via SCRIP.
case "$LANG_ARG" in
  snobol4)  KDIR="$B/snobol4"; EXT="sno"; RIVAL_NAME="SPITBOL";;
  snocone)  KDIR="$B/snocone"; EXT="sc";  RIVAL_NAME="SPITBOL (SNOBOL4 twin)";;
  rebus)    KDIR="$B/rebus";   EXT="reb"; RIVAL_NAME="";;
  icon)     KDIR="$B/icon";    EXT="icn"; RIVAL_NAME="Arizona iconx";;
  prolog)   KDIR="$B/prolog";  EXT="pl";  RIVAL_NAME="SWI-Prolog";;
  pascal)   KDIR="$B/pascal";  EXT="pas"; RIVAL_NAME="Free Pascal";;
  raku)     KDIR="$B/raku";    EXT="raku";RIVAL_NAME="Rakudo";;
  *) refuse "unknown language '$LANG_ARG'";;
esac
[ -d "$KDIR" ] || refuse "kernel dir missing: $KDIR"
write_empty() {  # $1 = path
  case "$LANG_ARG" in
    snobol4) printf 'END\n' > "$1";;
    snocone) printf '' > "$1";;   # ⛔ NOT `END` -- that is SNOBOL4 syntax and is a Snocone parse error (verified by execution)
    rebus)   printf '# empty\n' > "$1";;
    icon)    printf 'procedure main()\nend\n' > "$1";;
    prolog)  printf ':- initialization(halt).\n' > "$1";;
    pascal)  printf 'program empty;\nbegin\nend.\n' > "$1";;
    raku)    printf '' > "$1";;
  esac
}
rival_ir() {  # $1 = kernel source path -> Ir on the rival engine, or empty if none/failed
  local f="$1" d
  case "$LANG_ARG" in
    snobol4) ir_of "$(sbl_clean_bin)" $(sbl_lang_flags) "$f" < /dev/null;;
    # ⛔ SNOCONE'S RIVAL IS ITS SNOBOL4 TWIN, NOT THE .sc FILE. SPITBOL cannot parse Snocone syntax, so
    # feeding it "$f" would fail silently and the row would print "(no rival)" -- a plausible, false
    # "Snocone has no rival" where in fact the twin exists. The twin names are the ones
    # bench_triangulate_snocone.sh already committed to (string_concat/arith_loop collide with unrelated
    # pre-existing .sno kernels, hence _twin).
    snocone) local tw; case "$(basename "$f" .sc)" in
               empty) tw="";; fib_recur) tw="fib_recur";; arith_loop) tw="arith_loop_twin";;
               string_concat) tw="string_concat_twin";; *) tw="";; esac
             if [ -z "$tw" ]; then
               # The OVERHEAD probe for the rival arm must be an empty program in the language the
               # RIVAL actually runs -- SNOBOL4 (`END`), not an empty .sc, which SPITBOL cannot parse.
               # Subtracting a SPITBOL startup measured on a program that never parsed would be the
               # same false-number class the ir_of exit guard exists to stop.
               if [ "$(basename "$f")" = "empty.sc" ]; then
                 printf 'END\n' > "$WORKDIR/rival_empty.sno"
                 ir_of "$(sbl_clean_bin)" $(sbl_lang_flags) "$WORKDIR/rival_empty.sno" < /dev/null
               fi
               return 0
             fi
             [ -f "$S4E/corpus/benchmarks/snobol4/$tw.sno" ] || return 0
             ir_of "$(sbl_clean_bin)" $(sbl_lang_flags) "$S4E/corpus/benchmarks/snobol4/$tw.sno" < /dev/null;;
    icon)   d="$(mktemp -d "$WORKDIR/ic.XXXXXX")"; ( cd "$d" && "$(icont_bin)" -o "$d/o.oracle" "$f" ) >/dev/null 2>&1 || return 0
            ir_of "$(iconx_bin)" "$d/o.oracle" < /dev/null;;
    prolog) command -v swipl >/dev/null 2>&1 || return 0; ir_of swipl -q -g true -t halt "$f" < /dev/null;;
    pascal) d="$(mktemp -d "$WORKDIR/pa.XXXXXX")"; command -v fpc >/dev/null 2>&1 || return 0
            ( cd "$d" && cp "$f" k.pas && fpc -Miso -O2 k.pas ) >/dev/null 2>&1 || return 0
            [ -x "$d/k" ] || return 0; ir_of "$d/k" < /dev/null;;
    raku)   command -v raku >/dev/null 2>&1 || return 0; ir_of raku "$f" < /dev/null;;
    rebus)  return 0;;
  esac
}
scrip_m4_ir() {  # $1 = source -> Ir of the linked mode-4 binary
  local f="$1" d; d="$(mktemp -d "$WORKDIR/m4.XXXXXX")"
  "$SCRIP_BIN" --compile "$f" -o "$d/p.s" < /dev/null >/dev/null 2>&1 || return 0
  gcc "$d/p.s" -o "$d/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread >/dev/null 2>&1 || return 0
  ir_of "$d/p.bin" < /dev/null
}
# ---- OVERHEAD: the empty-program constant, measured ONCE per engine -----------------------------
E="$WORKDIR/empty.$EXT"; write_empty "$E"
OVH_M3="$(ir_of "$SCRIP_BIN" --run "$E" < /dev/null)"
OVH_M4="$(scrip_m4_ir "$E")"
OVH_RV="$(rival_ir "$E")"
TREE="$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo '?')"
CORPUS_TREE="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "TWO_NUMBER_IR lang=$LANG_ARG tree=SCRIP $TREE corpus $CORPUS_TREE RT_OPT=-O0 instrument=callgrind-Ir date=$(date -u +%Y-%m-%d)"
echo "  basis: WORK = total Ir - OVERHEAD; OVERHEAD = empty-program subtraction (the marked interim of"
echo "         RULES.md § THE TWO-NUMBER BENCHMARK BASIS). Multiple = rival WORK / SCRIP WORK (FASTER axis)."
echo "  instrument = callgrind Ir at fixed work, which is LOAD-IMMUNE: this board carries no load stamp deliberately,"
echo "         not by omission (CEO-743 requires the stamp on WALL-CLOCK numbers; stamping an Ir board would imply a"
echo "         dependence it does not have). Measured here anyway for the record: $(perf_load_stamp)."
echo "  OVERHEAD (empty program, Ir): m3=${OVH_M3:-n/a}  m4=${OVH_M4:-n/a}  rival=${OVH_RV:-n/a}${RIVAL_NAME:+  [$RIVAL_NAME]}"
printf '%-22s %14s %14s %14s %14s %14s %10s %s\n' kernel m3_total m4_total m4_WORK rival_total rival_WORK basis "x vs ${RIVAL_NAME:-none}"
N=0; RC=0
for f in "$KDIR"/*."$EXT"; do
  [ -f "$f" ] || continue
  k="$(basename "$f" ".$EXT")"
  case "$k" in empty|prelude_*|epilogue_*|*_twin) continue;; esac
  m3="$(ir_of "$SCRIP_BIN" --run "$f" < /dev/null)"
  m4="$(scrip_m4_ir "$f")"
  rv="$(rival_ir "$f")"
  if [ -z "$m4" ] && [ -z "$m3" ]; then printf '%-22s %14s\n' "$k" "UNPROVEN(scrip)"; RC=1; continue; fi
  m4w=""; rvw=""; basis="-"; mult="-"
  if [ -n "$m4" ] && [ -n "${OVH_M4:-}" ]; then m4w=$((m4 - OVH_M4)); fi
  if [ -n "$rv" ] && [ -n "${OVH_RV:-}" ]; then rvw=$((rv - OVH_RV)); fi
  if [ -n "$m4w" ] && [ -n "$rvw" ] && [ "$m4w" -gt 0 ] && [ "$rvw" -gt 0 ]; then
    # ⛔ CEO-173: refuse the WORK multiple when startup is >= 50% of EITHER arm's reading.
    fm4=$(awk -v o="$OVH_M4" -v t="$m4" 'BEGIN{printf "%d", (t>0? o*100/t : 100)}')
    frv=$(awk -v o="$OVH_RV" -v t="$rv" 'BEGIN{printf "%d", (t>0? o*100/t : 100)}')
    if [ "$fm4" -ge 50 ] || [ "$frv" -ge 50 ]; then
      basis="TOTAL"; mult="$(perf_mult "$rv" "$m4")"
    else basis="WORK"; mult="$(perf_mult "$rvw" "$m4w")"; fi
  elif [ -n "$m4w" ]; then basis="WORK"; mult="(no rival)"; fi
  printf '%-22s %14s %14s %14s %14s %14s %10s %s\n' "$k" "${m3:-NA}" "${m4:-NA}" "${m4w:-NA}" "${rv:-NA}" "${rvw:-NA}" "$basis" "$mult"
  N=$((N+1))
done
echo "TWO_NUMBER_BOARD lang=$LANG_ARG kernels=$N"
[ "$N" -gt 0 ] || refuse "no kernel measured -- a grid of nothing is not a measurement."
exit $RC
