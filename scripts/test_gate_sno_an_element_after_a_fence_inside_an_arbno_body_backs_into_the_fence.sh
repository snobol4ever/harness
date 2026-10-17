#!/usr/bin/env bash
# test_gate_sno_an_element_after_a_fence_inside_an_arbno_body_backs_into_the_fence.sh -- INSIDE AN ARBNO BODY, AN ELEMENT AFTER
# FENCE(P) THAT FAILS BACKS INTO THE FENCE, AND THE FENCE INTO WHAT PRECEDES IT IN THE SAME ITERATION (cfo 2026-09-30, found in the
# probe matrix closing the ARBNO-then-FENCE hang row: 'bbz' ? POS(0) ARBNO(ARBNO('b') FENCE('b') 'z') RPOS(0) -- sbl yes, SCRIP no).
# THE DEFECT, read in the emitted mode-4 code: the 'z' after the FENCE failed straight to the enclosing ARBNO's body-omega
# (`jne .Lmatch_arbno_omega`), skipping FENCE's beta, so the inner ARBNO('b') left of the fence was never asked to grow and the whole
# iteration failed. src/lower/lower_snobol4.c's fenced TT_SEQ builds right to left; its outside-ARBNO branch re-routes the right-hand
# run's failure into the FENCE's beta (sno_resume_omega_to on right_tail), and the inside-ARBNO branch (SNO_FENCE_LIT_ARG_IN_ARBNO)
# never did. THE CURE: the same re-route, and right_sealed cleared, in the inside-ARBNO branch. It holds since 32b404921 made
# FENCE's beta restore the cursor it found at alpha -- before that, routing into FENCE's beta would hand the inner ARBNO a stale one.
# ARMS: (1) mode 3 and (2) mode 4 print ../harness/scripts/fixtures/pattern/fence_inside_arbno_body_retries_its_left.{sno,ref} (ref cut from
# sbl -bf): E1-E3 and E5 RED on the parent (no where sbl says yes) -- an inner ARBNO, a leading literal, an alternation and a
# two-arm fence body left of the trailing element; E4, E6, E7 controls (no element after the fence, a subject that must fail, no
# FENCE) that were green before. rc 0 both agree · 1 a hang or a diff · 2 no binary or fixture.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); G=sno_an_element_after_a_fence_inside_an_arbno_body_backs_into_the_fence
[ -x "$W/scrip" ] || { echo "GATE REFUSE(2) [$G]: no $W/scrip"; exit 2; }
F="$W/scripts/fixtures/pattern/fence_inside_arbno_body_retries_its_left.sno"; R="${F%.sno}.ref"
[ -s "$F" ] && [ -s "$R" ] || { echo "GATE REFUSE(2) [$G]: fixture or ref missing"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
rc=0
timeout -k 5 20 "$W/scrip" "$F" < /dev/null > "$T/m3.out" 2>&1; r3=$?
if [ $r3 -eq 124 ]; then echo "  m3: HANG (20 s)"; rc=1
elif ! cmp -s "$T/m3.out" "$R"; then echo "  m3: DIFF from the oracle's answer"; diff "$T/m3.out" "$R" | head -6; rc=1
else echo "  m3: agrees with sbl -bf"; fi
if "$W/scrip" --compile "$F" -o "$T/w.s" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$T/w" 2>/dev/null; then
    timeout -k 5 20 "$T/w" < /dev/null > "$T/m4.out" 2>&1; r4=$?
    if [ $r4 -eq 124 ]; then echo "  m4: HANG (20 s)"; rc=1
    elif ! cmp -s "$T/m4.out" "$R"; then echo "  m4: DIFF from the oracle's answer"; diff "$T/m4.out" "$R" | head -6; rc=1
    else echo "  m4: agrees with sbl -bf"; fi
else echo "  m4: could not build"; rc=1; fi
[ $rc -eq 0 ] && { echo "GATE PASS(0) [$G]: an element after a FENCE inside an ARBNO body backs into the FENCE as SPITBOL does, both modes"; exit 0; }
echo "GATE FAIL(1) [$G]: inside an ARBNO body a failure after a FENCE skips the FENCE (see above)"; exit 1
