#!/usr/bin/env bash
# test_gate_rtx_an_asm_define_equals_the_c_define_of_the_same_name.sh -- A LEAF'S COPY OF A C NUMBER IS EQUAL TO THE C NUMBER, BY A CENSUS AND NOT BY A READER
#
# MEASURED 2026-11-01 (hq_collector, the cto's pointer on rt_gc_trail_run, af8ada222): rt_gc_trail_run started its walk of the Prolog trail at the literal base + 64, copied from the C
# original when PL_TR_HEADER_BYTES was 64; the header grew to 128 and then 160 and the leaf stepped over header words as trail entries until the cao read it.  The row there was a LITERAL, which no name
# scan sees (the leaf now includes rt/pl_trail_layout.h and spells PL_TR_HEADER_BYTES, so it has no copy); this gate holds the other half of the class: every numeric #define in src/runtime/rtx
# (the sixteen .s leaves and rtx_abi.inc) that the C side also defines UNDER THE SAME NAME carries a number the C side carries (38 of 243 at the landing, all equal; the mirrors under other names are held by
# the C _Static_asserts beside their structs, gc_heap.c, gc_slot_table.c and rtx_init.c, which is where the rt_pseg_t offsets the leaf uses are pinned now).
# ARMS: (1) the census's own selftest on a synthetic tree: a skewed twin reds and names itself, an equal tree reads green, a hex and a parenthesised unsigned spelling compare by value;
# (2) the census over SCRIP/src: rc 0 green; a DIFFER line names the define, its asm lines and its C lines; rc 2 when the population is empty (no count is pinned: the refusal floor is 50 asm defines
# and at least one twin).  Hermetic: it reads source text, builds nothing and takes no run slot.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
CEN="$HERE/util_rtx_asm_c_twins.py"; [ -f "$CEN" ] || { echo "⛔ GATE REFUSE(2) [$G]: $CEN absent"; exit 2; }
[ -d "$ROOT/src/runtime/rtx" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $ROOT/src/runtime/rtx"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
python3 "$CEN" --selftest > "$T/self.txt" 2>&1; sr=$?
if [ "$sr" -eq 0 ]; then echo "  arm 1 PASS: $(cat "$T/self.txt")"
else echo "  arm 1 RED: the census's selftest is not green -- an instrument not shown to discriminate has measured nothing: $(head -c 300 "$T/self.txt")"; RC=1; fi
python3 "$CEN" "$ROOT/src" > "$T/c.txt" 2>&1; cr=$?
sum="$(grep '^RTX_ASM_C_TWINS ' "$T/c.txt" | tail -1)"
echo "RTX_ASM_C_TWINS_BOARD ${sum#RTX_ASM_C_TWINS } (tree $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null))"
case "$cr" in
  0) echo "  arm 2 PASS: every asm define of rtx that the C side defines under the same name carries the C number" ;;
  2) echo "⛔ GATE REFUSE(2) [$G]: $(grep -a 'REFUSE' "$T/c.txt" | head -1)"; exit 2 ;;
  *) echo "  arm 2 RED: an asm leaf spells a number the C side no longer carries -- the leaf is a frozen copy; make it include the C header or fix the C number:"; grep -a '^DIFFER' "$T/c.txt" | head -12 | sed 's/^/    /'; RC=1 ;;
esac
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: ${sum#RTX_ASM_C_TWINS } (examined 2 arms)"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
exit $RC
