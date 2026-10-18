#!/usr/bin/env bash
# test_gate_gc_a_register_resident_box_result_is_spilled_as_a_descr_across_its_poll.sh
# ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6.5b (cto, 2026-09-18; F6 step 4).
#
# WHAT THIS GATE HOLDS, AND THE DIAGNOSIS IT CORRECTS. F6 step 4's admission predicate was "the call's
# result is stored to a mapped frame slot before the poll" (CTO-75/76). 131 of the 210 allocating call
# sites cannot satisfy it, and the standing reading of that -- the ceo's CEO-884, and the cto's own
# bucket line in CTO-76 -- was that they are BLOCKED ON STEP 2 until the static map grows a slot vector
# naming which frame offsets are live DESCRs.
#
# ⛔ THAT DIAGNOSIS IS WRONG, AND A SLOT VECTOR WOULD NOT HAVE MOVED ONE OF THEM. The blocked sites are
# op_zres boxes: the call's result IS the box's result and it stays in rax:rdx, so it is not in the frame
# at all. A map that describes the frame perfectly still cannot see a value that never reached the frame.
# What those sites need is not a better description of the stack -- it is for the value to BE on the stack.
#
# ⛔⭐ SUPERSEDED IN PLACE 2026-09-18 BY 6.5c's RECORD FORM, AND THE REASON IS THE ceo's CEO-898. 6.5b's spill-PAIR
# put the cell INSIDE the word-swept range and relied on gc_zeta_frame to relocate it -- and gc_zeta_frame is
# exactly what F6 step 3 DELETES. The moment `conservative total` reaches 0, a cell that only the sweep visits is
# visited by NOTHING and keeps its pre-collection address through a moving collection. Five sites were on that
# footing (bb_assign_global, bb_assign_var_sub, bb_idx_get, bb_to_by, bb_rev_assign_var) and all five now take
# x86_rt_gc_poll_rec_res(), which hands the pair to the poll as its SHIELD ARRAY -- visited by rt_gc_visit_descr,
# a TYPED visit that relocates by the cell's own type field -- and RAISES the floor to the caller's own rsp so the
# cell is deliberately OUTSIDE the swept range. ⭐ THAT IS THE ARM-3 INVERSION: this gate used to prove the walker
# SWEEPS the range the cell lands in; it now proves the cell lies BELOW the floor, so the relocation arm 1
# measures cannot have come from the sweep. The cure survives the sweep's deletion by construction, which is the
# property the ceo's rank-0 row needs from this half.
#
# THE ORIGINAL MECHANISM, KEPT BECAUSE THE DIAGNOSIS IT CORRECTS IS THE POINT. x86_rt_gc_poll_res() spilled the
# rax:rdx pair as a 16-byte DESCR cell under rsp across the poll and reloads it after:
#     sub rsp,16 ; mov [rsp+0],rax ; mov [rsp+8],rdx ; call rt_gc_poll ; mov rax,[rsp+0] ; mov rdx,[rsp+8] ; add rsp,16
# gc_heap.c's precise root phase already walks [poll floor, stack top) as DESCR cells with relocation
# (gc_collect_ex, the pz && g_gc_seam_sp arm), so the spilled cell is visited and UPDATED by construction
# rather than by a new agreement. rsp stays 16-aligned across the sub, so the poll's call is ABI-correct.
#
# ⛔ WHAT THIS DOES **NOT** BUY, stated here so nobody over-reads the cure the way the block was over-read.
# It makes the RESULT visible. It does not make a poll safe "anywhere": any OTHER live collected-heap
# pointer sitting in a caller-saved register at the poll is still lost, and a callee-saved register holding
# one (section 6.5a measured r13 as that register) is still owed the SPILL RECORD of 6.5. The predicate is
# relaxed from "the result reaches a mapped slot" to "the result is in rax:rdx and nothing else live is in a
# register" -- a wider door, not an open one.
#
# THE ARMS. Arm 1 is the fail-once this cure was built against, run as a live measurement rather than cited:
# the witness prints stk=B, and printed stk= (a WRONG ANSWER, not a crash) when the same site took a bare
# x86_rt_gc_poll(). Arm 2 reads the emitted asm in mode 4 and requires the record idiom in order, because an
# emission that drops a reload is exactly the bug arm 1 catches only when a collection happens to fire. Arm 3
# is a second answer, under a forced collection on an allocating witness. ⭐ ARM 4 IS THE ONE THAT CHANGED AND
# IT IS NOW THE LOAD-BEARING ONE: it proves the cell lies BELOW the floor handed to the poll. Arm 1 measured the
# value surviving a MOVING collection; arm 4 says the word sweep cannot be what relocated it, because the sweep
# walks [floor, stack top) and the cell is not in that range -- so the relocation came through the shield array
# and rt_gc_visit_descr, a TYPED visit, and the cure therefore survives F6 step 3 deleting gc_zeta_frame. The
# planted violation lowers every floor back into the cell, which is precisely 6.5b, and all of them read RED.
# Each arm carries a PLANTED-VIOLATION check so this gate can say no (CTO-74: ten gates could not).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"
echo "  HOLDS: a box whose result lives in rax:rdx writes the pair as the record's ONE cell, hands it to the poll as the shield array and reloads it after, so the value the poll would otherwise clobber is both PRESERVED and RELOCATED -- by rt_gc_visit_descr reading the cell's own type field, NOT by the word sweep, because the floor handed to the poll leaves the cell outside the swept range. The map carries no slot vector and needs none for this class (6.5): a value that never reached the frame cannot be described by a frame map."

cat > "$T/w.sno" <<'EOF'
        DEFINE('inner(c)')
        DEFINE('outer(cs)')                                   :(both_end)
inner   stk    = c stk
        inner  = .stk                                         :(NRETURN)
outer   outer  = EVAL('LEN(1) . *inner(' cs ')')              :(RETURN)
both_end
        stk    = ''
        s      = 'AB'
        pat    = outer('c1') outer('c2')
        s POS(0) pat RPOS(0)                                  :S(YES)F(NO)
YES     OUTPUT = 'stk=' stk                                   :(END)
NO      OUTPUT = 'fail'
END
EOF

arm1_verdict() { [ "$1" = "stk=B" ] && return 0 || return 1; }
A1="$("$SCRIP" "$T/w.sno" 2>/dev/null | head -1)"
if arm1_verdict "$A1"; then echo "  ARM 1 answer: stk=B -- the polled op_zres site returns its result intact"
else echo "⛔ ARM 1 RED: the witness printed '$A1', want 'stk=B' -- the poll clobbered the box result (this is the exact fail-once the spill-pair cures; 'stk=' is the bare-poll signature, rax clobbered by the poll's own call)"; RC=1; fi
if arm1_verdict "stk="; then echo "⛔ ARM 1 PLANTED-VIOLATION DID NOT TRIP: the comparator accepts the known bare-poll reading"; RC=1
else echo "  ARM 1 planted-violation: the SAME comparator rejects the recorded bare-poll reading 'stk=' -- the arm discriminates"; fi

"$SCRIP" --compile "$T/w.sno" >"$T/w.s" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: mode 4 emission failed"; exit 2; }
IDIOM='sub[[:space:]]+rsp,[[:space:]]*32|mov[[:space:]]+qword ptr \[rsp \+ 0\],[[:space:]]*rax|mov[[:space:]]+qword ptr \[rsp \+ 8\],[[:space:]]*rdx|mov[[:space:]]+qword ptr \[rsp \+ 16\],[[:space:]]*r13|lea[[:space:]]+rdi,[[:space:]]*\[rsp \+ 0\]|lea[[:space:]]+rdx,[[:space:]]*\[rsp \+ 16\]|lea[[:space:]]+rcx,[[:space:]]*\[rsp \+ 32\]|call[[:space:]]+rt_gc_point_arr_probe_c|mov[[:space:]]+rax,[[:space:]]*qword ptr \[rsp \+ 0\]|mov[[:space:]]+rdx,[[:space:]]*qword ptr \[rsp \+ 8\]|mov[[:space:]]+r13,[[:space:]]*qword ptr \[rsp \+ 16\]|add[[:space:]]+rsp,[[:space:]]*32'
SITE="$(grep -n 'call *NV_SET_fn' "$T/w.s" | head -1 | cut -d: -f1)"
[ -n "$SITE" ] || { echo "⛔ GATE REFUSE(2) [$G]: the witness emitted no NV_SET_fn call -- this gate graded nothing"; exit 2; }
awk -v n="$SITE" 'NR>=n && NR<=n+34' "$T/w.s" > "$T/win.s"
SEQ="$(grep -oE "$IDIOM" "$T/win.s" | tr -d ' ' | paste -sd'|' -)"
WANT='subrsp,32|movqwordptr[rsp+0],rax|movqwordptr[rsp+8],rdx|movqwordptr[rsp+16],r13|leardi,[rsp+0]|leardx,[rsp+16]|learcx,[rsp+32]|callrt_gc_point_arr_probe_c|movrax,qwordptr[rsp+0]|movrdx,qwordptr[rsp+8]|movr13,qwordptr[rsp+16]|addrsp,32'
if printf '%s' "$SEQ" | grep -qF "$WANT"; then echo "  ARM 2 emission: the record idiom appears in order in mode 4 -- the pair written as the record's one cell, arr and the RAISED floor, the typed poll, and both reloads"
else echo "⛔ ARM 2 RED: the record idiom is not emitted in order in mode 4 -- a dropped reload loses the result whenever a collection fires; read: $SEQ"; RC=1; fi
BROKEN="$(printf '%s' "$SEQ" | sed 's/|movrax,qwordptr\[rsp+0\]//g')"
if printf '%s' "$BROKEN" | grep -qF "$WANT"; then echo "⛔ ARM 2 PLANTED-VIOLATION DID NOT TRIP: the sequence check passes with the reload removed"; RC=1
else echo "  ARM 2 planted-violation: removing the rax reload from the stream reds the same check -- the arm discriminates"; fi

cat > "$T/p.sno" <<'EOF'
        DEFINE('bump()')                                      :(BEND)
bump    G = G 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
        bump = .G                                             :(RETURN)
BEND
        N = 0
LOOP    N = N + 1
        bump()
        LT(N,3000)                                            :S(LOOP)
        OUTPUT = 'size=' SIZE(G)
END
EOF
A3="$(SCRIP_GC_STRESS=10 "$SCRIP" "$T/p.sno" 2>/dev/null | head -1)"
if [ "$A3" = "size=96000" ]; then echo "  ARM 3 answer under forced collection: size=96000"
else echo "⛔ ARM 3 RED: the allocating witness printed '$A3' under SCRIP_GC_STRESS=10, want 'size=96000'"; RC=1; fi

# ⛔ THE RECORD IS NOT ALWAYS SIXTEEN BYTES, AND READING ONLY THAT SIZE MADE THIS ARM MISREAD A CORRECT SITE
# (cfo 2026-09-19, found when the defer road's four SIGMA-record polls joined the witness): 6.5c's result record
# opens with `sub rsp,16` and hands the poll `[rsp + 16]`, while 6.5's SHIELD record (x86_rt_gc_poll_rec1, r13 and
# its length as one tagged cell, plus the kept rax and the kept protocol word below it) opens with `sub rsp,32`
# and hands `[rsp + 32]`.  Both satisfy the property this arm exists to hold -- the floor IS the rsp the record
# opened at, so every cell lies BELOW the swept range -- and the first spelling of the matcher knew only the
# 16-byte one, so the four sigma sites read `open == 0` and the arm called four correct records broken.  The test
# is now the EQUALITY the arm's own sentence states, over either size, and a size it does not know still reads
# open == 0 and reds rather than passing in silence.
# \u26d4 AND "EITHER SIZE" WAS STILL A WHITELIST, WHICH IS WHY IT BROKE A SECOND TIME THE SAME DAY (cfo
# 2026-09-19): the defer road's protocol pair became THREE tagged cells against the cto's measured blocker, the
# record opens with `sub rsp,48`, and a matcher spelled (16|32) read those four correct sites as open == 0 and
# called them broken -- the identical misread this comment was written about, one size later. The matcher now
# tests the PROPERTY the record must have rather than a list of sizes it has had: a positive multiple of 16 (the
# multiple of 16 is what keeps rsp parity at the poll's call, which is the other thing a record owes). A size that
# is not one still reads open == 0 and still reds, so nothing passes in silence, and the planted violation lowers
# EVERY floor by displacement rather than by the two displacements someone happened to have seen.
# hq_icon 2026-10-11: the record form x86_rt_gc_poll_rec_res now hands the saved r13 to rt_gc_point_arr_probe_c (the subject shield every
# result-preserving poll owes, cfo 2026-10-04), so a probe call that passes a shield array (lea rdi, [rsp + 0]) is a record too; x86_rt_gc_poll_res,
# which passes none (xor edi, edi) and keeps its cell AT the floor by design, is not one and is not counted.
floor_below_cell() {
    awk '
      /sub +rsp, +[0-9]+$/ { o=$0; sub(/.*rsp, +/, "", o); o=o+0; open=(o > 0 && o % 16 == 0) ? o : 0 }
      /lea +rcx, +\[rsp \+ [0-9]+\]/ { f=$0; sub(/.*\[rsp \+ /, "", f); sub(/\].*/, "", f); floor=f+0 }
      /lea +rdi, +\[rsp \+ 0\]/ { arr=1 }
      /xor +edi, +edi/ { arr=0 }
      /call +rt_gc_point_arr_c([^a-z_]|$)/ || (/call +rt_gc_point_arr_probe_c([^a-z_]|$)/ && arr) { n++; if (floor != open || open == 0) bad++; floor=-1; open=0; arr=0 }
      END { print (bad+0) " " (n+0) }
    ' "$1"
}
read -r FBAD FN < <(floor_below_cell "$T/w.s")
if [ "${FN:-0}" -gt 0 ] && [ "${FBAD:-1}" -eq 0 ]; then
  echo "  ARM 4 THE INVERSION: all $FN record(s) hand the poll a floor EQUAL to the rsp the record opened at, so the cell at [rsp+0] lies BELOW the swept floor. Arm 1 measured the value surviving a moving collection; this arm says the sweep cannot be what relocated it, because the sweep walks [floor, stack top) and the cell is not in it. The relocation came from rt_gc_visit_descr through the shield array -- a TYPED visit -- so this cure SURVIVES the deletion of gc_zeta_frame (F6 step 3), which 6.5b's spill-PAIR did not."
else echo "⛔ ARM 4 RED: $FBAD of ${FN:-0} record call(s) hand the poll a floor that is not the rsp the record opened at -- the cell is back inside the word-swept range, and it will be visited by nothing the moment the sweep is deleted"; RC=1; fi
sed -e 's/lea\( *\)rcx,\( *\)\[rsp + [0-9][0-9]*\]/lea\1rcx,\2[rsp + 0]/' "$T/w.s" > "$T/lowfloor.s"
read -r PBAD PN < <(floor_below_cell "$T/lowfloor.s")
if [ "${PBAD:-0}" -gt 0 ]; then echo "  ARM 4 planted-violation: lowering every floor to [rsp + 0] -- putting the cell back inside the sweep, which is exactly 6.5b -- makes $PBAD of $PN read RED against the same test"
else echo "⛔ ARM 4 PLANTED-VIOLATION DID NOT TRIP: a floor lowered into the cell read GREEN"; RC=1; fi

[ $RC -eq 0 ] && echo "✅ GATE PASS [$G]" || echo "⛔ GATE FAIL [$G]"
exit $RC
