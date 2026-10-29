#!/usr/bin/env bash
# test_gate_gc_the_spill_record_carries_a_callee_saved_heap_pointer_across_an_allocating_return.sh
# ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6.5 and 6.5c (cto, 2026-09-18; F6 step 4).
#
# WHAT THIS GATE HOLDS. Section 6.5 says the callee-saved registers are made visible AT THE POLL, never in a
# per-graph map: at an allocating return the poll pushes a SPILL RECORD of tagged cells and reloads the registers
# from it after the collector returns, so a relocated subject re-enters its register fixed up. Section 6.5a then
# MEASURED that ruling rather than asserting it, and named the residual the record must carry -- r13, the subject
# base, arriving not by its seeding mov after rt_match_enter but by a reload out of the frame cell the match
# stashed it in. This gate is that record, built and held.
#
# ⛔ THE TWO FACTS THE MECHANISM TURNS ON, both read off gc_heap.c rather than off a paragraph.
#   (1) rt_gc_point_arr_c(arr, n, r0, floor) ALREADY TAKES A SHIELD ARRAY AND A FLOOR. The cells of arr are visited
#       PRECISELY, by rt_gc_visit_descr, which relocates by the cell's own type field and handles an interior
#       pointer (gc_visit_one's DT_S arm counts interiors and registers &d->s for rewrite). So the record needs no
#       new runtime symbol, no map change and no agreement: a DESCR cell handed to the poll as arr[0] is visited
#       by type and updated by construction.
#   (2) THE FLOOR IS WHAT KEEPS THE HAZARD OUT. gc_zeta_frame walks [floor, stack top) EIGHT BYTES AT A TIME and
#       its fallback arm is `if (gc_blk_of(*loc)) rt_gc_visit_raw(loc)` -- ANY word inside a heap block is visited
#       raw AND registered for rewrite when the block slides. An untagged integer left in that range therefore
#       comes back as a relocated address. The record hands the poll the CALLER's own rsp as the floor, so the
#       record and the raw scratch below it are OUT of the word-swept range and only the TAGGED cell is visited.
#       That is why section 6.5 says tagged cells and why it cannot be relaxed: this class of site returns a long,
#       not a DESCR, and spilling that long as a descriptor pair is the corruption, not the cure.
#
# THE FAIL-ONCE, RUN LIVE RATHER THAN CITED (arm 1). With the SAME sites taking the 6.5b spill-PAIR poll instead
# of the record, a SNOBOL4 deferred LEN(*N) match under SCRIP_GC_STRESS=1 printed its captures as 0xDB poison
# bytes -- a WRONG ANSWER, not a crash: the subject block slid under the match and r13 kept the dead address.
# With the record it prints X=AAA Y=AABBBBBCCCCC in both media.
#
# ARMS (all blocking, each with a planted violation -- CTO-74: ten gates could not say no).
#  1 ANSWER: the fail-once witness, under a forced collection, in mode 3 AND mode 4.
#  2 EMISSION: the record idiom in order in mode 4 -- the tagged cell, the scratch, the four arguments, the call,
#    the register reload. A dropped reload is the bug arm 1 catches only when a collection happens to fire.
#  3 COVERAGE, NOT A SPOT CHECK: every site the callee-saved census names as a COLLECTED-HEAP POINTER in a
#    callee-saved register at an allocating return must carry the record. A cure that covered nine of ten sites
#    would pass a spot check and lose an object at the tenth. A site is covered when the FIRST call after its
#    allocating return, before any jmp or ret, is the record's rt_gc_point_arr_c: by structure, not by a line window
#    (cto 2026-09-25: a 22-line window went red when af773a80e put the six-line in-line g_gc_pending test ahead of the
#    record, which it had moved to line 24 with nothing else in between).
#  4 THE FLOOR: the floor handed to the poll is exactly the rsp the record opened at, so the untagged scratch is
#    below it. A floor inside the record is the hazard above, emitted.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
CENSUS="$HERE/util_gc_callee_saved_census.py"; [ -f "$CENSUS" ] || { echo "⛔ GATE REFUSE(2) [$G]: $CENSUS absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"

echo "  HOLDS: at an allocating return inside a pattern, the collected-heap pointer sitting in a callee-saved register is spilled as ONE TAGGED DESCR cell handed to the poll as its shield array, so the collector visits it by type and relocates it -- and the FLOOR handed to the poll is the caller's own rsp, which keeps the untagged result below the word-swept range instead of inside it."

cat > "$T/w.sno" <<'EOF'
        I = 0
LP      I = LT(I,400) I + 1                                   :F(DONE)
        JUNK = DUPL('z',120)                                  :(LP)
DONE    JUNK =
        S = DUPL('A',5) DUPL('B',5) DUPL('C',5)
        N = 3
        S LEN(*N) . X REM . Y                                 :F(NO)
        OUTPUT = 'X=' X ' Y=' Y                               :(END)
NO      OUTPUT = 'fail'
END
EOF
WANT_ANS='X=AAA Y=AABBBBBCCCCC'
ans_ok() { [ "$1" = "$WANT_ANS" ]; }

A3="$(SCRIP_GC_STRESS=1 "$SCRIP" "$T/w.sno" 2>/dev/null | head -1)"
"$SCRIP" --compile --out="$T/w.s" "$T/w.sno" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode 4 emission failed"; exit 2; }
A4=""
if gcc -c "$T/w.s" -o "$T/w.o" 2>/dev/null && gcc "$T/w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/w" 2>/dev/null; then
    A4="$(SCRIP_GC_STRESS=1 "$T/w" 2>/dev/null | head -1)"
else echo "⛔ GATE REFUSE(2) [$G]: mode 4 assemble/link failed"; exit 2; fi
if ans_ok "$A3" && ans_ok "$A4"; then echo "  arm 1 PASS: the deferred LEN(*N) match under SCRIP_GC_STRESS=1 answers '$WANT_ANS' in BOTH media -- the subject survived a moving collection taken inside the pattern blob"
else echo "⛔ arm 1 RED: m3='$A3' m4='$A4', want '$WANT_ANS' -- the subject block slid under the match and the callee-saved register kept the dead address (the recorded bare-pair reading prints the captures as 0xDB poison)"; RC=1; fi
if ans_ok "X=$(printf '\333\333\333') Y="; then echo "⛔ arm 1 PLANTED-VIOLATION DID NOT TRIP: the comparator accepts a poisoned capture"; RC=1
else echo "  arm 1 planted-violation: the SAME comparator rejects a poisoned capture -- the arm discriminates"; fi

SITE="$(grep -n 'call *rt_pat_prim_int' "$T/w.s" | head -1 | cut -d: -f1)"
[ -n "$SITE" ] || { echo "⛔ GATE REFUSE(2) [$G]: the witness emitted no rt_pat_prim_int call -- this gate graded nothing"; exit 2; }
awk -v n="$SITE" 'NR>=n && NR<=n+30' "$T/w.s" > "$T/win.s"
IDIOM='sub[[:space:]]+rsp,[[:space:]]*32|mov[[:space:]]+dword ptr \[rsp \+ 0\],[[:space:]]*2|mov[[:space:]]+dword ptr \[rsp \+ 4\],[[:space:]]*r15d|mov[[:space:]]+qword ptr \[rsp \+ 8\],[[:space:]]*r13|mov[[:space:]]+qword ptr \[rsp \+ 16\],[[:space:]]*rax|lea[[:space:]]+rdi,[[:space:]]*\[rsp \+ 0\]|lea[[:space:]]+rcx,[[:space:]]*\[rsp \+ 32\]|call[[:space:]]+rt_gc_point_arr_c|mov[[:space:]]+r13,[[:space:]]*qword ptr \[rsp \+ 8\]|add[[:space:]]+rsp,[[:space:]]*32'
SEQ="$(grep -oE "$IDIOM" "$T/win.s" | tr -d ' ' | paste -sd'|' -)"
WANT='subrsp,32|movdwordptr[rsp+0],2|movdwordptr[rsp+4],r15d|movqwordptr[rsp+8],r13|movqwordptr[rsp+16],rax|lerdi,[rsp+0]'
WANT='subrsp,32|movdwordptr[rsp+0],2|movdwordptr[rsp+4],r15d|movqwordptr[rsp+8],r13|movqwordptr[rsp+16],rax|leardi,[rsp+0]|learcx,[rsp+32]|callrt_gc_point_arr_c|movr13,qwordptr[rsp+8]|addrsp,32'
if printf '%s' "$SEQ" | grep -qF "$WANT"; then echo "  arm 2 PASS: the record idiom appears in order in mode 4 -- {v=DT_S, slen=r15d, s=r13} as the tagged cell, the untagged result in the scratch below it, arr/n/r0/floor, the call, and the r13 reload"
else echo "⛔ arm 2 RED: the record idiom is not emitted in order in mode 4; read: $SEQ"; RC=1; fi
BROKEN="$(printf '%s' "$SEQ" | sed 's/|movr13,qwordptr\[rsp+8\]//g')"
if printf '%s' "$BROKEN" | grep -qF "$WANT"; then echo "⛔ arm 2 PLANTED-VIOLATION DID NOT TRIP: the sequence check passes with the r13 reload removed"; RC=1
else echo "  arm 2 planted-violation: removing the r13 reload from the stream reds the same check -- without it the register keeps the pre-collection address and arm 1's answer is poison"; fi

cat > "$T/d.sno" <<'EOF'
        S = 'AAAAABBBBBCCCCC'
        N = 3
        C = 'AB'
        S LEN(*N) . X1                              :F(D1)
D1      S ANY(*C) . X2                              :F(D2)
D2      S SPAN(*C) . X3                             :F(D3)
D3      S BREAK(*C) . X4                            :F(D4)
D4      S TAB(*N) . X5                              :F(D5)
D5
END
EOF
"$SCRIP" --compile --out="$T/d.s" "$T/d.sno" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the deferred-pattern witness did not emit"; exit 2; }
python3 "$CENSUS" "$T/d.s" > "$T/c.txt" 2>&1
HEAPN="$(grep -oE '^SUMMARY .*' "$T/c.txt" | tr ' ' '\n' | awk -F= '$1=="heap"{print $2}')"
cover_uncovered() {
    local asm="$1" rep="$2" bad=0
    while read -r ln; do
        [ -n "$ln" ] || continue
        awk -v n="$ln" 'NR<=n{next} /(^|[ \t;])(jmp|ret)([ \t]|$)/{exit} /call /{ok=($0 ~ /call *rt_gc_point_arr_c/); exit} END{exit !ok}' "$asm" || bad=$((bad+1))
    done < <(grep -oE 'line=[0-9]+' "$rep" | cut -d= -f2)
    echo "$bad"
}
if [ -n "${HEAPN:-}" ] && [ "$HEAPN" -gt 0 ]; then
    grep -E '^ +[^ ]+\.s graph=.* line=[0-9]+ r[0-9]+ ' "$T/c.txt" > "$T/heap.txt"
    NH=$(wc -l < "$T/heap.txt")
    UNCOV=$(cover_uncovered "$T/d.s" "$T/heap.txt")
    if [ "$NH" -gt 0 ] && [ "$UNCOV" -eq 0 ]; then echo "  arm 3 PASS: all $NH site(s) the census names as a COLLECTED-HEAP POINTER in a callee-saved register at an allocating return carry the record (heap=$HEAPN over the deferred-pattern witness) -- coverage over the named class, not a spot check at one site"
    else echo "⛔ arm 3 RED: $UNCOV of $NH heap site(s) reach their allocating return with NO spill record -- a register holding a collected-heap pointer there is a root the collector cannot fix up"; sed 's/^/    /' "$T/heap.txt" | head -6; RC=1; fi
    PL=$(awk 'BEGIN{n=0} /call *rt_gc_point_arr_c/{next} {print} END{}' "$T/d.s" > "$T/d_noprec.s"; cover_uncovered "$T/d_noprec.s" "$T/heap.txt")
    if [ "$PL" -eq "$NH" ]; then echo "  arm 3 planted-violation: with every record call removed from the stream all $NH site(s) read uncovered -- the arm discriminates"
    else echo "⛔ arm 3 PLANTED-VIOLATION DID NOT TRIP: $PL of $NH read uncovered with every record call removed"; RC=1; fi
else echo "⛔ arm 3 RED: the deferred-pattern witness reports heap=${HEAPN:-0} -- the population carries none of the class this gate exists to cover, so arms 1 and 2 grade one site and nothing states the rest are covered"; RC=1; fi

floor_mismatches() {
    local asm="$1"
    awk '
      /sub +rsp, +[0-9]+/   { match($0, /sub +rsp, +[0-9]+/); n=$0; sub(/.*sub +rsp, +/, "", n); sub(/[^0-9].*/, "", n); open=n+0 }
      /lea +rcx, +\[rsp \+ [0-9]+\]/ { f=$0; sub(/.*\[rsp \+ /, "", f); sub(/\].*/, "", f); floor=f+0 }
      /call +rt_gc_point_arr_c/ { calls++; if (floor != open || open == 0) bad++ ; floor=-1 }
      END { print (bad+0) " " (calls+0) }
    ' "$asm"
}
read -r BAD NCALL < <(floor_mismatches "$T/d.s")
if [ "${NCALL:-0}" -gt 0 ] && [ "${BAD:-1}" -eq 0 ]; then
    echo "  arm 4 PASS: every one of the $NCALL record(s) hands the poll a floor EQUAL to the rsp the record opened at, so the tagged cell at +0 and the untagged scratch at +16 both lie BELOW the swept floor and gc_zeta_frame's raw arm never reaches the untagged word"
else echo "⛔ arm 4 RED: $BAD of ${NCALL:-0} record call(s) hand the poll a floor that is NOT the rsp the record opened at -- a floor inside the record puts the untagged result into the word-swept range, where any word landing in a heap block is visited raw and rewritten when the block slides"; RC=1; fi
sed 's/lea\( *\)rcx,\( *\)\[rsp + 32\]/lea\1rcx,\2[rsp + 16]/' "$T/d.s" > "$T/d_lowfloor.s"
read -r PBAD PCALL < <(floor_mismatches "$T/d_lowfloor.s")
if [ "${PBAD:-0}" -gt 0 ] && [ "$PCALL" -eq "$NCALL" ]; then echo "  arm 4 planted-violation: lowering every floor to [rsp + 16] -- inside the record, above the scratch -- makes $PBAD of $PCALL read RED against the same test"
else echo "⛔ arm 4 PLANTED-VIOLATION DID NOT TRIP: a floor lowered into the record read GREEN ($PBAD of $PCALL)"; RC=1; fi

[ $RC -eq 0 ] && echo "✅ GATE PASS [$G]" || echo "⛔ GATE FAIL [$G]"
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
