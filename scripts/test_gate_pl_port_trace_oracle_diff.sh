#!/usr/bin/env bash
# stale-binary preflight (same convention as test_gate_icn_port_trace.sh)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_port_trace_oracle_diff.sh -- THE PROLOG PORT-TRACE ORACLE DIFF, against SWI-Prolog's trace/0.
# (seat20 2026-09-05, row fuzz-crash-class-and-port-trace-refs-over-the-three-open-languages, hq_U task.)
#
# test_gate_pl_port_trace.sh is a SELF-CONSISTENCY PIN, by its own header's admission: "trace/0 emits goal
# events in its own format, not a Byrd four-port sequence over our box graph, so no line-for-line oracle
# diff exists to take." That line is the premise this gate falsifies: Prolog's own textbook 4-port tracer
# uses the EXACT SAME PORT NAMES this codebase's Byrd-box vocabulary was named after -- Call/Redo/Exit/Fail
# IS the Byrd box model, not an analogy to it -- so the "normalisation" is far thinner than Icon's or
# SNOBOL4's: mostly filtering, barely any renaming.
#
# WHY SWI, NOT GNU PROLOG (both are accessible via lib_oracle_flags.sh's swipl_bin/gprolog_bin): MEASURED
# 2026-09-05 on matched scratch witnesses -- swipl's trace/0, with `leash(-all)` to stop it waiting on a
# tty that is not there, writes Call:/Exit:/Redo:/Fail: lines to STDERR and leaves STDOUT carrying only the
# program's real output, cleanly separable exactly like SCRIP's own SCRIP_PL_TRACE convention. gprolog's
# `--consult-file` driver was measured to interleave its banner, compilation messages, trace lines AND
# program output all on ONE stream (stdout) with no separation -- unusable as a "does tracing perturb the
# answer stream" instrument without first solving a harder problem (silencing gprolog's own banner/compile
# noise) that is out of scope for this rung.
#
# ⛔⭐ POPULATION IS ONE HAND-WRITTEN CANARY WITNESS, NOT DRAWN FROM THE RUNGS SUITE -- A DELIBERATE,
# NAMED DEPARTURE FROM EVERY OTHER GATE IN THIS FAMILY, explained in full because a silent one would read
# as an oversight. MEASURED 2026-09-05 on corpus/tests/prolog's own `rung05_backtrack_backtrack` family
# (list_directive_2.pl, a recursive member/2): SCRIP logs ONE Redo event PER ACTIVE STACK FRAME when
# backtracking unwinds through several live recursive calls of the SAME static box at once, where swipl's
# tracer logs a single Redo at the frame where a new alternative is actually tried -- a genuine
# instrumentation-granularity difference (20 SCRIP events vs 17 swipl events on that witness), not a bug in
# either engine, and NOT something a normalisation rule (drop-a-trailing-pair) can safely paper over without
# risking silently swallowing a REAL extra/missing event elsewhere in a multi-frame sequence. Recursive/
# multi-frame backtracking is therefore an EXPLICIT FOLLOW-UP GAP for hq_U, not silently assumed covered --
# the same shape as Icon's gate leaving plain (non-suspend) calls uncovered and saying so.
# The canary below (`color/1`, three facts, driven by an explicit `fail`-loop) isolates the one case that
# IS clean: non-recursive, single-frame, multi-clause backtracking. Even there, ONE named, ONE-DIRECTION
# normalisation is required and applied ONLY to SCRIP's side (see drop_trailing_choicepoint_pair below) --
# unlike Icon's SYMMETRIC trailing-pair drop, because the artifact here is asymmetric by measurement: SCRIP
# always leaves a choice point until a predicate's clauses are truly exhausted (one extra Redo+Fail pair);
# swipl's first-argument/last-clause indexing detects "blue" was the last matching fact and exits `color/1`
# deterministically, so it never emits that pair at all. WITNESSES ONLY, NEVER COMPILER FIXES: this gate
# does not attempt to make SCRIP perform the same choice-point elision -- that would be a compiler change,
# and squarely hq_U's to consider, not this rung's.
#
# NORMALISATION: SCRIP's `n<K>_call_proc_staged NAME/ARITY` box family (MEASURED: user-predicate calls
# only -- built-ins and internal dispatch fire through a DIFFERENT box family, `n<K>_call $unify` /
# `$findall_new` / `$write` / etc., which this filter already excludes just by grepping call_proc_staged
# specifically) maps Call/Redo/Exit/Fail -> alpha/beta/gamma/omega, arity dropped (`color/1` -> `color`) to
# match swipl's own bare-functor trace text once its argument list is dropped too, and the entry predicate
# (`main`, whose own Call/Exit swipl reports as a redo-driven interpreted loop where SCRIP reports a single
# compiled-box in/out -- an architectural difference, not a bug, see the m3/m4 "wiring IS the execution"
# design note in CLAUDE.md) is excluded from BOTH sides by name.
#
# REF: corpus/tests/prolog/ALL.trace.oracle -- deliberately NOT ALL.trace, which the self-pin sibling above
# already owns.
# EXIT: 0 the canary's alpha/beta/gamma sequence matches the oracle in both modes; 1 a mismatch or a
# perturbation/killswitch failure; 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CUT=0; for a in "$@"; do [ "$a" = --cut ] && CUT=1; done
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RUNGS_DIR="$S4E/corpus/tests/prolog"
REF="$RUNGS_DIR/ALL.trace.oracle"; T="${TIMEOUT:-20}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$RUNGS_DIR" "Prolog corpus dir (only used to co-locate the ref beside its self-pin sibling)"
[ "$CUT" = 1 ] || gate_require "$REF" "oracle trace ref (run with --cut to create it)"
if [ "$CUT" = 1 ]; then
  . "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
  SWIPL="$(swipl_bin)" || exit 2
fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
CANARY="backtrack_canary"
cat > "$W/$CANARY.pl" << 'EOF'
color(red).
color(green).
color(blue).
:- initialization(main).
main :- color(C), write(C), nl, fail ; true.
EOF
printf 'red\ngreen\nblue\n' > "$W/$CANARY.ref"
user_preds_of() {  # $1=src.pl -> NAME1|NAME2|... (clause-head functors at column 0, excluding 'main')
  grep -oE '^[a-z][A-Za-z0-9_]*' "$1" | sort -u | grep -v '^main$' | paste -sd'|' -
}
# ⛔ ONE-DIRECTION, NAMED, NEVER SYMMETRIC -- see the header's POPULATION note for the measurement behind
# this. Applied to SCRIP's normalised stream only; the oracle's stream never carries the pair to begin with.
drop_trailing_choicepoint_pair() {
  awk '{ln[NR]=$0} END{n=NR; if (n>=2 && ln[n] ~ /^omega /  && ln[n-1] ~ /^beta /) n-=2; for (i=1;i<=n;i++) print ln[i]}'
}
scrip_trace_norm() {  # $1=raw trace file  $2=NAME1|NAME2|... (user predicates, excluding main)
  grep -E ': n[0-9]+_call_proc_staged ' "$1" \
    | sed -E 's/^.*(Call|Redo|Exit|Fail): n[0-9]+_call_proc_staged ([^ /]+)\/[0-9]+.*$/\1 \2/' \
    | sed -E 's/^Call /alpha /; s/^Redo /beta /; s/^Exit /gamma /; s/^Fail /omega /' \
    | grep -E "^(alpha|beta|gamma|omega) ($2)\$" \
    | drop_trailing_choicepoint_pair
}
oracle_map() {  # $1=NAME1|NAME2|... -- filters+normalises swipl's stderr trace to alpha/beta/gamma/omega NAME
  sed -E '
    s/^\^?[[:space:]]*(Call|Redo|Exit|Fail): \([0-9]+\)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\(.*$/\1 \2/
    s/^\^?[[:space:]]*(Call|Redo|Exit|Fail): \([0-9]+\)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$/\1 \2/
  ' | sed -E 's/^Call /alpha /; s/^Redo /beta /; s/^Exit /gamma /; s/^Fail /omega /' \
    | grep -E "^(alpha|beta|gamma|omega) ($1)\$"
}
oracle_trace_for() {  # $1=src.pl  $2=NAME1|NAME2|...
  local src="$1" names="$2" wd rc=0
  wd="$(mktemp -d)"
  { echo ':- leash(-all), trace.'; cat "$src"; } > "$wd/f.pl"
  ( cd "$wd" && timeout -k 5 "$T" "$SWIPL" -q f.pl ) < /dev/null > "$wd/out.txt" 2> "$wd/err.txt"; rc=$?
  oracle_map "$names" < "$wd/err.txt"
  rm -rf "$wd"; return $rc
}
m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
refblock() { awk -v o="$1" '$0 ~ "^%---- " o " " {on=1; next} /^%---- /{on=0} on' "$REF"; }
refmeta()  { grep -E "^%---- $1 " "$REF" | head -1 | sed -E 's/.* total=([0-9]+).*/\1/'; }
n=0; bad=0; ans_ok=0; ans_red=0; declare -a lines
o="$CANARY"; src="$W/$o.pl"; ref="$W/$o.ref"
NAMES="$(user_preds_of "$src")"
[ -n "$NAMES" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not parse a predicate name out of the embedded canary -- fixture is broken"; gate_stamp; exit 2; }
n=1
(cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0" "$src" </dev/null >/dev/null 2>&1); (cd "$W" && SCRIP_PL_TRACE=0 timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0b" "$src" </dev/null >/dev/null 2>&1)
(cd "$W" && SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s1" "$src" </dev/null >/dev/null 2>&1)
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
  total=$(wc -l < "$W/$o.$m.norm")
  [ "$total" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o $m: SCRIP_PL_TRACE=1 produced ZERO call_proc_staged lines for {$NAMES} -- the instrument is not firing, this is not 'no ports'"; gate_stamp; exit 2; }
done
if [ "$CUT" = 1 ]; then
  oracle_trace_for "$src" "$NAMES" > "$W/$o.oracle.norm"
  otot=$(wc -l < "$W/$o.oracle.norm")
  [ "$otot" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o: swipl produced ZERO normalised trace lines -- cannot cut a ref from nothing"; gate_stamp; exit 2; }
  { echo "%---- $o total=$otot"; cat "$W/$o.oracle.norm"; } > "$W/ALL.trace.oracle"
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
lines+=("$(printf '%-20s killswitch=%-4s perturb m3=%-4s m4=%-7s trace m3=%-16s m4=%-16s answer=%s' "$o" "$ks" "$pert3" "$pert4" "$tr3" "$tr4" "$ans")")
for m in m3 m4; do [ -f "$W/$o.$m.diff" ] && lines+=("$(cat "$W/$o.$m.diff")"); done
printf '%s\n' "${lines[@]}"
if [ "$CUT" = 1 ]; then cp "$W/ALL.trace.oracle" "$REF"; echo "refs CUT -> $REF (1 block)"; fi
echo "witnesses=$n (1 hand-written canary, non-recursive single-frame backtracking -- NOT drawn from the rungs suite, see header) modes=2 (m3 --run, m4 --compile+as+gcc) . answer ok=$ans_ok red=$ans_red (informational) . oracle=swipl trace/0, Call/Redo/Exit/Fail -> alpha/beta/gamma/omega verbatim (Prolog's own port names ARE this codebase's Byrd vocabulary), depths/args/main dropped, one named one-direction trailing-choicepoint-pair drop on SCRIP's side only (see header)"
GATE_EXAMINED=$((n*2)); gate_verdict "$bad" "failed checks across killswitch/perturbation/trace"
