#!/usr/bin/env bash
# test_gate_sno_arbno_literal_body_then_fence_terminates.sh -- ARBNO(P) WHOSE BODY BEGINS WITH A LITERAL, FOLLOWED BY A FENCE(Q)
# THAT IS BACKTRACKED INTO, TERMINATES AND ANSWERS AS SPITBOL DOES (ceo 2026-09-30, found rewriting bootstrap/parser_raku.sc:
# `'a' ARBNO(' b') FENCE(' ' | '') RPOS(0)` on 'a b' -- sbl -bf says yes, ./scrip never returns; the same with FENCE(' ') -- sbl no,
# ./scrip never returns; two fences -- sbl yes, ./scrip never returns. ARBNO(FENCE(...)) and ARBNO((' ' | '') 'x') agree on both
# engines, so the shape is the LITERAL-FIRST body. The witness and its oracle-cut ref: ../harness/scripts/fixtures/pattern/
# arbno_literal_body_then_fence.{sno,ref}. rc 0 both modes print the ref within the limit; rc 1 a diff or a timeout (the hang);
# rc 2 no binary.
# THE DEFECT (cfo 2026-09-30, measured under gdb on the fixture): FENCE1's beta handed its predecessor the backtrack with r14 where
# FENCE's BODY had left it, not where FENCE found it at alpha. Every predecessor beta reads r14 as the cursor it left at its own
# gamma: a literal subtracts its width from it, and a frameless ARBNO re-enters its body there and recedes until r14 equals its
# start -- from 2 against a start of 1, by steps of 2, so 0, -2, -4 ... and never back (the hang). The same stale cursor gives a
# wrong answer where the recede does land (C1, C2 below: SCRIP no, sbl yes). The literal-first body was the reported trigger,
# not the cause: ARBNO(LEN(2)), FENCE(LEN(1)) and a literal between ARBNO and FENCE all hung the same way.
# THE CURE: FENCE1 saves r14d at alpha beside its watermark and restores it at beta before the release (bb_match_fence1.cpp).
# ARM 2: ../harness/scripts/fixtures/pattern/arbno_then_fence_cursor_class.{sno,ref}, the class -- the stale cursor's wrong answers, ARBNO
# reached through a literal, a FENCE body on the frame route (an alternation inside), and controls that never depended on the
# cursor. NOT ARMED: *P (a stored ARBNO) left of the FENCE still hangs alone -- a FENCE after a deferred pattern whose thunk stays
# live addresses its zls slots 144-16 bytes off (gdb: rsp falls 0x90 from defer alpha to fence alpha, the depth tracker counts
# 16), its own row; inside this fixture that arm passed only because the misplaced stores fell on dead slots, so it is not here. RED on the parent of the cure (b1cde82b2): both fixtures HANG in m3 and m4; the class prints C1 no, C2 no, then hangs at C3.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); G=sno_arbno_literal_body_then_fence_terminates
[ -x "$W/scrip" ] || { echo "GATE REFUSE(2) [$G]: no $W/scrip"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
rc=0
for stem in arbno_literal_body_then_fence arbno_then_fence_cursor_class; do
    F="$W/scripts/fixtures/pattern/$stem.sno"; R="${F%.sno}.ref"
    [ -s "$F" ] && [ -s "$R" ] || { echo "GATE REFUSE(2) [$G]: fixture or ref missing ($stem)"; exit 2; }
    timeout -k 5 20 "$W/scrip" "$F" < /dev/null > "$T/m3.out" 2>&1; r3=$?
    if [ $r3 -eq 124 ]; then echo "  $stem m3: HANG (20 s) -- the matcher does not terminate"; rc=1
    elif ! cmp -s "$T/m3.out" "$R"; then echo "  $stem m3: DIFF from the oracle's answer"; diff "$T/m3.out" "$R" | head -4; rc=1
    else echo "  $stem m3: agrees with sbl -bf"; fi
    if "$W/scrip" --compile "$F" --out="$T/w.s" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$T/w" 2>/dev/null; then
        timeout -k 5 20 "$T/w" < /dev/null > "$T/m4.out" 2>&1; r4=$?
        if [ $r4 -eq 124 ]; then echo "  $stem m4: HANG (20 s)"; rc=1
        elif ! cmp -s "$T/m4.out" "$R"; then echo "  $stem m4: DIFF from the oracle's answer"; diff "$T/m4.out" "$R" | head -4; rc=1
        else echo "  $stem m4: agrees with sbl -bf"; fi
    else echo "  $stem m4: could not build"; rc=1; fi
done
[ $rc -eq 0 ] && { echo "GATE PASS(0) [$G]: ARBNO with a literal-first body then FENCE terminates and matches SPITBOL in both modes"; exit 0; }
echo "GATE FAIL(1) [$G]: the literal-first ARBNO body followed by a backtracked FENCE does not answer as SPITBOL does (see above)"; exit 1
