#!/usr/bin/env bash
# test_gate_gc_a_callee_saved_register_at_an_allocating_return_is_named_not_assumed.sh
# -- F1 RUNG 3, THE REGISTERS (cto 2026-09-18, the ceo's row (1) of CEO-845; row
# gc-frame-placement-proof-...-and-callee-saved-registers-are-mapped; design
# .github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md sections 6.3 and 6.5 and section 7 F1; law RULES.md FACT RULE
# THE COLLECTOR GUESSES NOTHING, CEO-812).
#
# ⛔ WHY THIS GATE IS NOT THE ROW AS IT WAS HANDED TO ME, AND THE DISAGREEMENT IS THE POINT. The row says "the map
# must carry the pointer-bearing callee-saved registers -- gc_frame_map_t has one reserved quad and nothing reads
# it", which is section 7 F1's wording. Section 6.5 of the SAME frozen page says the opposite in as many words:
# "NO REGISTER MASK: the callee-saved registers are made visible at the poll itself, not in a map", with a spill
# record of tagged cells below RSP. I wrote both, on the same day, and neither was held by a check -- which is the
# fourth time in two days that a fact in this area turned out to be living in a paragraph. So this gate does not
# pick a side by argument. IT MEASURES THE ONE THING THAT DECIDES IT, and the measurement is unambiguous:
#   A REGISTER'S CONTENT AT AN ALLOCATING RETURN IS A PROPERTY OF THE SITE, NOT OF THE GRAPH.
# Two facts, both read off the emitted code by util_gc_callee_saved_census.py and both printed by arm 6:
#   (a) SITE-DEPENDENCE. There are graphs in which the same register is live across one allocating return and dead
#       across another. Section 6.3's map is ONE PER GRAPH. A per-graph mask would therefore have to be the union
#       over that graph's sites, and at the site where the register is dead the union tells the collector to visit
#       a register holding whatever the last box left in it. That is a GUESS, in the one place Lon's rule forbids
#       guessing, and it is worse than no mask at all -- a missing root loses an object, a spurious root reads an
#       arbitrary word as a pointer.
#   (b) PASS-THROUGH. At most allocating returns most callee-saved registers were never written by the graph at
#       all: the value belongs to an ANCESTOR frame, still sitting in the register because nothing here touched it.
#       No map of THIS graph can name it, because the fact is not this graph's.
# THE RULING THIS GATE HOLDS: the register facts do NOT go in the map, section 6.5 stands, section 7 F1's clause
# is the stale one, and the map's fourth quad carries a FRAME fact only (map_off since CTO-88, ARCH-GC 6.2h; it was
# the zero `reserved` quad before) -- arm 6 reds if a register mask is ever
# smuggled into it. What the registers DO need is a tag at the site, which is the spill record, and that is the
# polls row's build, not this one's.
#
# ⭐ AND WHAT THE MEASUREMENT FOUND ON THE WAY, which is worth more than the ruling. Section 6.5 asserts that r13
# holds the subject base and that r14/r15 are the subject CURSOR and LENGTH and therefore raw. The register half
# is confirmed -- r14 and r15 are seeded 32-bit (mov r14d, dword ptr [...]; cmp eax, r15d), and a 32-bit define
# zero-extends, so a 64-bit pointer cannot survive in either. But the ROUTE in that paragraph is wrong: the
# pointer does not reach an allocating return through the seeding `mov r13, rax` after rt_match_enter -- that one
# is dead across every allocating call in the population. It arrives through a RELOAD out of the frame cell the
# match stashed it in, and through the `push r13  # outer_Σ` that saves the CALLER's subject. A whitelist that
# accepted "it came from a tagged cell" as proof of rawness would have blessed every one of those, because a
# cell's DESCR tag is the truth about the CELL and it does not travel to the register: the collector can relocate
# the block, fix up the cell, and leave the register pointing at the old address. The census therefore refuses to
# call a copy raw, and arm 5 holds the copy count at its measured ceiling so the class cannot grow in silence.
#
# ⛔ THE COPY CEILING HAS BEEN RE-BASED THREE TIMES AND NO MOVE WAS THE CLASS GROWING -- A COUNT IS NOT COMPARABLE
# ACROSS A CHANGE OF ITS CRITERION, and both changes were the population getting honest.
#   83 -> 108 (cto 2026-09-18, section 6.5c): the seven hermetic witnesses carry no DEFERRED pattern, so this gate
#     read heap=0 and had NEVER GRADED ONE INSTANCE of the class it exists to hold; the residual it ratcheted was
#     entirely CELL copies. A deferred-pattern witness joined the population and reads heap=5 -- and reads the same
#     heap=5 on ORIGIN, so it was a two-day population gap and not something a cure made. Arm 2b now reds on heap=0.
#   108 -> 133 (cto 2026-09-18, section 6.5d): the ALLOCATING SET itself was undercounted. Its derivation recorded
#     `call` edges only, and the hand-written asm allocators in rtx_alloc.s reach the carve by a TAIL JUMP, so they
#     and the 99 functions reaching the heap only through them read NON-ALLOCATING. Widening the derivation to
#     inter-function tail jumps took this gate's population from 528 allocating call sites to 582 -- the SAME
#     witnesses, 54 sites that were never graded before. Every one of the 25 new copy readings is at a site that was
#     always allocating and was never counted.
#   133 -> 185 (cto 2026-09-19, row gc-the-blob-frame-interior-...; Lon: no BB is entered from C after the original
#   invocation): the SNOBOL4 match-end pump is BOX-DRIVEN now -- rt_match_end_all (one allocating call per match end,
#   the C pump entering bodies from C) became rt_dcap_end_ok_open + rt_dcap_land_γ + rt_dcap_land_ω (three), the box
#   entering the capture target itself through an indirect jmp. 582 -> 594 sites is exactly +2 per IR_MATCH_END over
#   the witnesses, and the census reads every callee-saved register live across the box's indirect entry (the same
#   upper-bound reading a ret produces), so the SAME copies (r13 = outer subject, r14/r15 cursors, r12 pend, rbx)
#   count at twelve more sites. No new register, no new defining form: arm 3 still reads 0 unclassified.
#
# ARMS (all blocking). (1) SELFTEST: the census's own arms, including its planted ones -- an instrument not shown
# to discriminate has measured nothing. (2) POPULATION: one witness per frontend, all seven, compiled to mode-4
# asm; the census reads a non-zero allocating-call population out of them and prints it. (3) UNCLASSIFIED = 0:
# every owned register live across an allocating return has a defining form the census can name. (4) UNDERSTOOD:
# zero mnemonics the census's def/use model does not know -- an unknown instruction is silently assumed to leave
# the six registers alone, which is the same shape as the hole this whole row is about. (5) COPY RATCHET: the
# named residual, held at its measured ceiling. (6) THE RULING: the map's fourth quad is zero in every emitted map
# in BOTH media and nothing in src/ reads gc_frame_map_t.reserved, and the site-dependence count that justifies
# that is printed beside it. (7) PLANTED: an .s carrying a register defined by an un-whitelisted form, live across
# an allocating call, must make the census RED end to end -- not only inside its own selftest.
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
#   185 -> 287 (cfo 2026-09-19, row gc-rt-c-c-to-bb-entries-...; the SAME mechanism as the move above, MEASURED ON
#   THREE TREES WITH THE SAME WITNESS SET RATHER THAN REASONED): landing 3 put the COMPUTED-NAME CAPTURE TARGET and
#   the TEN MATCH-TIME PRIMITIVES on the tree's one open/land pair, so the deferred witness's LEN/ANY/SPAN/BREAK/TAB
#   each enter their target through the box's indirect jmp instead of calling one C leaf.  80e3a942e (landing 2):
#   594 sites, not-a-pointer 317, copies 185, heap 6.  f0368fb08 (landing 3): 612 sites, 332, 339, heap 6.
#   41323bc8e (landing 5, the entry glue's record as tagged cells): 612 sites, 372, 287, heap 6.  NO NEW REGISTER
#   AND NO NEW DEFINING FORM -- arm 3 reads 0 unclassified on all three and heap stays 6 -- so the 185 -> 339 half is
#   eighteen more allocating call sites reading the SAME copies (r13 the outer subject, r14/r15 the cursors, r12 the
#   pend, rbx), and the 339 -> 287 half is this seat's cure giving 52 back: the glue's pops became tagged-cell loads
#   and r15 is now reloaded 32-bit, which the census reads as D32, provably not a pointer (that is the 332 -> 372).
#   ⛔ THE CEILING IS RE-MEASURED, NOT RAISED TO FIT: it is the residual the spill record of section 6.5 must carry,
#   and it falls when a site stops keeping a heap pointer in a callee-saved register across an allocating return --
#   never because a count was uncomfortable.  The census's own rule stands: "it came from a tagged cell" is not an
#   argument that a register is raw, it is the argument that the register needs a tag OF ITS OWN at the site.
#   287 -> 289 (cfo 2026-09-19, row gc-rt-c-c-to-bb-entries-...; THE COUNT BECOMING HONEST, NOT THE CLASS GROWING,
#   AND THE INSTRUMENT'S OWN TWO COUNTS DISAGREEING IS HOW IT WAS FOUND): the census composes a class NAME
#   recursively -- a reload out of a slot whose store came from a register that was itself reloaded out of a slot
#   reads CELL:CELL:POP -- and the tally that feeds THIS ceiling peeled ONE `CELL:` prefix, so such a reading left
#   with a tail of CELL:POP, matched no set, and fell to the tally's "unclassified" bucket. The SUMMARY prints
#   unclassified as the length of the unclassified LIST, which such a reading never joins (the census files it in the
#   COPY list), so the two readings -- both r12 at rt_dcap_land_γ/ω in n27_match_end of the SNOBOL4 witness, this
#   seat's own match-end road -- were counted by NEITHER blocking arm: not arm 5's ratchet, not arm 3's zero. The
#   copy LIST held 289 while this ceiling was grading 287 and no arm could say so. Cured at the instrument: bucket()
#   peels every prefix (hoisted to module scope so the selftest grades the REAL rule and not a second copy of it),
#   the census REFUSES rc=2 when the tally and the list disagree, a 14th selftest arm plants a CELL:CELL:POP chain
#   and reds on the one-prefix peel, and the SUMMARY carries bucket_unclassified= so the two counts are visible side
#   by side in the one line the gates parse. NO NEW SITE, NO NEW REGISTER, NO NEW DEFINING FORM: 612 sites, raw 372,
#   heap 6 are unchanged from 41323bc8e -- only the two readings that were always there and were never counted.
#   ⛔ AND THE RESIDUAL IS NOW NAMED BY FILE AND GRAPH in the census report (`COPY <file> total=N: <graph>=n ...`),
#   because a residual nobody can attribute is a residual nobody cures: 166 of the 289 are the deferred-pattern
#   witness's primitive and capture roads, 43 the SNOBOL4 witness, and the rest the ceo's frontends.
#   289 -> 284 (cto 2026-09-23, CTO-143, row icon-gc-the-standing-chop-...; FIVE MOVES IN FOUR DAYS, EVERY ONE NAMED BY
#   COMMIT, FILE, GRAPH AND REGISTER FROM A TWO-TREE CENSUS -- the gate's own eight witnesses compiled by a fresh worktree
#   build at each commit and read by ONE census (HEAD's), bisected commit by commit, never a bracket): this ceiling stood at
#   289 while origin read 271, 282, 293 and 295 in turn, and the red that finally fired (295) was three landings old.
#   289 -> 271 at 25d0955d8 (rbx STEP 1, 09-20): the Icon witness 36 -> 18, the whole rbx/POP class of 18 gone -- the
#   by-name call's rbx anchor left the register, so main, n31_to, the deref/coerce/binop/call_proc_staged sites each lost
#   one reading. A FALL, the class shrinking. 271 -> 282 at 2344d2dc7 (ten of the ceo's twelve rejected safe-point sites take
#   their poll form, 09-22): the Pascal witness 13 -> 24, r13/CELL 66 -> 77, sites unchanged at 612 -- main, n20_binop_test,
#   n23_call, n24_assign, n27_binop, n28_assign, n31_call each read ONE MORE r13 copy, and the defining form is the new poll's
#   own spill-record reload (mov r13,[rsp+N] after rt_gc_point_arr_c), which this census files as CELL. 282 -> 293 at
#   e42cc0909 (two bare polls become rec_sigma where the subject base is live, 09-22): the Icon witness 18 -> 29, r13/CELL
#   77 -> 88, the SAME shape at g, main, n37_deref, n39_call_proc_staged, n40_deref, n41/n42_coerce_numeric, n43_binop,
#   n99_call_icon. 293 -> 295 at 3cc697fbc (hq_pascal, global integer/real scalars zero-initialised, 09-23): two NEW Pascal
#   assign nodes n19_assign and n21_assign, one r12/CELL reading each, sites 618 -> 620. 295 -> 284 at 79b7aa13d (hq_icon,
#   bb_deref's ordinary-branch poll no longer assumes r13/r15d hold the scan subject, 09-23): e42cc0909's eleven Icon
#   readings gone again, r13/CELL 88 -> 77, the same nine graphs. ⛔ TWENTY-TWO OF THE 284 ARE THE SANCTIONED POLL'S OWN
#   RELOAD OF r13 (the cfo's 92.8 percent class, CFO-149): a register reloaded out of the poll's tagged spill cell reads as
#   "a copy of something else" under this census's rule, so a poll batch that ADDS polls RAISES this count while rooting more,
#   and a poll batch that removes a wrong-assumption rec_sigma LOWERS it. The count therefore moves with the safe-point chop
#   in BOTH directions and a move is not a verdict on the chop until its graphs are read; the ceiling is re-cut to the
#   measurement, never held against a landing that added a sanctioned reload. By file at 284: defer.sno 166, sno 43, pas 26,
#   pl 22, icn 18, raku 5, sc 2, reb 2.
COPY_CEILING=${COPY_CEILING:-284}

echo "  HOLDS: what sits in a callee-saved register at an allocating return is NAMED from the emitted code, not assumed from a paragraph -- and it is a property of the SITE, not of the graph, so it does not go in the per-graph map. gc_frame_map_t.reserved stays zero with no reader; the registers get a tag at the poll (section 6.5's spill record), which is the polls row's build."

python3 "$CENSUS" --selftest > "$T/self.txt" 2>&1
if [ $? -eq 0 ] && grep -q 'arms green' "$T/self.txt"; then echo "  arm 1 PASS: census $(grep -o 'SELFTEST .*' "$T/self.txt")"
else echo "  arm 1 RED: the census's own selftest is not green -- an instrument not shown to discriminate has measured nothing"; sed 's/^/      /' "$T/self.txt" | head -8; RC=1; fi

cat > "$T/w.icn" <<'EOF'
procedure f(a, b)
   return a + b;
end
procedure g(n)
   local s, i;
   s := 0;
   every i := 1 to n do s := s + f(i, 2);
   return s;
end
procedure main()
   write(g(5));
end
EOF
cat > "$T/w.sno" <<'EOF'
        DEFINE('F(X)')                              :(F_END)
F       F = X + 1                                   :(RETURN)
F_END
        S = 'hello world'
        S 'hello' = 'goodbye'                       :F(DONE)
        OUTPUT = S
        OUTPUT = F(41)
DONE
END
EOF
cat > "$T/w.pl" <<'EOF'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
:- app([1,2],[3],X), write(X), nl.
EOF
cat > "$T/w.sc" <<'EOF'
function Double(n) {
    Double = n + n; return;
}
OUTPUT = Double(21);
EOF
cat > "$T/w.raku" <<'EOF'
sub add($a, $b) {
    return $a + $b;
}
sub main() {
    my $s = 0;
    for 1..5 { $s = add($s, 2); }
    say($s);
}
EOF
cat > "$T/w.pas" <<'EOF'
program sumloop;
var
  i, s: integer;
function add(a, b: integer): integer;
begin
  add := a + b
end;
begin
  s := 0;
  for i := 1 to 5 do
    s := add(s, 2);
  writeln(s)
end.
EOF
cat > "$T/w.reb" <<'EOF'
function main()
  OUTPUT := 3 + 4
end
EOF
cat > "$T/w.defer.sno" <<'EOF'
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
asm=""
for w in w.icn w.sno w.pl w.sc w.raku w.pas w.reb w.defer.sno; do
    if timeout -k 5 120 "$SCRIP" --compile --out="$T/$w.s" "$T/$w" </dev/null >/dev/null 2>&1 && [ -s "$T/$w.s" ]; then asm="$asm $T/$w.s"
    else echo "  arm 2 RED ($w: mode 4 did not emit asm -- this frontend could not be censused)"; RC=1; fi
done
nasm=$(echo $asm | wc -w)
python3 "$CENSUS" $asm > "$T/c.txt" 2>&1
sum=$(grep '^SUMMARY ' "$T/c.txt" | tail -1)
val(){ echo "$sum" | tr ' ' '\n' | awk -F= -v k="$1" '$1==k{print $2}'; }
sites=$(val sites); unc=$(val unclassified); unk=$(val unknown_mnemonics); cop=$(val copies); dep=$(val site_dependent_pairs); gr=$(val graphs); raw=$(val raw); heap=$(val heap)
if [ "$nasm" -eq 8 ] && [ -n "$sites" ] && [ "$sites" -ge 100 ]; then
    echo "  arm 2 PASS: 7 of 7 frontends plus the DEFERRED-PATTERN witness censused ($nasm files), $sites allocating call site(s) over $gr graph(s) -- owned readings: provably_not_a_pointer=$raw a_copy_of_something_else=$cop heap=$heap"
else echo "  arm 2 RED: censused $nasm of 8 witnesses, sites=${sites:-none} (a census over an empty population reports zero violations while measuring nothing)"; RC=1; fi
if [ -n "$heap" ] && [ "$heap" -gt 0 ]; then echo "  arm 2b PASS: $heap owned reading(s) in this population ARE a collected-heap pointer in a callee-saved register at an allocating return -- the class this gate exists to hold is EXERCISED, not merely declared"
else echo "  arm 2b RED: heap=${heap:-0} -- the population carries no collected-heap pointer in any callee-saved register at any allocating return, so arms 3 and 5 grade a class that never occurs in it. The seven hermetic witnesses read heap=0 for exactly this reason and the gap was invisible until a DEFERRED pattern was censused (section 6.5c)."; RC=1; fi
if [ "${unc:-1}" = 0 ]; then echo "  arm 3 PASS: 0 unclassified -- every owned register live across an allocating return has a defining form the census can name"
else echo "  arm 3 RED: $unc register reading(s) live across an allocating return whose content the census cannot name:"; grep 'UNCLASSIFIED' "$T/c.txt" | head -6 | sed 's/^/    /'; RC=1; fi
if [ "${unk:-1}" = 0 ]; then echo "  arm 4 PASS: 0 mnemonics outside the census's def/use model"
else echo "  arm 4 RED: $unk instruction(s) the census does not model -- it would silently assume they leave the six callee-saved registers alone, which is the same shape as the hole this row is about:"; grep 'UNDERSTOOD=NO' "$T/c.txt" | sed 's/^/    /'; RC=1; fi
if [ -n "$cop" ] && [ "$cop" -le "$COPY_CEILING" ]; then echo "  arm 5 PASS: $cop owned reading(s) are a copy of something else, at or under the measured ceiling $COPY_CEILING -- the NAMED residual the spill record of section 6.5 must carry, held so it cannot grow in silence"
else echo "  arm 5 RED: the copy residual is ${cop:-?} against a ceiling of $COPY_CEILING -- a register holding an untagged copy across a collection is a root the collector cannot fix up"; RC=1; fi

badq=0; qpop=""
for w in w.icn w.sno w.pl w.sc w.raku w.pas w.reb w.defer.sno; do
    [ -s "$T/$w.s" ] || continue
    n=$(grep -c '^\.Lgcmap_[^ ]*:$' "$T/$w.s")
    nz=$(awk 'BEGIN{c=-1} /^\.Lgcmap_[^ ]*:$/{c=0;next} c>=0 && /^[ \t]*\.quad/{c++; if(c==1){fb=int($2/4294967296)} if(c==4){ if($2+0 > fb || $2+0 < 0) bad++ ; c=-1}} END{print bad+0}' "$T/$w.s")
    qpop="$qpop $w:$n"
    [ "${nz:-0}" -gt 0 ] && { echo "  arm 6 RED ($w: $nz emitted map(s) carry a fourth quad LARGER THAN frame_bytes -- the fourth quad is map_off, the cell's offset from the frame's region base (ARCH-GC 6.2h, CTO-88), a frame fact the walker reads; a value outside [0, frame_bytes] is not an offset and a register mask smuggled into the per-graph map is exactly what the site-dependence measurement says cannot be right)"; badq=1; }
done
readers=$(grep -rn -e '->reserved' -e '\.reserved' -e 'regmask' -e 'reg_mask' "$ROOT/src" 2>/dev/null | grep -vc '^$')
if [ "$badq" = 0 ] && [ "$readers" -eq 0 ]; then
    echo "  arm 6 PASS: the map's fourth quad is map_off in every emitted map, never above frame_bytes (maps per witness --$qpop), and no reader of a reserved or register-mask field exists in src/. THE MEASUREMENT BEHIND THE RULING: $dep (graph, register) pair(s) over $gr graphs are live across one allocating return of a graph and dead across another, so a per-graph mask would have to be a union that guesses at one of its own sites; and most callee-saved registers at most sites were never written by the graph at all, so the value is an ancestor's and no map of this graph can name it."
else [ "$badq" = 0 ] && echo "  arm 6 RED: gc_frame_map_t.reserved has $readers reader(s) in src/ -- the register facts are being moved into the per-graph map, which section 6.5 and the site-dependence measurement both say cannot be done without guessing"; RC=1; fi

cat > "$T/plant.s" <<'EOF'
 .text
p_α:
 push r12
 call rt_gcheap_alloc
 mov r12, rax
 call rt_gcheap_alloc
 mov rdi, r12
 pop r12
 ret
EOF
python3 "$CENSUS" "$T/plant.s" > "$T/plant.txt" 2>&1; prc=$?
if [ "$prc" -ne 0 ] && grep -q 'UNCLASSIFIED' "$T/plant.txt"; then echo "  arm 7 PASS: a planted register defined by an un-whitelisted form, live across an allocating return, makes the census RED end to end (rc=$prc) -- the arms above are not an inert seam"
else echo "  arm 7 RED: the planted unclassifiable definition read GREEN (rc=$prc) -- the census has stopped discriminating and arms 3 to 5 are measuring nothing"; RC=1; fi
cat > "$T/plant2.s" <<'EOF'
 .text
q_α:
 push r13
 mov rax, rbp                                      # pl_disj_open inline (planted: the note without its lea as the last rcx writer)
 shl rax, 8
 lea rcx, [rbp + 128]
 mov rcx, qword ptr [rbp + 48]
 test r13, r13
 je 1f
 cmp r13, rcx
 jb 2f
1:
 mov r13, rcx
2:
 call rt_gcheap_alloc
 mov rdi, r13
 pop r13
 ret
EOF
python3 "$CENSUS" "$T/plant2.s" > "$T/plant2.txt" 2>&1; prc2=$?
if [ "$prc2" -ne 0 ] && grep -q 'UNCLASSIFIED' "$T/plant2.txt"; then echo "  arm 7b PASS: the CHOICE class (hq_prolog 2026-10-03, the cfo's tightening): a disj_open note with a memory load into rcx between its lea and the mov r13, rcx reads UNCLASSIFIED and red -- the class takes the declared lea only, never a comment's word for what rcx holds"
else echo "  arm 7b RED: a mov r13, rcx whose last rcx writer is a memory load read as CHOICE under a disj_open note (rc=$prc2) -- the census is taking the note's word for a form it cannot see"; RC=1; fi

if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: what a callee-saved register holds at an allocating return is read off the emitted code, nothing is unclassified, and the per-graph map carries no register mask (examined 8 arms)"
else echo "GATE FAIL(1) [$G]: a callee-saved register at an allocating return is unnamed, unmodelled, or the map has taken on a register mask it cannot honestly carry (examined 8 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
