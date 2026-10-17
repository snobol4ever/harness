#!/usr/bin/env bash
# test_gate_sno_byname_goto_zeta_unwind_in_a_loop.sh -- A BY-NAME GOTO OUT OF A MATCH STATEMENT UNWINDS TO THE MATCH WATERMARK, NOT TO ZERO.
#
# WHAT THIS IS: in SNOBOL4 a transfer `:(X)` whose target is computed (`$X`) lowers to a FOUR-node
# IR_GOTO_DEFERRED chain -- the ^R/^F/^N special-transfer tests, then a resolve that calls rt_goto_resolve and
# jumps to the returned address. When that transfer leaves a statement that CONTAINS A PATTERN MATCH, the node
# that leaves the statement is the chain head, an IR_GOTO_DEFERRED -- not the IR_STATEMENT_END that a plain
# `:(L)` would exit through.
#
# THE DEFECT THIS PINS: zd_plan (src/emitter/emit.cpp) computes the exit pop for a node leaving a statement as
# the MATCH-BEGIN WATERMARK (zdh_match + emit_match_begin_stfh_k()) rather than the statement's full zeta depth,
# because a match's own epilogue has already released the bytes above that watermark. That rule was gated on
# `op == IR_STATEMENT_END || op == IR_STATEMENT`. IR_GOTO_DEFERRED was not in the set, so it fell through to the
# full depth and emitted `add rsp, <full>` -- OVER-popping by exactly the watermark on every traversal. The pop
# is emitted at BOTH ports of the chain head (gamma = the special-transfer landing, omega = the hop to the next
# test), and the omega port is the one the ordinary case takes, so both arms of the fallback needed the rule.
#
# ⭐ IT IS AN OVER-POP, NOT A LEAK, AND THAT IS WHY IT LOOKED LIKE ONE. rsp CLIMBS 16 bytes per traversal
# (measured at the loop head: e070 -> e080 -> e090 -> e0a0 on the pre-cure build, flat at e060 after). Nothing
# is lost; the stack pointer walks UP through its own frame until it passes the frame base, after which the
# program is executing with rsp above live data and dies at whatever it jumps through next. On an 8MB stack the
# witness died at ~4200 iterations -- not because 8MB was exhausted, but because only ~73KB of headroom
# separated the loop's rsp from the frame base. A stack-exhaustion reading of the crash predicts a threshold
# ~100x larger than the measured one, which is how the over-pop reading was chosen over the leak reading.
#
# ⛔ THE b-ARM IS THE ONLY ARM THE CURE FLIPS AND IT WAS PROVEN RED ON A BUILD WITHOUT THE CURE (clean HEAD
# 03402a0fc, built into a separate tree so the objdir could not be shared): b1 m4 rc=139, everything else rc=0.
# The three c-arms were GREEN BEFORE AND AFTER and are not decoration -- each one pins a boundary of the change:
#   c1  the same loop with a PLAIN LABEL target. Exits through IR_STATEMENT_END, which always had the rule.
#       If a future change makes the deferred chain stop being the exit node, b1 and c1 stop differing.
#   c2  a by-name goto out of a statement with NO MATCH IN IT. There is no watermark (zdh_match < 0), so the
#       rule must NOT fire and the full depth remains correct. This is the arm that would catch the cure being
#       written as an unconditional "deferred gotos pop less".
#   b2  the same match statement with a match that FAILS, so the transfer leaves through the statement's omega
#       exits and the SECOND deferred chain. Green on both builds; it is here because the failure path reaches
#       a different chain and nothing else in the suite grades it.
#
# ⛔ ITERATION COUNT IS LOAD-BEARING, NOT ARBITRARY. 20000 iterations is ~4.3x the measured pre-cure crash
# threshold on this host's 8MB stack. A drift of 16 bytes per traversal needs roughly 4600 traversals to reach
# the frame base; grading at, say, 1000 would print a green board for a fully live defect. If this gate is ever
# green on a build you believe is broken, raise N before concluding anything.
#
# EXIT: 0 all arms match SPITBOL. 1 an arm regressed. 2 UNPROVEN (no built scrip, no oracle, or nothing graded).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
ORACLE=/home/resources/x64/bin/sbl
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
N=20000
mk() { printf "        X = 'L'\n        N = 0\nL       N = LT(N,%s) N + 1              :F(DONE)\n        S = 'hello'\n        %s\nDONE    OUTPUT = 'N=' N\nEND\n" "$N" "$2" > "$T/$1.sno"; }
mk b1 "S 'ell' = 'ELL'                    :(\$X)"
mk b2 "S 'zzz' = 'ELL'                    :(\$X)"
mk c1 "S 'ell' = 'ELL'                    :(L)"
mk c2 "T = S                              :(\$X)"
graded=0; bad=0
for a in b1 b2 c1 c2; do
    want="$(timeout -k 5 60s "$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
    [ -n "$want" ] || { echo "UNPROVEN(2): oracle produced no output for $a -- refusing to grade SCRIP against nothing"; exit 2; }
    for m in m3 m4; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 60s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
        else
            "$SCRIP" --compile -o "$T/$a.s" "$T/$a.sno" < /dev/null >/dev/null 2>&1 || { echo "  RED  $a $m -- compile failed"; bad=$((bad+1)); graded=$((graded+1)); continue; }
            gcc -no-pie "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=$((bad+1)); graded=$((graded+1)); continue; }
            got="$(timeout -k 5 60s "$T/$a.x" < /dev/null 2>&1 | tr '\n' '/')"
        fi
        graded=$((graded+1))
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL [$want]"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=$((bad+1)); fi
    done
done
echo "BYNAME-GOTO-ZETA-UNWIND graded=$graded bad=$bad (N=$N iterations per arm)"
[ "$graded" -eq 8 ] || { echo "UNPROVEN(2): expected 8 graded arms, got $graded -- a runner that cannot measure never prints the success shape"; exit 2; }
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-byname-goto-zeta-unwind-in-a-loop]: a by-name goto leaving a match statement over-popped the match watermark and walked rsp out of its frame"; exit 1; fi
echo "GATE GREEN(0) [sno-byname-goto-zeta-unwind-in-a-loop]: a deferred goto out of a match statement unwinds to the match watermark on both ports, in both modes, over $N iterations with no rsp drift; plain-label, no-match and failed-match controls hold"
