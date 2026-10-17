#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_vanroy.sh — PL-SPEED-0 MEASUREMENT RAIL (van Roy loop harness).
# Per-iteration compute (ms) for GNU (gprolog consult) · SWI (swipl) · SCRIP m3
# (--run) · SCRIP m4 (compiled binary), each bench looped via the PROVEN
# rename-wrapper shape (FINDING-2026-07-10):
#   sed 's/^main :-/bench__main :-/'  +  appended  main :- l__(N).  recursion loop.
# N is AUTO-RANGED PER ENGINE (doubling until wall-floor >= MIN_WALL_MS, cap NMAX),
# so fast engines get big N (precision) and slow ones small N (bounded wall);
# per-iteration ms = (wall - engine startup floor) / N, which is N-independent at
# ⛔ RETIRED PATH: that board also left its gprolog-calibrated wrapper in VANROY_DIR as a checked-in artifact. Both the
# board and the directory are gone (CEO-567); see the note at the foot of this file. What remains here is --two-number (the
# 21-kernel bucket board) and --measured-from (its rule check), neither of which writes anything.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
NTSV="${NTSV:-$S4E/corpus/benchmarks/prolog/fixed-iter-n.tsv}"   # the 21-kernel universe, since vanroy/ retired (CEO-567)
T="${TIMEOUT:-240}"; MIN_WALL_MS="${MIN_WALL_MS:-300}"; NMAX="${NMAX:-65536}"
# ⭐ THE TWO AUTHORITIES, SOURCED NOT REIMPLEMENTED: lib_oracle_flags.sh owns WHICH BINARY IS THE RIVAL
# (swipl_bin/gprolog_bin, loud rc=2 refusal when absent) and lib_perf_fmt.sh owns HOW A MULTIPLE IS PRINTED
# (perf_mult/perf_row, reference/ours, RED below 1.00x). ⛔ A harness that cannot load them REFUSES rather
# than inventing a format or a path -- RULES.md FACT RULES.
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot source lib_oracle_flags.sh"; exit 2; }
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot source lib_perf_fmt.sh";     exit 2; }
TWO_NUMBER=0; RULECHECK=; for a in "$@"; do [ "$a" = --two-number ] && TWO_NUMBER=1; done
# ⭐ --measured-from <tri.tsv> : print the bucket rule's INPUT-TO-OUTPUT decision for one triangulation file and exit.
# It exists so test_gate_vanroy_bucket_rule.sh can grade THE REAL SELECTION CODE against fixtures instead of restating
# the awk in the test -- a gate that reimplements the rule it guards proves the two copies agree, never that either is
# right. It is a PURE function of the TSV, so it deliberately runs BEFORE the built-binary and oracle guards below:
# demanding a compiler and two rival engines to answer a question about a text file is how a cheap check becomes one
# nobody runs.
for i in $(seq $#); do [ "${!i}" = --measured-from ] && { j=$((i+1)); RULECHECK="${!j}"; }; done
# THE SCRIP ROWS RUN AT EACH KERNEL'S DECLARED HEAP AND STACK: TN_DECL holds lib_declared_arena.sh's -d<kb>k -s<kb>k for the kernel
#   in hand, set by tn_decl before every SCRIP run (RULES.md clause 8 (g), CEO-1353). Until 2026-10-01 this line was ulimit -s unlimited
#   and SCRIP got nothing, so tak (declared 65536 KB) overflowed at the 4 MB default. MEASURED 2026-10-01 at c1c899df3: all 23 kernels
#   read the same on gprolog, swipl, m3 and m4 at the shell's soft 8 MB stack and at unlimited.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot source lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars"; exit 2; }
declare -a TN_DECL=()
tn_decl() { TN_DECL=(); local dw; dw=$(declared_switches_beside "$1") || { echo "⛔ REFUSED-TO-GRADE (rc=2): $(basename "$1"): a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && read -r -a TN_DECL <<<"$dw"; [ "${2:-}" = --quiet ] || undeclared_beside_named "$1" || true; }
if [ -z "$RULECHECK" ]; then
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing: $B"; exit 2; }
fi
# ⛔ LEGACY PATH ONLY. `command -v` is forbidden on the --two-number path (row prolog-vanroy-21-board-two-number-basis):
# it resolves a bare name on PATH, which is the exact fallback lib_oracle_flags.sh exists to refuse. Left in place for
# the legacy per-iteration board rather than changed under it, so this row's diff is the new path, not a silent
# re-basing of numbers nobody re-measured.
if [ "$TWO_NUMBER" -eq 0 ] && [ -z "$RULECHECK" ]; then
gprolog_bin >/dev/null || exit 2
command -v swipl   >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE swipl absent"; exit 2; }
fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
now_ms() { echo $(( $(date +%s%N) / 1000000 )); }
# ⛔⛔ THE BUCKET RULE'S ONE IMPLEMENTATION. Both the board and its gate call THESE -- never a second awk.
# tn_rivals: the engines that form the comparison axis, DERIVED FROM THE DATA. ⛔ SCRIP's own mode rows (m3/m4, and
# any future m<N>) are excluded on purpose: bench_triangulate_prolog.sh's header pins them UNPROVEN for every kernel by
# a known compiler defect (PZ-4 -- a named var bound by a user-predicate call plus one more goal, re-entered by
# backtracking), not by disagreement. They are the subject being measured, not the axis measuring it; gating on them
# pins MEASURED at 0 until PZ-4 lands, and a bucket that can never fill is a broken instrument, not a strict one.
tn_rivals() { awk -F'\t' 'NR>2 && $2!~/^m[0-9]+$/ && NF{print $2}' "$1" | sort -u; }
# tn_measured_kernels: a kernel is MEASURED only when it carries an AGREE row for EVERY rival -- not >=1 (hq_B ruling
# 2026-09-01). ⛔⛔ IDENTITY-KEYED ON COLUMN 6, NEVER `grep AGREE`: AGREE IS A SUBSTRING OF DISAGREE, and that one
# substring is where this row's GOAL got "the 6 that pass" (grep says 6; the verdict column says 4 AGREE + 2 DISAGREE,
# spanning 2 kernels). The dedupe guard makes a duplicated kernel,engine row unable to fake a full house.
tn_measured_kernels() { awk -F'\t' -v nriv="$2" 'NR>2 && $2!~/^m[0-9]+$/ && $6=="AGREE" && !seen[$1"\t"$2]++{c[$1]++} END{for(k in c) if(c[k]==nriv) print k}' "$1" | sort -u; }
# ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# --two-number : THE VAN ROY 21-KERNEL BOARD ON THE TWO-NUMBER BASIS (row prolog-vanroy-21-board-two-number-basis).
# ⛔ An EXTENSION, not a fourth harness (the row's GOAL is explicit: "extend, do not fork"). Everything above this line
# is the legacy per-iteration path and is untouched: it still runs whenever --two-number is absent.
# BASIS: RULES.md § THE TWO-NUMBER BENCHMARK BASIS (Lon 2026-08-30) -- WORK is the program's own bracketed
# wall_us/wall_ms delta printed to user_error; OVERHEAD is (external total - WORK) and is its own number, never a
# WORK column. Multiples are reference/ours through lib_perf_fmt.sh, the one authority for printing a multiple.
# ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
tn_work_us() {   # tn_work_us <engine> <src> -> work_us, or "-" when the kernel did not report one
  local eng="$1" src="$2" out=""
  case "$eng" in
    scrip) out=$( (cd "$W" && timeout -k 5 "$TN_T" "$SCRIP" --run "${TN_DECL[@]}" "$src" </dev/null 2>&1 >/dev/null) ) ;;
    gnu)   out=$( (cd "$W" && timeout -k 5 "$TN_T" "$TN_GP" --consult-file "$TN_PRO/prelude_gplc.pl" --consult-file "$src" --query-goal halt </dev/null 2>&1 >/dev/null) ) ;;
    swi)   out=$( (cd "$W" && timeout -k 5 "$TN_T" "$TN_SW" -g true "$TN_PRO/prelude_swipl.pl" "$src" </dev/null 2>&1 >/dev/null) ) ;;
  esac
  local v; v=$(printf '%s\n' "$out" | sed -n 's/.*work_us=\([0-9][0-9]*\).*/\1/p' | head -1)
  # ⛔⭐ A RIVAL READING OF 0 IS NOT A MEASUREMENT, IT IS "BELOW THE FLOOR" -- AND THE FIRST RUN OF THIS BOARD
  # PRINTED IT AS 0, WHICH perf_mult THEN TURNED INTO "0.000x" FOR deriv-vs-gprolog: a fabricated multiple that
  # reads exactly like a measured one. gprolog real_time/1 and swipl statistics(walltime) are 1 ms sources, so any
  # sub-millisecond kernel yields a 0-TICK DELTA. The preludes already warned ("Reporting a 1 ms floor honestly
  # costs less than defending a multiple built on three ticks") and the board printed the zero anyway. Sentinel it,
  # and let the caller refuse to build a ratio on it -- a number that cannot be measured must say so, never resolve
  # to a plausible value (RULES.md THE INSTRUMENT LAWS).
  case "$eng" in gnu|swi) [ "${v:-0}" -eq 0 ] 2>/dev/null && { printf '%s' "<1ms"; return; } ;; esac
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' -
}
# ⛔ THE ONE GATE BETWEEN A SUB-FLOOR READING AND A PUBLISHED MULTIPLE. Never call perf_row directly on a rival
# number that may be "<1ms": a multiple over a 0-tick denominator is arithmetic, not evidence.
tn_angle() {
  local k="$1" rival="$2" ref="$3" ours="$4"
  case "$ref" in
    -)     printf '  %-34s %14s %14s   %s\n' "$k -- vs $rival (WORK)" "n/a" "$ours" "UNPROVEN (rival produced no work bracket)" ;;
    "<1ms") printf '  %-34s %14s %14s   %s\n' "$k -- vs $rival (WORK)" "<1ms" "$ours" "⛔ NO MULTIPLE: rival is under its 1 ms floor -- 0 ticks is not a measurement" ;;
    *)     perf_row "$k -- vs $rival (WORK)" "$ref" "$ours" ;;
  esac
}
tn_total_ms() { local t0 t1; t0=$(now_ms); ( "$@" </dev/null >/dev/null 2>&1 ); t1=$(now_ms); echo $((t1-t0)); }
# ⛔ OVERHEAD IS MEASURED ON THE SAME KERNEL AS THE WORK IT IS SUBTRACTED FROM, never on a different program:
# (external total) - (that run's own reported work). Mixing a floor from an empty program into a self-timed row is
# exactly what RULES.md's basis ruling forbids -- empty-program subtraction is the marked INTERIM, not the basis.
tn_overhead_line() {
  local label="$1" eng="$2" src="$3" tot w
  case "$eng" in
    scrip) tot=$(tn_total_ms "$SCRIP" --run "${TN_DECL[@]}" "$src") ;;
    gnu)   tot=$(tn_total_ms "$TN_GP" --consult-file "$TN_PRO/prelude_gplc.pl" --consult-file "$src" --query-goal halt) ;;
    swi)   tot=$(tn_total_ms "$TN_SW" -g true "$TN_PRO/prelude_swipl.pl" "$src") ;;
  esac
  w=$(tn_work_us "$eng" "$src")
  if [ "$w" = - ]; then printf '  %-10s total=%sms work=n/a  overhead=UNPROVEN (kernel reported no work bracket)\n' "$label" "$tot"
  else awk -v l="$label" -v t="$tot" -v u="$w" 'BEGIN{ printf "  %-10s total=%dms  work=%.1fms  overhead=%.1fms (startup+teardown)\n", l, t, u/1000, t-(u/1000) }'; fi
}
two_number_board() {
  # ── oracles BY ACCESSOR ONLY. ⛔ The legacy path above uses `command -v`; the GOAL forbids it here, and the reason
  # is in the accessor's own message: a rival measured with the binary absent is not slow, it is ABSENT, and a column
  # filled anyway is a false number. Missing rival => rc=2 REFUSAL, never a plausible all-fail grid.
  TN_GP="$(gprolog_bin)" || { echo "⛔ REFUSED-TO-GRADE (rc=2): gprolog rival absent"; return 2; }
  TN_SW="$(swipl_bin)"   || { echo "⛔ REFUSED-TO-GRADE (rc=2): swipl rival absent";   return 2; }
  [ -x "$SCRIP" ]             || { echo "⛔ REFUSED-TO-GRADE (rc=2): scrip not built";        return 2; }
  [ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): libscrip_rt.so missing"; return 2; }
  # The population is PROLOG_DIR and BENCH_DIR, as in the three sibling angles (the coo 2026-10-03: this read $S4E's corpus alone while
  # NTSV was honoured, so a scratch kernel set named its kernels from one tree and their sources from another).
  TN_PRO="${PROLOG_DIR:-$S4E/corpus/benchmarks/prolog}"; TN_BENCH="${BENCH_DIR:-$TN_PRO/bench}"; TN_T="${TN_T:-25}"
  local TRI EXC; TRI="$(ls -1t "$TN_PRO"/triangulation-*.tsv 2>/dev/null | head -1)"; EXC="$TN_PRO/EXCLUDED.tsv"
  [ -s "$NTSV" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): committed-N table missing or empty: $NTSV -- the 21-kernel universe has no source"; return 2; }
  [ -n "$TRI" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): no triangulation-*.tsv -- MEASURED has no source"; return 2; }
  [ -f "$EXC" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): EXCLUDED.tsv missing -- DECLARED has no source"; return 2; }
  # ── THE UNIVERSE IS vanroy/ (21); THE SOURCES ARE bench/ (23). Measured 2026-09-01: 0 of 21 vanroy files carry a
  # wall_ms bracket and 10 of 23 bench files do -- vanroy/*.pl are mkwrap OUTPUTS the legacy path regenerates, not
  # kernels. So names come from vanroy, source text from bench. ⛔ Do not let the two directories blur.
  # ⛔⭐ THE UNIVERSE MOVED FROM A DIRECTORY OF GENERATED FILES TO A COMMITTED TABLE (hq_P 2026-09-13, CEO-567): it was
  # `ls vanroy/*.pl`, i.e. the denominator was a property of a DERIVED ARTIFACT. Same 21 names, verified identical by diff at
  # the retirement; test_gate_bench_rivals_coverage.sh reads the same table, so the two boards cannot drift apart.
  local KERNELS NK; KERNELS=$(awk -F'\t' '!/^[[:space:]]*#/ && NF && $1 != "kernel" { print $1 }' "$NTSV" | sort)
  NK=$(printf '%s\n' "$KERNELS" | grep -c .)
  # ── MEASURED, IDENTITY-KEYED ON COLUMN 6. ⛔⛔ NEVER `grep AGREE`: AGREE IS A SUBSTRING OF DISAGREE. That one
  # substring is where this row's GOAL got "the 6 that pass" -- grep -c says 6; the verdict column says 4 AGREE +
  # 2 DISAGREE, and those 4 are kernel,engine PAIRS spanning only 2 kernels (deriv, fib).
  # ⛔⭐ AND "AGREE" IS PER KERNEL ONLY WHEN EVERY *RIVAL* ENGINE THE GRID PUBLISHES AGREES -- NOT >=1 (hq_B ruling
  # 2026-09-01, implemented 2026-09-01 with the fixture that proves the difference: test_gate_vanroy_bucket_rule.sh).
  # A kernel promoted on ONE rival while the other rival disagreed is a board citing its friendliest number, which is
  # the same defect as `grep AGREE` wearing better manners.
  # ⛔⛔ "RIVAL" IS LOAD-BEARING, AND THE LITERAL ALL-ENGINES READING IS A TRAP THAT ZEROES THIS BOARD. The grid
  # publishes FOUR engines -- gnu swi m3 m4 -- and m3/m4 are UNPROVEN for EVERY kernel BY CONSTRUCTION, not by
  # disagreement: bench_triangulate_prolog.sh's own header pins the cause (a named var bound by a user-predicate call
  # plus one more goal, re-entered by backtracking, "stack smashing detected" -- GOAL-PROLOG-100.md PZ-4), and every
  # vanroy kernel is exactly that shape, so all 21 crash at once. Gating promotion on SCRIP's own mode rows therefore
  # makes MEASURED permanently 0 until PZ-4 lands -- a bucket that can never fill is not strictness, it is a broken
  # instrument. SCRIP's modes are the thing being MEASURED; the rivals are the axis that decides whether the
  # measurement is trustworthy. Self-rows stay UNPROVEN and visible, and are never allowed to veto a rival verdict.
  # ⭐ THE RIVAL SET IS DERIVED FROM THE DATA, never a hardcoded pair, so adding a third rival tightens this
  # automatically instead of silently keeping a two-engine rule under a three-engine grid.
  local MEAS DECL RIVALS NRIV
  RIVALS=$(tn_rivals "$TRI"); NRIV=$(printf '%s\n' "$RIVALS" | grep -c .)
  [ "$NRIV" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): triangulation publishes no rival engine -- MEASURED has no axis"; return 2; }
  MEAS=$(tn_measured_kernels "$TRI" "$NRIV")
  DECL=$(grep -v '^#' "$EXC" | awk -F'\t' 'NF{print $1}' | sort -u)
  echo "VAN ROY 21-KERNEL BOARD -- TWO-NUMBER BASIS"
  echo "BASIS: WORK = the kernel's own wall_us(T0)/wall_us(T1) delta, printed to user_error so stdout stays"
  echo "       byte-comparable and every .ref still verifies. OVERHEAD = external total - WORK, per engine."
  echo "       Multiples are reference/ours via lib_perf_fmt.sh (RED below 1.00x, GREEN at or above). One axis."
  echo "⛔ PRECISION IS NOT UNIFORM AND IS NOT PAPERED OVER: gprolog real_time and swipl statistics(walltime) are"
  echo "   1 ms sources, so a rival work_us is that many WHOLE TICKS x1000, not a us measurement. SCRIP's wall_us"
  echo "   is genuinely us-backed. A us-precise numerator over a ms-quantized denominator is stated, never hidden."
  echo "⛔ BUCKETS PARTITION, PRECEDENCE MEASURED > REFUSE > DECLARED: a crash that is UNDERSTOOD is still a crash,"
  echo "   so a checked EXCLUDED reason never converts a red into an excuse (hq_B ruling 2026-09-01, ask CLOSED)."
  echo "⛔ MEASURED REQUIRES EVERY RIVAL ENGINE TO AGREE, NOT ONE: rivals=[$(echo $RIVALS)] ($NRIV of them)."
  echo "   SCRIP's own m3/m4 rows are UNPROVEN by a known compiler defect (PZ-4), not by disagreement, so they are"
  echo "   printed by the triangulator but never gate promotion -- gating on them would pin MEASURED at 0 forever."
  echo "SHARED AXES: instrument=wall clock · RT_OPT=-O0 · mode=m3 · basis printed PER ROW (SELF|FLOOR, never mixed)"
  echo "TREE: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null) triangulation=$(basename "$TRI") kernels=$NK"
  echo
  printf '%-9s %-13s %-6s %11s %11s %11s   %s\n' BUCKET KERNEL BASIS SCRIP_us GNU_us SWI_us NOTE
  local k src bucket basis note rc us_s us_g us_w n_meas=0 n_decl=0 n_ref=0 n_rows=0
  for k in $KERNELS; do
    src="$TN_BENCH/$k.pl"; tn_decl "$src"
    if grep -q 'wall_us' "$src" 2>/dev/null; then basis=SELF; else basis=FLOOR; fi
    # ⛔ `2>/dev/null` on the subshell does NOT silence this: the "Segmentation fault"/"Aborted" line is printed by
    # THIS shell's job reporting about the dead child, not by the child. Wrapping the compound is what suppresses it
    # -- measured on the first run, where 11 crash notices interleaved with the rows and broke the grid's alignment.
    { ( cd "$W" && timeout -k 5 "$TN_T" "$SCRIP" --run "${TN_DECL[@]}" "$src" </dev/null >/dev/null 2>&1 ); rc=$?; } 2>/dev/null
    us_s=-; us_g=-; us_w=-
    if printf '%s\n' "$MEAS" | grep -qx "$k"; then
      bucket=MEASURED; n_meas=$((n_meas+1)); note="AGREE from all $NRIV rivals in $(basename "$TRI")"
      printf '%s\n' "$DECL" | grep -qx "$k" && note="$note ⛔STALE-DECLARED: EXCLUDED.tsv's own header orders removal"
    elif [ $rc -ne 0 ]; then
      bucket=REFUSE; n_ref=$((n_ref+1))
      case $rc in 139) note="SIGSEGV rc=139 -- printed RED, never dropped" ;; 124) note="TIMEOUT rc=124 at ${TN_T}s" ;; *) note="rc=$rc" ;; esac
      printf '%s\n' "$DECL" | grep -qx "$k" && note="$note (checked EXCLUDED reason exists; still REFUSE)"
    elif printf '%s\n' "$DECL" | grep -qx "$k"; then
      bucket=DECLARED; n_decl=$((n_decl+1)); note="checked reason in EXCLUDED.tsv"
    else
      bucket=REFUSE; n_ref=$((n_ref+1)); note="runs green but lacks an AGREE from every rival -- UNPROVEN, not excused"
    fi
    if [ "$basis" = SELF ] && [ $rc -eq 0 ]; then
      us_s=$(tn_work_us scrip "$src"); us_g=$(tn_work_us gnu "$src"); us_w=$(tn_work_us swi "$src")
    fi
    printf '%-9s %-13s %-6s %11s %11s %11s   %s\n' "$bucket" "$k" "$basis" "$us_s" "$us_g" "$us_w" "$note"
    n_rows=$((n_rows+1))
  done
  echo
  echo "ROWS: $n_rows (MEASURED=$n_meas DECLARED=$n_decl REFUSE=$n_ref) -- every kernel printed, none dropped."
  echo "⛔ BASIS COVERAGE: $(printf '%s\n' "$KERNELS" | while read -r k; do [ -f "$TN_BENCH/$k.pl" ] && grep -ql 'wall_us' "$TN_BENCH/$k.pl" 2>/dev/null && echo x; done | grep -c x) of $NK kernels carry the two-number bracket (SELF);"
  echo "   the rest are FLOOR and have NO self-timed WORK. RULES.md permits empty-program subtraction as a MARKED"
  echo "   INTERIM only -- so their WORK columns print '-' rather than a floor-derived number silently mixed in."
  echo
  echo "ANGLES 1+2 -- x vs each rival on WORK (axis named once: reference/ours; above 1.00x SCRIP is ahead):"
  for k in $(printf '%s\n' "$MEAS"); do
    src="$TN_BENCH/$k.pl"; [ -f "$src" ] || continue; tn_decl "$src" --quiet
    us_s=$(tn_work_us scrip "$src"); us_g=$(tn_work_us gnu "$src"); us_w=$(tn_work_us swi "$src")
    [ "$us_s" = - ] && continue
    tn_angle "$k" gprolog "$us_g" "$us_s"; tn_angle "$k" swipl "$us_w" "$us_s"
  done
  echo
  echo "ANGLE 3 -- OVERHEAD, one line per engine (startup+teardown only, never mixed into a WORK column):"
  local ov_src="$TN_BENCH/fib.pl"; [ -f "$ov_src" ] || ov_src="$(ls -1 "$TN_BENCH"/*.pl | head -1)"
  echo "  (witness: $(basename "$ov_src") -- overhead is per-ENGINE and near-constant, so one kernel states it)"
  tn_decl "$ov_src" --quiet; tn_overhead_line "SCRIP m3" scrip "$ov_src"; tn_overhead_line "gprolog" gnu "$ov_src"; tn_overhead_line "swipl" swi "$ov_src"
  echo
  echo "CONTROL ARM: re-run on the same binary; every bucket assignment and every multiple must reproduce within the"
  echo "             spread recorded in the row's LEDGER. ⛔ An unstated spread is not a control arm."
  return 0
}

if [ -n "$RULECHECK" ]; then
  [ -f "$RULECHECK" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): no such triangulation TSV: $RULECHECK"; exit 2; }
  _rv=$(tn_rivals "$RULECHECK"); _nrv=$(printf '%s\n' "$_rv" | grep -c .)
  [ "$_nrv" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): triangulation publishes no rival engine -- MEASURED has no axis"; exit 2; }
  echo "RIVALS($_nrv): $(echo $_rv)"
  echo "MEASURED: $(echo $(tn_measured_kernels "$RULECHECK" "$_nrv"))"
  exit 0
fi
if [ "$TWO_NUMBER" -eq 1 ]; then two_number_board; exit $?; fi
# ⛔⭐ THE LEGACY PER-ITERATION PRODUCER PATH WAS DELETED HERE (hq_P 2026-09-13, CEO-567, 77 lines: wall_ms/med5/mkwrap/
# auto_range, the startup-floor block and the per-iteration board). IT WAS THE ROOT PRODUCER OF corpus/benchmarks/prolog/vanroy/
# -- its board ended `mkwrap "$pl" "$NG" "$V/$s.pl"   # checked-in driver = gprolog-calibrated wrapper`, which is precisely the
# artifact CEO-567 forbids: the iteration count frozen into the file under measurement, and calibrated to ONE engine at that, so
# every other engine was measured on gprolog's N. Retiring the directory without retiring its producer would have left the next
# run of this script to recreate it. The three angles that replace it all GENERATE their wrapper: angle 1
# test_bench_prolog_timed.sh (live doubling search), angle 2 bench_prolog_fixed_iter.sh (committed N from fixed-iter-n.tsv),
# both through ../harness/scripts/bench_prolog_wrap.sh.
# ⛔ A SECOND REASON NOT TO PRESERVE IT, worth recording because it is a law violation and not a taste question: its ratio
# columns were m4/GNU and m4/SWI computed as OURS/REFERENCE (`a=m4i b=gi; a/b`), so a value BELOW 1.00 meant we were ahead --
# the inverted orientation. RULES.md FACT RULE fixes the multiple as reference/ours on the faster axis, and lib_perf_fmt.sh is
# its one authority. A number carried out of that board into a today's column would have to be re-measured, never converted.
# ⭐ WHAT SURVIVES ABOVE, and why this script is not simply deleted: --two-number is the 21-kernel BUCKET BOARD that
# corpus/benchmarks/prolog/EXCLUDED.tsv names as the authority promoting a kernel to MEASURED, and --measured-from is the pure
# rule-check that test_gate_vanroy_bucket_rule.sh grades against fixtures. Neither writes anything. THE NAME STAYS: "van Roy"
# is the kernel set's PROVENANCE, never the retired directory's.
[ -n "$RULECHECK" ] || [ "$TWO_NUMBER" -eq 1 ] || {
    echo "⛔ REFUSED (rc=2): the legacy per-iteration board is RETIRED (CEO-567) -- it wrote the checked-in wrapped form."
    echo "   Use one of the generating angles instead:"
    echo "     angle 1  bash ../harness/scripts/test_bench_prolog_timed.sh      (live doubling search for N)"
    echo "     angle 2  bash ../harness/scripts/bench_prolog_fixed_iter.sh      (committed N, corpus/benchmarks/prolog/fixed-iter-n.tsv)"
    echo "   This script still serves --two-number (the bucket board) and --measured-from <tri.tsv> (the rule check)."
    exit 2; }
