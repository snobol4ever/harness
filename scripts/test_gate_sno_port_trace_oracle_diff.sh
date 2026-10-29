#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# stale-binary preflight (same convention as test_gate_icn_port_trace.sh)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_port_trace_oracle_diff.sh -- THE SNOBOL4 PORT-TRACE ORACLE DIFF, against SPITBOL's &FTRACE.
# (seat20 2026-09-05, row fuzz-crash-class-and-port-trace-refs-over-the-three-open-languages, hq_U task.)
#
# test_gate_sno_port_trace.sh is a SELF-CONSISTENCY PIN -- its own header says so: "--cut writes ALL.trace
# from SCRIP's own traces... AN ORACLE DIFF IS POSSIBLE HERE AND IS SIMPLY NOT BUILT YET". This file is
# that missing instrument, built the same way test_gate_icn_port_trace.sh already built it for Icon's
# `&trace := -1`: normalise SCRIP's own port trace AND the real oracle's trace onto the same four-port
# vocabulary and diff them, instead of diffing SCRIP against itself.
#
# WHAT &FTRACE ACTUALLY IS (SPITBOL manual v3.7 p.146-147; MEASURED against the shared correctness oracle,
# /home/resources/x64/bin/sbl -bf, on two scratch witnesses 2026-09-05 before this gate was written).
# Setting `&FTRACE = N` traces every DEFINE'd-function call and return with ZERO further setup -- the same
# "just works" shape as Icon's `&trace`, and UNLIKE bare `&TRACE` (which needs an explicit per-item
# `TRACE(name,type)` call and was MEASURED to print nothing at all when merely assigned a count). A call
# prints `****<stmt>****** NAME(args)`; a successful return prints `****<stmt>****** RETURN NAME = value`;
# a function that reaches FRETURN prints `****<stmt>****** FRETURN NAME` (no value). Nested calls prefix
# an `I`-run (one `I` per depth level) before the message. MEASURED to never emit a third "resumed" kind of
# message: a DEFINE'd function calls and returns exactly once, it is not resumable the way an Icon
# procedure is -- so, like the Icon gate, this instrument never exercises beta and says so rather than
# quietly passing zero beta witnesses off as coverage.
#
# SCRIP SIDE (MEASURED the same session, SCRIP_PL_TRACE=1 on the same two witnesses): every DEFINE'd-
# function invocation compiles to one `n<K>_call NAME` box whose own Call/Exit/Fail bracket the ENTIRE
# body execution 1:1 with &FTRACE's call/return-success/return-failure messages: Call=alpha, Exit=gamma,
# Fail=omega. Confirmed empirically on both a normal return and an FRETURN failure return.
#
# POPULATION: origins of the `ladder` family (corpus/tests/snobol4/ALL.csv -- the SAME population
# test_gate_sno_port_trace.sh already grades) whose extracted source contains the substring `DEFINE(`.
# 12 witnesses as of this mint (both quoting styles present in the corpus, `DEFINE('...')` and
# `DEFINE("...")`, hence a bare substring match rather than a quote-specific one). Computed fresh from
# ALL.csv + a grep every run, never hardcoded -- the same discipline the Icon gate uses for its own
# `suspend` token filter, for the same reason: a hardcoded list rots at the next corpus rename.
#
# NOT COVERED, ON PURPOSE (a known follow-up gap, not a silent omission): FENCE/pattern-internal
# backtracking inside a single MATCH statement is invisible to &FTRACE by construction (it traces
# function-call boundaries, not pattern engine retries), so this instrument can only ever speak to
# DEFINE'd-function call/return topology, never to pattern backtracking. That is the corpus's `ladder`
# self-pin sibling's job, not this one's.
#
# REF: corpus/tests/snobol4/ALL.trace.oracle -- deliberately NOT ALL.trace, which the self-pin sibling
# above already owns; the two gates' --cut must never collide.
# runtime_call NAME is the port event of a DEFINE'd function the RUNTIME enters, a TRACE callback (rt_pl_port_trace_cb, core.c): it has no call-site box, and sbl's &FTRACE traces it as a call.
# TWO MEASURED CORRECTIONS (hq_snobol4 2026-10-15): (1) oracle_map read RETURN and FRETURN but not NRETURN, so `NRETURN NM = .M` was dropped and every
# witness with a name-returning function read ONE event short (rung18 value_traces..., rung19 ftrace_return_types, rung32 ...); NRETURN is a gamma.
# (2) a witness that sets its own `&FTRACE = N` (rung19 ftrace_decrements_and_stops_at_zero sets 2) truncates the ORACLE to N events while SCRIP's
# port trace is unbudgeted, so the oracle run rewrites the witness's budget to the prepended 100000 -- the budget is the rungs suite's, graded by ref.
# A witness whose oracle trace is empty is cut as `total=0` when sbl ran it (rung17_trace_types_all defines F and never calls it); the cut refuses
# only when sbl traced nothing across the whole population.
# EXIT: 0 every witness's alpha/gamma/omega sequence matches the oracle in both modes; 1 a mismatch or a
# perturbation/killswitch failure; 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CUT=0; for a in "$@"; do [ "$a" = --cut ] && CUT=1; done
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RUNGS_DIR="$S4E/corpus/tests/snobol4"; RUNGS_EXT=.sno; export RUNGS_DIR RUNGS_EXT
REF="$RUNGS_DIR/ALL.trace.oracle"; T="${TIMEOUT:-20}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$RUNGS_DIR/ALL.sno" "SNOBOL4 rungs suite"
gate_require "$RUNGS_DIR/ALL.csv" "SNOBOL4 rungs suite index"
[ "$CUT" = 1 ] || gate_require "$REF" "oracle trace refs (run with --cut to create them)"
. "$HERE/lib_rungs_extract.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot source lib_rungs_extract.sh"; exit 2; }
if [ "$CUT" = 1 ]; then
  . "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
  SBL="$(sbl_correctness_bin)" || exit 2
  LANGFLAGS="$(sbl_lang_flags)"
fi
origins=""
for o in $(rungs_origins_of_family ladder); do
  wtmp="$(mktemp -d)"
  rungs_extract_origin "$o" "$wtmp/x.sno" "$wtmp/x.ref" >/dev/null 2>&1 && grep -q 'DEFINE(' "$wtmp/x.sno" 2>/dev/null && origins="$origins $o"
  rm -rf "$wtmp"
done
[ -n "${origins# }" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no DEFINE-containing ladder origins in $RUNGS_DIR/ALL.csv -- the population moved, re-derive it, never hardcode a list"; gate_stamp; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔⭐ `n<K>_call` IS NOT A USER-FUNCTION-ONLY BOX FAMILY -- MEASURED 2026-09-05, three of the twelve
# witnesses (array_arg_implicit_reference, call_by_name_swap, returns_pattern_for_match): it ALSO fires
# for the builtin ARRAY() constructor and for SCRIP-internal desugaring calls (SNO$NAME for the `.`/`$`
# indirection operators, SNO$MKPAT for building a BREAK(...)-style pattern), none of which &FTRACE traces
# -- the manual is explicit that it fires only for PROGRAM-DEFINED functions. A population filter on box
# family ALONE therefore over-counts; this is the same shape as Icon's gate needing to scope to `proc_gen`
# specifically rather than "every box downstream of a call". The fix is symmetric with how the population
# is already chosen: derive the DEFINE'd name set from the SAME witness source and require the call box's
# own NAME to be one of them, discarding SNO$*/builtin calls that happen to share the box family.
define_names_of() {  # $1 = source file -> NAME1|NAME2|... (DEFINE'd function names, either quote style)
  grep -oE "DEFINE\([\"'][A-Za-z_][A-Za-z0-9_]*" "$1" | sed -E "s/^DEFINE\([\"']//" | sort -u | paste -sd'|' -
}
scrip_trace_norm() {  # $1=raw trace file  $2=NAME1|NAME2|... (DEFINE'd names only, from define_names_of)
  grep -E ': (n[0-9]+_call|runtime_call) ' "$1" \
    | sed -E 's/^.*(Call|Exit|Fail): (n[0-9]+_call|runtime_call) ([^ ]+).*$/\1 \3/' \
    | sed -E 's/^Call /alpha /; s/^Exit /gamma /; s/^Fail /omega /' \
    | grep -E "^(alpha|gamma|omega) ($2)\$"
}
# ⛔ THE TWO-STAGE PIPE IS LOAD-BEARING: the first sed REWRITES matching trace lines and leaves every other
# line (ordinary program OUTPUT, since &FTRACE and OUTPUT share one stream -- manual p.146) UNTOUCHED; the
# second, separate `sed -n` is what actually DROPS those untouched lines. Folding this into one sed -n
# script would silently print nothing for the (common) case of a witness whose OUTPUT lines happen not to
# get rewritten -- i.e. every witness -- so the split is not a style choice.
# ⛔ THE DEPTH MARKER IS LOWERCASE 'i'/'ii'/'iii'... ON THE REAL ORACLE -- MEASURED 2026-09-05 on a live
# recursive witness (FACT(5), 5 deep: "****4******* iiii FACT(1)"); the manual excerpt this gate's header
# cites shows uppercase 'I'/'II'. Trusting the manual's case over the live binary silently dropped every
# nested call/return line (an uppercase-only `I*` does not match 'i', so the whole substitution missed and
# the line fell through unrewritten, then got filtered out downstream) -- FACT(5) read as 2 events instead
# of the real 10 the first time this gate was run. Fixed here to accept either case; if a future SPITBOL
# rebuild changes it again, a recursive witness's total dropping back to 2 is the tripwire.
oracle_map() {
  sed -E '
    s/^\*+[0-9]+\*+[[:space:]]*[iI]*[[:space:]]*N?RETURN[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*$/gamma \1/
    s/^\*+[0-9]+\*+[[:space:]]*[iI]*[[:space:]]*FRETURN[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$/omega \1/
    s/^\*+[0-9]+\*+[[:space:]]*[iI]*[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)\(.*\)[[:space:]]*$/alpha \1/
  ' | sed -nE '/^(alpha|gamma|omega) /p'
}
oracle_trace_for() {
  local src="$1" wd rc=0
  wd="$(mktemp -d)"
  { echo "        &FTRACE = 100000"; sed -E 's/&FTRACE[[:space:]]*=[[:space:]]*[0-9]+/\&FTRACE = 100000/' "$src"; } > "$wd/f.sno"
  ( cd "$wd" && timeout -k 5 "$T" "$SBL" $LANGFLAGS f.sno ) < /dev/null > "$wd/raw.out" 2>&1; rc=$?
  oracle_map < "$wd/raw.out"
  rm -rf "$wd"; return $rc
}
m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
refblock() { awk -v o="$1" '$0 ~ "^%---- " o " " {on=1; next} /^%---- /{on=0} on' "$REF"; }
refmeta()  { grep -E "^%---- $1 " "$REF" | head -1 | sed -E 's/.* total=([0-9]+).*/\1/'; }
n=0; bad=0; ans_ok=0; ans_red=0; oracle_sum=0; declare -a lines
[ "$CUT" = 1 ] && : > "$W/ALL.trace.oracle"
for o in $origins; do
  n=$((n+1)); src="$W/$o.sno"; ref="$W/$o.ref"
  rungs_extract_origin "$o" "$src" "$ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot extract $o from the rungs suite"; gate_stamp; exit 2; }
  NAMES="$(define_names_of "$src")"
  [ -n "$NAMES" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o: no DEFINE'd name could be parsed back out of its own extracted source"; gate_stamp; exit 2; }
  (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --out="$o.s0" "$src" </dev/null >/dev/null 2>&1); (cd "$W" && SCRIP_PL_TRACE=0 timeout -k 5 "$T" "$SCRIP" --compile --out="$o.s0b" "$src" </dev/null >/dev/null 2>&1)
  (cd "$W" && SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$SCRIP" --compile --out="$o.s1" "$src" </dev/null >/dev/null 2>&1)
  ks=OK; { cmp -s "$W/$o.s0" "$W/$o.s0b" && [ -s "$W/$o.s0" ] && ! cmp -s "$W/$o.s0" "$W/$o.s1"; } || { ks=FAIL; bad=$((bad+1)); }
  timeout -k 5 "$T" "$SCRIP" --run "$src" </dev/null >"$W/$o.m3.out0" 2>/dev/null; r30=$?
  SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$SCRIP" --run "$src" </dev/null >"$W/$o.m3.out1" 2>"$W/$o.m3.raw"; r31=$?
  pert3=OK; { [ "$r30" = "$r31" ] && cmp -s "$W/$o.m3.out0" "$W/$o.m3.out1"; } || { pert3=FAIL; bad=$((bad+1)); }
  pert4=OK
  if m4build "$W/$o.s0" "$W/$o.bin0" && m4build "$W/$o.s1" "$W/$o.bin1"; then
    timeout -k 5 "$T" "$W/$o.bin0" </dev/null >"$W/$o.m4.out0" 2>/dev/null; r40=$?
    SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$W/$o.bin1" </dev/null >"$W/$o.m4.out1" 2>"$W/$o.m4.raw"; r41=$?
    { [ "$r40" = "$r41" ] && cmp -s "$W/$o.m4.out0" "$W/$o.m4.out1"; } || { pert4=FAIL; bad=$((bad+1)); }
  else pert4=NOBUILD; bad=$((bad+1)); : > "$W/$o.m4.raw"; fi
  cmp -s "$W/$o.m3.out0" "$ref" && { ans=ok; ans_ok=$((ans_ok+1)); } || { ans=RED; ans_red=$((ans_red+1)); }
  scrip_trace_norm "$W/$o.m3.raw" "$NAMES" > "$W/$o.m3.norm"
  scrip_trace_norm "$W/$o.m4.raw" "$NAMES" > "$W/$o.m4.norm"
  for m in m3 m4; do
    fired=$(grep -cE '^\([0-9]+\) [0-9]+ (Call|Redo|Exit|Fail): ' "$W/$o.$m.raw")
    [ "$fired" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o $m: SCRIP_PL_TRACE=1 produced ZERO port events of any box -- the instrument is not firing, this is not 'no ports'"; gate_stamp; exit 2; }
  done
  if [ "$CUT" = 1 ]; then
    oracle_trace_for "$src" > "$W/$o.oracle.norm"; orc=$?
    otot=$(wc -l < "$W/$o.oracle.norm")
    [ "$otot" -gt 0 ] || [ "$orc" -eq 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o: sbl exited rc=$orc with ZERO normalised &FTRACE lines -- it did not run the witness, cannot cut a ref from that"; gate_stamp; exit 2; }
    oracle_sum=$((oracle_sum + otot))
    { echo "%---- $o total=$otot"; cat "$W/$o.oracle.norm"; } >> "$W/ALL.trace.oracle"
    tr3=CUT; tr4=CUT
  else
    rt="$(refmeta "$o")"
    for m in m3 m4; do
      total=$(wc -l < "$W/$o.$m.norm")
      if [ -z "$rt" ]; then v=NOREF; bad=$((bad+1))
      elif [ "$rt" != "$total" ]; then v="FAIL(total $total != ref $rt)"; bad=$((bad+1))
      elif ! refblock "$o" | cmp -s - "$W/$o.$m.norm"; then v="FAIL(diff)"; bad=$((bad+1)); refblock "$o" | diff - "$W/$o.$m.norm" | head -6 | sed 's/^/        /' > "$W/$o.$m.diff"
      else v="ok($total)"; fi
      [ "$m" = m3 ] && tr3="$v" || tr4="$v"
    done
  fi
  lines+=("$(printf '%-30s killswitch=%-4s perturb m3=%-4s m4=%-7s trace m3=%-16s m4=%-16s answer=%s' "$o" "$ks" "$pert3" "$pert4" "$tr3" "$tr4" "$ans")")
  for m in m3 m4; do [ -f "$W/$o.$m.diff" ] && lines+=("$(cat "$W/$o.$m.diff")"); done
done
printf '%s\n' "${lines[@]}"
if [ "$CUT" = 1 ]; then [ "$oracle_sum" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl's &FTRACE traced ZERO calls across the whole population -- the oracle instrument is not firing, no ref is cut"; gate_stamp; exit 2; }; cp "$W/ALL.trace.oracle" "$REF"; echo "refs CUT -> $REF ($(grep -c '^%---- ' "$REF") blocks)"; fi
echo "witnesses=$n (DEFINE-containing ladder origins) modes=2 (m3 --run, m4 --compile+as+gcc) . answer ok=$ans_ok red=$ans_red (informational: the rungs suite owns answers) . oracle=SPITBOL &FTRACE, Call/RETURN/FRETURN -> alpha/gamma/omega, statement numbers and nesting depth stripped, never beta (DEFINE'd functions call/return exactly once)"
GATE_EXAMINED=$((n*2)); gate_verdict "$bad" "failed checks across killswitch/perturbation/trace"
