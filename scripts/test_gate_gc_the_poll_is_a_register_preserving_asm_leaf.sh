#!/usr/bin/env bash
# test_gate_gc_the_poll_is_a_register_preserving_asm_leaf.sh -- THE SAFE-POINT POLL IS AN ASM LEAF, AND IT PRESERVES EVERY REGISTER IT TOUCHES.
#
# THE RULE (Lon 2026-09-22, in-chat to the ceo, verbatim: "Why not make the poll an ASM call instead of a C call? It is big?"; ceo CEO-1105).
# The C rt_gc_poll is 43 instructions at -O0 and pays for a frame, an %fs:0x28 stack-protector canary load AND verify, and a GOT hop, all to
# test two flags. Worse than its size: it is a C function, so by the SysV ABI it may clobber rax rcx rdx rsi rdi r8-r11 -- which is WHY the site
# helper family spills and reloads around it (x86_rt_gc_poll_res is 7 instructions AT THE SITE, _rec_sigma ~14, _rec_sigma_pair ~20, against
# Lon's 4-6 budget in RULES.md FACT RULE -- AN EMITTED ALLOCATION SEQUENCE IS AT MOST 4-6 INSTRUCTIONS AT THE SITE).
#
# rt_gc_poll_asm is 19 instructions, has no frame and no canary, and RESTORES EVERY REGISTER IT WRITES. It lives as a file-scope __asm__ block
# inside gc_heap.c rather than under src/runtime/rtx/ for one measured reason: g_gc_in and g_hp_gcline are FILE-LOCAL statics (nm reads them
# lowercase 'b'), so a separate .s file cannot name them at all. g_hp_top is a MACRO over g_hp_fr.top at offset 0, whose offsets the file already
# pins with _Static_assert for exactly this purpose -- rtx_alloc.s reads the same struct the same way.
#
# ⛔ WHAT THIS GATE DOES NOT CLAIM, stated so nobody reads it as broader than it is: PRESERVING A REGISTER IS NOT RELOCATING IT. A DESCR live in
# rax:rdx across a collection must be SPILLED AS A TAGGED CELL so the walker can move it; restoring the old bits hands back a STALE pointer. That
# is why the per-site _res / _rec_* variants still exist and still encode type knowledge the leaf cannot guess. This gate holds the leaf, not them.
set -u
G="${0##*/}"; R="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"; F=0; N=0
ck() { N=$((N+1)); if [ "$1" = 0 ]; then printf '  ok    %s\n' "$2"; else F=$((F+1)); printf '  FAIL  %s\n' "$2"; fi; }
H="$R/src/runtime/rt/gc_heap.c"; X="$R/src/templates/x86/x86_asm.h"
[ -r "$H" ] && [ -r "$X" ] || { echo "GATE REFUSE(2) [$G]: gc_heap.c or x86_asm.h unreadable"; exit 2; }
tr -s ' \t\n' '   ' < "$X" | grep -q 'x86_rt_gc_poll_at(const char \* f, int l) {.*x86("call", "rt_gc_poll_asm"'; ck $? "the emitter's bare poll calls rt_gc_poll_asm, not the C rt_gc_poll (the helper carries its template site as a note since 2026-09-23; x86_rt_gc_poll() is the macro that stamps it)"
grep -q '".globl rt_gc_poll_asm' "$H";                               ck $? "rt_gc_poll_asm is defined as a file-scope __asm__ leaf in gc_heap.c"
BODY="$(awk '/"rt_gc_poll_asm:/{f=1} f{print} f&&/size rt_gc_poll_asm/{exit}' "$H")"
[ -n "$BODY" ]; ck $? "the leaf body is extractable between its label and its .size directive"
PUSH=$(printf '%s\n' "$BODY" | grep -o 'pushq' | wc -l); POP=$(printf '%s\n' "$BODY" | grep -o 'popq' | wc -l)
PSET="$(printf '%s\n' "$BODY" | grep -oE 'pushq %[a-z0-9]+' | awk '{print $2}' | tr -d '%' | sort -u | tr '\n' ' ')"
QSET="$(printf '%s\n' "$BODY" | grep -oE 'popq %[a-z0-9]+'  | awk '{print $2}' | tr -d '%' | sort -u | tr '\n' ' ')"
[ "$PUSH" -gt 0 ] && [ "$PSET" = "$QSET" ] && [ "$POP" -ge "$PUSH" ]
ck $? "the pushed and popped register SETS are identical and no path leaks: pushed={$PSET} popped={$QSET}, pushq=$PUSH popq=$POP. ⛔ A GLOBAL pushq==popq COUNT IS THE WRONG INSTRUMENT HERE and it red on its first run: the leaf has TWO exits, fast and slow, and each pops r11 on its own path, so 2 pushes legitimately meet 3 pops. Counting instructions across branches asks a question about straight-line code of something that branches"
printf '%s\n' "$BODY" | grep -q 'call '; ck $((1-$?)) "the leaf CALLs nothing -- it tail-JMPs to the slow path, so it adds no frame of its own"
WROTE="$(printf '%s\n' "$BODY" | grep -oE ', %(r[0-9]+|[re][a-z]{2})' | awk '{print $2}' | tr -d '%' | sort -u | tr '\n' ' ')"
SAVED="$(printf '%s\n' "$BODY" | grep -oE 'pushq %[a-z0-9]+' | awk '{print $2}' | tr -d '%' | sort -u | tr '\n' ' ')"
BAD=0; for w in $WROTE; do case " $SAVED " in *" $w "*) ;; *) BAD=1; echo "      unsaved write target: $w";; esac; done
[ "$BAD" = 0 ]; ck $? "every register the leaf writes is one it pushed first (wrote: ${WROTE:-none} / saved: ${SAVED:-none})"
SO="$R/out/libscrip_rt.so"
if [ -r "$SO" ] && command -v objdump >/dev/null 2>&1; then
  A=$(objdump -d "$SO" --disassemble=rt_gc_poll_asm 2>/dev/null | grep -cE '^[[:space:]]+[0-9a-f]+:')
  C=$(objdump -d "$SO" --disassemble=rt_gc_poll     2>/dev/null | grep -cE '^[[:space:]]+[0-9a-f]+:')
  [ "$A" -gt 0 ] && [ "$C" -gt 0 ] && [ "$A" -lt "$C" ]; ck $? "the built leaf is SMALLER than the C poll it replaces: asm=$A instructions, C=$C"
  printf '%s\n' "$(objdump -d "$SO" --disassemble=rt_gc_poll_asm 2>/dev/null)" | grep -q 'fs:0x28'; ck $((1-$?)) "the leaf carries NO %fs:0x28 stack-protector canary, which is most of what the C poll spends on two flag tests"
else
  echo "GATE REFUSE(2) [$G]: out/libscrip_rt.so or objdump missing -- COULD NOT MEASURE the built leaf"; exit 2
fi
W="$R/../corpus/benchmarks/icon/bench_icnstr_concat_table.icn"
if [ -x "$R/scrip" ] && [ -r "$W" ]; then
  OUT="$(SCRIP_HEAP_KB=128 SCRIP_GC_EXERCISE=1 timeout -k 5 300s "$R/scrip" "$W" </dev/null 2>&1 >/dev/null | grep -oE 'collections=[0-9]+' | head -1)"
  NCOL="${OUT#collections=}"
  [ -n "$NCOL" ] && [ "$NCOL" -gt 0 ] 2>/dev/null
  ck $? "THE SLOW PATH IS LIVE: a witness still collects through the leaf ($OUT). A poll that never reaches its slow path is green and useless"
else
  echo "GATE REFUSE(2) [$G]: ./scrip or the witness is missing -- COULD NOT MEASURE that the collector still runs"; exit 2
fi
SBODY="$(awk '/"rt_gc_poll_slow:/{f=1} f{print} f&&/size rt_gc_poll_slow/{exit}' "$H")"
[ -n "$SBODY" ]; ck $? "THE SLOW PATH IS AN ASM LEAF TOO, extractable between its label and its .size directive. ⛔ THIS ARM EXISTS BECAUSE THE ARMS ABOVE PROVED THE WRONG HALF: they measured rt_gc_poll_asm, saw it tail-JMP away, and never asked what it jumped INTO -- which was a C rt_gc_poll_slow that clobbered all nine caller-saved registers on the ONLY path that actually collects"
SP="$(printf '%s\n' "$SBODY" | grep -oE 'pushq %[a-z0-9]+' | awk '{print $2}' | sort)"
SQ="$(printf '%s\n' "$SBODY" | grep -oE 'popq %[a-z0-9]+'  | awk '{print $2}' | sort)"
[ -n "$SP" ] && [ "$SP" = "$SQ" ]; ck $? "the slow path's pushed and popped register sets are identical: pushed={$(echo $SP)} popped={$(echo $SQ)}"
MISS=""
for r in rax rcx rdx rsi rdi r8 r9 r10 r11; do printf '%s\n' "$SP" | grep -qx "%$r" || MISS="$MISS $r"; done
[ -z "$MISS" ]; ck $? "the slow path saves the WHOLE caller-saved set across the collector call, so a bare poll is transparent to emitted code${MISS:+ -- MISSING:$MISS}"
printf '%s\n' "$SBODY" | grep -q 'fs:0x28'; ck $((1-$?)) "the slow path carries no %fs:0x28 canary either"
SPILL=$(printf '%s\n' "$SBODY" | grep -oE 'subq +\$[0-9]+, *%rsp' | grep -oE '[0-9]+' | head -1); SPILL="${SPILL:-0}"
NPUSH=$(printf '%s\n' "$SBODY" | grep -o 'pushq' | wc -l); FLOOR=$(printf '%s\n' "$SBODY" | grep -oE 'leaq +[0-9]+\(%rsp\), *%rcx' | grep -oE '[0-9]+' | head -1); FLOOR="${FLOOR:-0}"
[ "$FLOOR" = "$(( NPUSH * 8 + SPILL ))" ]
ck $? "the slow path hands the collector the ENTRY rsp as its walk floor -- COMPUTED, not a literal: leaq $FLOOR(%rsp) == 8 x $NPUSH pushes + $SPILL bytes of own spill, so the caller's spilled cells stay INSIDE the swept range and everything this leaf saved for itself stays OUTSIDE it. ⛔ THE LITERAL 72 WAS THE WRONG KEY and it red on a correct landing: the cfo's subject probe added a 16-byte slot below the floor, the floor moved to 88 and the property never changed"
printf '%s\n' "$SBODY" | grep -qE 'movq +%r13, *\(%rsp\)'; ck $? "THE SUBJECT REGISTER IS HANDED TO THE COLLECTOR, NOT MERELY PRESERVED (cfo 2026-09-22): the slow path spills r13 into its own slot below the floor"
printf '%s\n' "$SBODY" | grep -qE 'movq +%rsp, *%rdx'; ck $? "and passes that slot's ADDRESS as r0, the saved-subject word (CEO-972's road, the one rt_gc_point_arr in rt_asm_helpers.S has always used)"
printf '%s\n' "$SBODY" | grep -qE 'movl +\$1, *%r8d'; ck $? "with is_probe=1, so gc_point_arr_body visits the word ONLY if it aliases the subject or scan_subj and IGNORES it silently otherwise -- an exact alias test, never a guess, which is why this is safe at all 105 bare-poll sites where spraying x86_rt_gc_poll_rec_sigma would have tagged a frame display register as DT_S"
printf '%s\n' "$SBODY" | grep -qE 'movq +\(%rsp\), *%r13'; ck $? "AND IT RELOADS r13 FROM THE SLOT after the call rather than popping a saved copy -- the difference between a relocation picked up and a pre-move address restored (ARCH-GC 6.2j's standing rule: a register the collector rewrites is fixed in place or reloaded from its authority, never restored raw)"
printf '%s\n' "$SBODY" | grep -qE 'call +gc_point_arr_body'; ck $? "the slow path calls the collector body DIRECTLY, not through rt_gc_point_arr_c's -O0 argument spill-and-reload shim"
if [ -r "$SO" ] && command -v objdump >/dev/null 2>&1; then
  SN=$(objdump -d "$SO" --disassemble=rt_gc_poll_slow 2>/dev/null | grep -cE '^[[:space:]]+[0-9a-f]+:')
  [ "$SN" -gt 0 ] && [ "$SN" -le 32 ]; ck $? "the built slow path is $SN instructions (was 25 C + an 18-instruction shim = 43 across two frames; the bound moved 30 -> 32 at CTO-145, SCRIP 7b74d4022, which captures the return PC into the anchor cell in two instructions before the body call)"
fi
grep -q '^void rt_gc_poll_asm(void);' "$H"; ck $? "rt_gc_poll_asm carries a C declaration in gc_heap.c. ⛔ AN ASM-ONLY SYMBOL IS UNDECIDABLE TO util_gc_safe_point_contract.py, whose K2 resolves a callee's return type out of src/runtime's own declarations and names what it cannot find rather than guessing"
grep -q '^void rt_gc_poll_slow(void);' "$H"; ck $? "rt_gc_poll_slow carries one too, for the same reason -- making it asm REMOVED the C definition the checker used to read"
echo "population: $N arm(s) over the poll leaf, its slow path, its emitter call site and one live witness"
if [ "$F" = 0 ]; then echo "GATE PASS(0) [$G]: the safe-point poll is a register-preserving asm leaf ($N arms)"; exit 0; fi
echo "GATE FAIL(1) [$G]: $F of $N arm(s) red"; exit 1
