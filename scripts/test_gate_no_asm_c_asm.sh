#!/usr/bin/env bash
# test_gate_no_asm_c_asm.sh — ⛔ LON'S LAW (2026-08-20 s194, in-chat): "You must guarantee that no ASM -> C -> ASM."
#
# THE RULE: emitted asm may call C, and C may call asm, but emitted asm must NEVER reach asm THROUGH C.  The middle C
# frame is where the machine loses its wires: gamma/omega ride r10/r11 (Lon s55) while RTCC banks r10/r11 in g_rtccb[32],
# a FLAT GLOBAL with NO nesting, so an inner activation entered through C overwrites the OUTER activation's banked
# continuations.  beauty's M1 SIGSEGV is that exact shape -- at the fault r11 = rip = &g_rtccb (FINDING s194c).
#
# ⛔ THIS IS A RATCHET, NOT A CLEAN GATE, AND THE COUNT IS COMPUTED, NEVER TYPED (the s169 lesson: a ratchet assembled
# from the violations already seen is permanently one syntax behind the code).  The floor is the measured census, 0 since
# CEO-1576 landing 3 deleted rt_proc_enter and every asm entry C could reach; a road put back reads RED.  Override for a
# deliberate, reviewed change: ASM_C_ASM_RATCHET=<n>.
#
# ⛔ WHAT A GREEN HERE DOES *NOT* PROVE.  The census is a STATIC, NAME-BASED call graph: INDIRECT calls (p->fn, dtp
# slots, jump tables) are INVISIBLE to it, and that is the direction this machine uses most.  A count of 0 would prove
# only that no NAMED road remains -- never that the property holds.  Read it as a floor that must fall, not a proof.
# The census REFUSES to report at all unless it finds a PLANTED road and skips two planted decoys (its own selftest; a
# MEASURED road died with its witness at CEO-1576, CEO-554: an instrument is never anchored on a found witness).
#
# ⛔ THE GATE PROVES ITS INSTRUMENT ON EVERY RUN (CEO-1573): after the clean census it plants two roads in a fixture
# directory -- its own asm entry (a .globl that jumps through a register), a ONE-LINE body called by x86("call", ...) and
# a multi-line body whose address the emitter bakes -- and the census must name both and count exactly two more.  A census that cannot see a planted road cannot grade the tree.
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(S4E_SCRIP="$HERE/../../SCRIP" python3 "$HERE/util_asm_c_asm_census.py" 2>&1)"; rc=$?
echo "$OUT"
[ "$rc" = 3 ] && { echo "⛔ GATE REFUSES: census selftest failed (see above) — fix the analysis before trusting any verdict."; exit 1; }
[ "$rc" = 0 ] || { echo "⛔ GATE ERROR: census exited $rc"; exit 1; }
N="$(printf '%s\n' "$OUT" | sed -n 's/^COUNT=//p' | tail -1)"
CEIL="${ASM_C_ASM_RATCHET:-0}"
case "$N" in ''|*[!0-9]*) echo "⛔ GATE ERROR: census printed no COUNT"; exit 1;; esac
echo "------------------------------------------------------------"
PLANT="$(mktemp -d)"; trap 'rm -rf "$PLANT"' EXIT
printf '%s\n' '__asm__(".text\n.globl rt_zz_planted_entry\nrt_zz_planted_entry:\n  jmp *%rdi\n");' 'DESCR_t rt_zz_planted_one_line(void) { return rt_zz_planted_entry((void *)0); }' 'static DESCR_t rt_zz_planted_block(long n) {' '    if (n) return rt_zz_planted_one_line();' '    return rt_zz_planted_entry((void *)0);' '}' > "$PLANT/zz_plant.c"
printf '%s\n' 'static std::string zz_plant(void) { return x86("call", "rt_zz_planted_one_line", 0) + x86("call_bare", "x", (uint64_t)(uintptr_t)(void *)rt_zz_planted_block); }' > "$PLANT/zz_plant.cpp"
POUT="$(S4E_SCRIP="$HERE/../../SCRIP" python3 "$HERE/util_asm_c_asm_census.py" --plant "$PLANT" 2>&1)"; prc=$?
PN="$(printf '%s\n' "$POUT" | sed -n 's/^COUNT=//p' | tail -1)"
if [ "$prc" != 0 ] || [ "$PN" != "$((N + 2))" ] || ! printf '%s\n' "$POUT" | grep -q '⛔ rt_zz_planted_one_line ' || ! printf '%s\n' "$POUT" | grep -q '⛔ rt_zz_planted_block '; then
    echo "⛔ GATE REFUSES: the census did not catch the two planted roads (rc $prc, COUNT $PN, want $((N + 2)))."
    printf '%s\n' "$POUT" | grep -E 'zz_planted|COUNT|SELFTEST|MISSING' | head -6
    exit 1
fi
echo "PLANT: both planted roads caught (COUNT $N -> $PN)."
if [ "$N" -gt "$CEIL" ]; then
    echo "⛔ FAIL: ASM->C->ASM roads $N EXCEEDS the ratchet $CEIL — a new road was added."
    echo "   Lon's law forbids the shape.  Either route the call so C is a LEAF, or lower the road count elsewhere."
    exit 1
fi
[ "$N" -lt "$CEIL" ] && echo "⭐ RATCHET FALLS: $N < $CEIL — lower the ceiling in this gate IN THE SAME COMMIT."
echo "OK: ASM->C->ASM roads $N (ratchet $CEIL).  ⛔ Green here is a FLOOR, not a proof — indirect calls are invisible."
exit 0
