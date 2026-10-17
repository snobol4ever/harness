#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
# test_gate_icn_call_traces_its_call_line_exactly_once.sh -- one call, one TRK_CALL event, one bar depth.
#
# WHY THIS EXISTS (hq_B found it 2026-09-10 while curing the Icon trace value renderer; hq_U cured it):
# a procedure call of arity FIVE OR MORE printed its trace call line TWICE and left the bar depth one too
# high for the rest of the call -- every later line, including "f returned", inherited the extra bar.
# THE BODY RAN ONCE: it was a duplicated EVENT, not a duplicated call.
#
# THE INVARIANT THIS PINS is ownership of the call event, and it is one predicate at the SHARED call spine
# rt_proc_call_prologue_lex (src/runtime/rt/rt.c): the spine computed `own` as "the callee has a registered
# direct-call fn and is not a generator", opened a level with it, and emitted the TRK_CALL itself when NOT
# own -- i.e. it assumed an UNREGISTERED callee has no tap of its own. The callee's compiled prologue tap
# (xa_icn_trace_tap kind==1 -> rt_trace_call_hook_f) emits UNCONDITIONALLY, so any callee routing through
# the spine with no dc_fn registered fired both taps and opened both levels. The cure makes a NON-GENERATOR
# callee always own its own call event, which is what the arity 1-4 route already did by never reaching the
# spine at all. THE GENERATOR ARM IS UNCHANGED ON PURPOSE and is not incidental: forcing own=1 for
# generators too was measured and took test_gate_icn_generator_exhaustion_traces_failed from 10/10 to 2
# FAILs, because a generator's events are owned by the spine, not by its prologue.
#
# ⛔ THE ARITY BOUNDARY IS THE WHOLE POINT, so this gate walks 1..8 rather than sampling. Arities 1-4 were
# ALREADY GREEN before the cure and are kept as ORACLE-AGREEMENT arms, not detectors: they would catch a
# future cure that overshoots into suppressing the event on the direct route. MEASURED on the pre-cure
# binary, 5/6/7/8 go RED in both modes and 1/2/3/4 do not -- so 8 of the 16 arms discriminate and the gate
# says so rather than printing a denominator that reads as if all 16 did.
#
# ⛔ &trace WRITES ONLY TO stderr, so every run below captures 2>&1; a version that dropped stderr would
# score a green board over an empty file.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
NAME=icn_call_traces_its_call_line_exactly_once
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)"; ICONX="$(iconx_bin)"
[ -n "$ICONT" ] && [ -x "$ICONT" ] || refuse "no icont oracle -- cannot measure (a missing oracle prints a full false all-FAIL table)"
[ -n "$ICONX" ] && [ -x "$ICONX" ] || refuse "no iconx oracle -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
graded=0; fail=0
for k in 1 2 3 4 5 6 7 8; do
  ps=""; as=""; i=1
  while [ "$i" -le "$k" ]; do ps="$ps${ps:+,}p$i"; as="$as${as:+,}$i"; i=$((i+1)); done
  printf 'procedure main()\n   &trace := -1;\n   f(%s);\nend\nprocedure f(%s)\n   return;\nend\n' "$as" "$ps" > "$T/a$k.icn"
  ( cd "$T" && "$ICONT" -s -o "a$k" "a$k.icn" >/dev/null 2>&1 && timeout -k 5 30 "$ICONX" "./a$k" > "a$k.ora" 2>&1 ) || refuse "oracle could not build or run arity $k -- cannot measure"
  [ -s "$T/a$k.ora" ] || refuse "oracle produced ZERO BYTES for arity $k -- that is not a score"
  ( cd "$T" && timeout -k 5 30 "$SCRIP" "a$k.icn" < /dev/null > "a$k.m3" 2>&1 )
  graded=$((graded+1))
  if cmp -s "$T/a$k.ora" "$T/a$k.m3"; then echo "  PASS m3 arity $k"; else fail=$((fail+1)); echo "  FAIL m3 arity $k: $(diff "$T/a$k.ora" "$T/a$k.m3" | grep -m1 '^[<>]' | cut -c1-80)"; fi
  ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o "a$k.s" "a$k.icn" </dev/null >/dev/null 2>&1 \
      && gcc -no-pie "a$k.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "a$k.b" >/dev/null 2>&1 \
      && timeout -k 5 30 "./a$k.b" < /dev/null > "a$k.m4" 2>&1 ) || true
  graded=$((graded+1))
  if cmp -s "$T/a$k.ora" "$T/a$k.m4"; then echo "  PASS m4 arity $k"; else fail=$((fail+1)); echo "  FAIL m4 arity $k: $(diff "$T/a$k.ora" "$T/a$k.m4" 2>/dev/null | grep -m1 '^[<>]' | cut -c1-80)"; fi
done
[ "$graded" = 16 ] || refuse "expected 16 arms (arities 1-8 x 2 modes), graded $graded"
echo "graded=$graded FAIL=$fail (arities 1-8 x m3+m4, every verdict cut from icont/iconx v9.5.25a at run time, never pinned from us; 8 of the 16 -- arities 5-8 in both modes -- go RED on the pre-cure binary and are the detectors, the arity 1-4 arms are oracle-agreement arms that would catch an overshoot)"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
