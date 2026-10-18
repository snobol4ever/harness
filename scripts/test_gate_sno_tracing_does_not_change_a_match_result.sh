#!/usr/bin/env bash
# test_gate_sno_tracing_does_not_change_a_match_result.sh -- TRACING (the monitor's precondition) DOES NOT CHANGE A MATCH RESULT
#
# MEASURED 2026-09-24 by hq_snocone (row snocone-tracing-changes-a-match-result-...): under --trace the transpiled parser_rebus.sno
# and parser_snocone.sno answered Parse Error where the untraced run printed the tree, so monitor_run.sh refused every bootstrap
# parser as NOT MONITOR-SAFE and Lon's step 3 was blocked for all seven. Every trace hook made a no-op left the failure in place;
# SCRIP_MON_SCC=1 (slim calls under trace) cured it and SCRIP_SCC_OFF=1 (no slim calls, no trace) reproduced it untraced -- so the
# defect was the NON-SLIM call protocol, which tracing merely selects for every call. Thirteen lines: a deferred NRETURN function
# whose body calls another NRETURN function (the parsers' Shift, which calls tree and Push) made the enclosing match fail --
# rt_proc_call_prologue parked the caller's want-name flag in the live global rt_g_want_name for the callee's epilogue to read,
# so the nested call read the outer's flag as its own and, on return, rt_nret_fix zeroed the outer's: the flags of the outer and
# inner calls were swapped, the outer's name came back dereferenced and the capture target was no name. The slim callee's emitted
# entry saves the flag in its frame, zeroes the global for its body and restores it at exit; the non-slim prologue now parks it in
# a spare bit of the existing per-level ownership byte and rt_proc_epilogue_named restores it before the caller's consult
# (killswitch SCRIP_WN_PARK=0 restores the old parking).
# ARMS: (1) the two witnesses, untraced against the SPITBOL oracle in m3 and m4 with slim calls off (the protocol form), then
# traced against untraced; (2) the two transpiled parsers, traced against untraced in m3 and m4, identical stdout and rc;
# (3) fail-once: the first witness under SCRIP_WN_PARK=0 with slim calls off must differ from the oracle.
# A mode-4 binary compiled with --trace is run with SCRIP_TRACE set, as the harness runs its scr4 participant: a traced compile
# whose RUNTIME budget is zero is a MIXED state (the runtime compiler then picks the slim protocol for an EVAL while the program's
# callees have no slim entry -- error 22 at the first deferred user call), a separate defect named in the row's baton.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; B="$ROOT/bootstrap"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_clean_bin 2>/dev/null)"; [ -x "${SBL:-}" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.sno" <<'EOW'
	DEFINE('H(v)')	:(HE)
H	OUTPUT = 'H ' v
	H = .dummy	:(NRETURN)
HE
	DEFINE('G(v)')	:(GE)
G	H(v)
	G = .dummy	:(NRETURN)
GE
	'ab' ? 'a' . x . *G(x)	:S(Y)F(N)
Y	OUTPUT = 'S'	:(E)
N	OUTPUT = 'F'
E
END
EOW
cat > "$T/w2.sno" <<'EOW'
	DEFINE('H(v)')	:(HE)
H	H = .z	:(NRETURN)
HE
	DEFINE('G(v)y')	:(GE)
G	H(v) = 3
	G = .dummy	:(NRETURN)
GE
	G('q') = 7
	OUTPUT = 'dummy=' dummy ' z=' z
END
EOW
printf 'function main()\n  OUTPUT := 1\nend\n' > "$T/p.reb"
printf "OUTPUT = 'hello world';\nOUTPUT = 3 + 4;\n" > "$T/p.sc"
for l in rebus snocone; do
  "$SCRIP" --transpile "$B/global.sc" "$B/case.sc" "$B/assign.sc" "$B/match.sc" "$B/counter.sc" "$B/stack.sc" "$B/tree.sc" "$B/ShiftReduce.sc" "$B/tdump.sc" "$B/gen.sc" "$B/qize.sc" "$B/semantic.sc" "$B/omega.sc" "$B/trace.sc" "$B/parser_$l.sc" > "$T/parser_$l.sno" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: parser_$l.sc does not transpile"; exit 2; }
done
run() {  # run <m3|m4> <prog> <stdin> [--trace] [ENV=V...] -> stdout; rc in $T/rc
  local m="$1" p="$2" in="$3"; shift 3; local tr=""; [ "${1:-}" = --trace ] && { tr=--trace; shift; }
  if [ "$m" = m3 ]; then env "$@" timeout -k 5 120 "$SCRIP" $tr --run "$p" < "$in" 2>/dev/null; echo $? > "$T/rc"; return; fi
  local x="$p.$m${tr:+.t}"
  env "$@" "$SCRIP" $tr --compile -o "$x.s" "$p" </dev/null >/dev/null 2>&1 || { echo "COMPILE-FAIL"; echo 99 > "$T/rc"; return; }
  gcc -no-pie -o "$x.bin" "$x.s" -L"$RT" -Wl,-rpath,"$RT" -lscrip_rt -lm >/dev/null 2>&1 || { echo "LINK-FAIL"; echo 99 > "$T/rc"; return; }
  env "$@" ${tr:+SCRIP_TRACE=2000000000} timeout -k 5 120 "$x.bin" < "$in" 2>/dev/null; echo $? > "$T/rc"; }
strip_trace() { grep -v '^\*\*\*\*'; }
RC=0; N=0
for w in w1 w2; do
  want=$("$SBL" -bf "$T/$w.sno" </dev/null 2>/dev/null); [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
  for m in m3 m4; do
    N=$((N+1)); got=$(run $m "$T/$w.sno" /dev/null SCRIP_SCC_OFF=1); if [ "$got" = "$want" ]; then echo "  $w $m non-slim vs oracle PASS"; else echo "  $w $m non-slim vs oracle FAIL: got [$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-60)] want [$(printf '%s' "$want" | tr '\n' ' ')]"; RC=1; fi
    N=$((N+1)); plain=$(run $m "$T/$w.sno" /dev/null); prc=$(cat "$T/rc"); traced=$(run $m "$T/$w.sno" /dev/null --trace | strip_trace); trc=$(cat "$T/rc")
    if [ "$plain" = "$traced" ] && [ "$prc" = "$trc" ]; then echo "  $w $m traced == untraced PASS"; else echo "  $w $m traced != untraced FAIL: plain [$(printf '%s' "$plain" | tr '\n' ' ' | cut -c1-40)] rc=$prc traced [$(printf '%s' "$traced" | tr '\n' ' ' | cut -c1-40)] rc=$trc"; RC=1; fi
  done
done
for l in rebus snocone; do
  in="$T/p.reb"; [ "$l" = snocone ] && in="$T/p.sc"
  for m in m3 m4; do
    N=$((N+1)); plain=$(run $m "$T/parser_$l.sno" "$in"); prc=$(cat "$T/rc"); traced=$(run $m "$T/parser_$l.sno" "$in" --trace | strip_trace); trc=$(cat "$T/rc")
    case "$plain" in "("*) ;; *) echo "  parser_$l $m untraced prints no tree: [$(printf '%s' "$plain" | head -1 | cut -c1-60)]"; RC=1;; esac
    if [ "$plain" = "$traced" ] && [ "$prc" = "$trc" ]; then echo "  parser_$l $m traced == untraced PASS"; else echo "  parser_$l $m traced != untraced FAIL: plain [$(printf '%s' "$plain" | head -1 | cut -c1-50)] rc=$prc traced [$(printf '%s' "$traced" | head -1 | cut -c1-50)] rc=$trc"; RC=1; fi
  done
done
want=$("$SBL" -bf "$T/w1.sno" </dev/null 2>/dev/null); got=$(run m3 "$T/w1.sno" /dev/null SCRIP_SCC_OFF=1 SCRIP_WN_PARK=0)
if [ "$got" != "$want" ]; then echo "  fail-once w1 under SCRIP_WN_PARK=0 SCRIP_SCC_OFF=1: RED as it must be"; else echo "  fail-once w1 under SCRIP_WN_PARK=0 SCRIP_SCC_OFF=1: STILL GREEN -- this gate cannot see the defect it names"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N arms -- two witnesses agree with SPITBOL under the non-slim protocol and read the same traced and untraced, both transpiled parsers read the same traced and untraced, in m3 and m4; the killswitch reds the witness"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL -bf  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
