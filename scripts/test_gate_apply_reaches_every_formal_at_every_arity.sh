#!/usr/bin/env bash
# test_gate_apply_reaches_every_formal_at_every_arity.sh -- APPLY('F',a1..aN) BINDS FORMAL i TO ACTUAL i AT EVERY ARITY.
#
# WHAT THIS IS: the regression arm of landing 4 of row gc-rt-c-c-to-bb-entries-leave-no-emitted-code-is-entered-from-c-in-rt-c-except-the-original-invocation
# (cfo 2026-09-19).  APPLY reaches a tiny-shim-eligible DEFINE'd procedure through rt_tiny_record_enter (src/runtime/rt/rt.c),
# the C-side half of the alpha face's calling convention: the caller lays the actuals in its own frame and hands the callee a
# record {nargs, gamma, omega, off_0 .. off_{N-1}} in rcx, where off_i is the byte displacement of formal i's actual from the
# caller's rsp.  The callee's role-4 SIG shim (bb_define.cpp, fnsig()) reads [rcx + 24 + 8i] for i < nargs and adds it to r8.
#
# ⛔ THE DEFECT THIS ARM PINS: rt_tiny_record_enter wrote a FIXED FIVE-QUAD record -- {nargs, gamma, omega, 16*nargs, 16} --
# which is the correct offset table for nargs 0, 1 and 2 BY COINCIDENCE (off_0 = 16N and off_1 = 16 are right only when N <= 2)
# and wrong for every higher arity: at N = 3 formal 1 read formal 2's actual and formal 2 read PAST THE RECORD, whatever the
# frame held there.  MEASURED on SCRIP f0368fb08: APPLY('F3',10,20,30) SIGSEGV rc=139 in BOTH modes, arities 0-2 correct, and
# the whole 1974-entry SNOBOL4 rungs green over it -- no board we own reaches a three-argument APPLY, which is why this arm
# exists rather than a board line.  The cure builds N offsets, and sizes the frame 24N + 40 (padded to keep rsp 16-aligned at
# the transfer) where the old shape allowed the record only 40 bytes above the actuals.
#
# NON-VACUOUS: arm P is a PLANT -- the same comparison run against a deliberately wrong expectation, which must be seen to
# FAIL, so a green above is a comparison that discriminates and not a harness that matches everything.  The stronger proof is
# the A/B: check out this file's parent tree, rebuild, and every arity >= 3 below is red.
#
# EXIT: 0 every arity matches SPITBOL in both modes.  1 an arity regressed.  2 UNPROVEN (no built scrip, stale binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
ORACLE="/home/resources/x64/bin/sbl"
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
{ printf "        DEFINE('F0()')\n"
  for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
      f=''; i=0; while [ "$i" -lt "$n" ]; do i=$((i+1)); f="$f${f:+,}A$i"; done
      printf "        DEFINE('F%s(%s)')\n" "$n" "$f"
  done
  printf "        DEFINE('V3(A1,A2,A3)')          :(MAIN)\n"
  printf "F0      F0 = 'n0' :(RETURN)\n"
  for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
      b=''; i=0; while [ "$i" -lt "$n" ]; do i=$((i+1)); b="$b '/' A$i"; done
      printf "F%s      F%s = 'n%s'%s :(RETURN)\n" "$n" "$n" "$n" "$b"
  done
  printf "V3      V3 = 'v' '/' A1 '/' A2 '/' A3 :(RETURN)\n"
  printf "MAIN    OUTPUT = APPLY('F0')\n"
  for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
      a=''; i=0; while [ "$i" -lt "$n" ]; do i=$((i+1)); a="$a,$i"; done
      printf "        OUTPUT = APPLY('F%s'%s)\n" "$n" "$a"
  done
  printf "        OUTPUT = APPLY('V3',7,8)\n        OUTPUT = APPLY('V3',7)\n        OUTPUT = APPLY('V3')\n        OUTPUT = APPLY('V3','p','q','r')\n"
  printf "        X = 'F3'\n        OUTPUT = APPLY(X,4,5,6)\n        OUTPUT = 'done'\nEND\n"; } > "$T/ap.sno"
want="$("$ORACLE" -bf "$T/ap.sno" < /dev/null 2>&1 | tr '\n' '/')"
case "$want" in *done*) ;; *) echo "UNPROVEN(2): the oracle did not run the witness to completion [$want]"; exit 2;; esac
bad=0
for m in m3 m4; do
    if [ "$m" = m3 ]; then
        got="$(timeout -k 5 30s "$SCRIP" "$T/ap.sno" < /dev/null 2>&1 | tr '\n' '/')"; rc=$?
    else
        "$SCRIP" --compile -o "$T/ap.s" "$T/ap.sno" < /dev/null >/dev/null 2>&1
        gcc -no-pie "$T/ap.s" -o "$T/ap.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $m -- link failed"; bad=1; continue; }
        got="$(timeout -k 5 30s "$T/ap.x" < /dev/null 2>&1 | tr '\n' '/')"; rc=$?
    fi
    if [ "$got" = "$want" ]; then echo "  ok   $m -- 13 arities, three short-call arms and a by-name APPLY all match SPITBOL (rc=$rc)"
    else echo "  RED  $m rc=$rc -- got [$got] want [$want]"; bad=1; fi
done
sed 's/^\( *OUTPUT = APPLY(.F3.,1,2,3)\)$/        OUTPUT = APPLY('"'"'F3'"'"',1,2,9)/' "$T/ap.sno" > "$T/plant.sno"
if cmp -s "$T/ap.sno" "$T/plant.sno"; then echo "  RED  P -- the plant edited nothing, so it proves nothing about this harness"; bad=1
else
    pgot="$(timeout -k 5 30s "$SCRIP" "$T/plant.sno" < /dev/null 2>&1 | tr '\n' '/')"
    if [ "$pgot" = "$want" ]; then echo "  RED  P -- a program that passes a DIFFERENT actual compared EQUAL to the reference: this harness cannot see a wrong binding"; bad=1
    else echo "  ok   P -- the plant is seen: one changed actual makes the measured run differ from the reference, so a green above is a comparison that discriminates"; fi
fi
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [apply_reaches_every_formal_at_every_arity]: APPLY binds a formal to the wrong actual, or crashes, at some arity"; exit 1; fi
echo "GATE GREEN(0) [apply_reaches_every_formal_at_every_arity]: APPLY('F',a1..aN) binds formal i to actual i for N = 0..12, both modes, against SPITBOL"
