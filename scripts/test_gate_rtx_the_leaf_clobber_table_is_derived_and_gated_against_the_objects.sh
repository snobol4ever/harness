#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_rtx_the_leaf_clobber_table_is_derived_and_gated_against_the_objects.sh -- THE CLOBBER SET OF EVERY ASM-RUNTIME ENTRY THE EMITTER READS IS DERIVED FROM THE ASSEMBLED
# OBJECTS AND REFUSED THE MOMENT IT DISAGREES WITH THEM (cto 2026-09-30, row rtx-leaves-carry-no-register-veneer-an-asm-runtime-call-is-not-a-c-function; Lon 2026-09-30, in-chat to
# the ceo, verbatim: "Ensure the veneer to save and restore registers has been removed from ALL x86 asm runtime calls since they are not C functions and do not require the extra.";
# ARCH-RT-CALL-PROTOCOL.md section 15 THE LEAF CONTRACT).
#
# WHAT IT GATES.  A leaf saves and restores nothing; what it writes among the RTCC four is not declared by anyone but DERIVED: ../harness/scripts/util_rtx_abi_walk.py --clobber-table
# abstract-interprets every registered entry along every path over `objdump -d -r` of the objects assembled from src/runtime/rtx/*.s (lib_rtx_clobber_derive.py), and
# ../harness/scripts/util_gen_rt_entry_table.py keeps the asm rows of harness/scripts/rt_entries.tsv equal to the result (--sync-asm writes them, --check-asm refuses a stale one).
# src/runtime/rt_entry_table.inc is generated from that table and src/emitter/emit.cpp includes it, so x86_rtcc_clob_raw() can re-establish exactly the named registers at the
# call site and nothing else.  A table that disagrees with the objects would let the emitter call a clobbering leaf bare, or spend a reload on a pure one: this gate refuses both.
# STAGE 5c (DESIGN-PLAN zeta-layout step 5, CEO-2019): this gate used to hold src/templates/x86/rtx_clobber_table.inc, written by util_gen_rtx_clobber_table.py; both are deleted and the
# runtime entry table is the one source, so the same four arms now read it (the gate keeps its name).
#
# FOUR ARMS.
#   (1) --check-asm reads FRESH: every registered asm entry has a row and its clobbers column is what the objects derive now;
#   (2) PLANTED: a copy of the table with one asm row's clobbers doctored reads STALE under --check-asm (rc 1) -- an instrument that cannot see a wrong mask proves nothing;
#   (3) the emitter includes the entry table and consults it (src/emitter/emit.cpp names rt_entry_table.inc and defines emit_rtx_clob_mask over g_rt_entries; src/templates/x86/x86_asm.h's
#       x86_rtcc_clob_raw calls it);
#   (4) the generated src/ file carries no comment and no blank line (RULES.md ABSOLUTE; the pre-commit hook refuses one).
#
# Usage: bash ../harness/scripts/test_gate_rtx_the_leaf_clobber_table_is_derived_and_gated_against_the_objects.sh
#   exit 0 = green, 1 = measured broken, 2 = could not measure
set -u
G="rtx_the_leaf_clobber_table_is_derived_and_gated_against_the_objects"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GEN="$HERE/util_gen_rt_entry_table.py"
TSV="$HERE/rt_entries.tsv"
TAB="$ROOT/src/runtime/rt_entry_table.inc"
for t in gcc objdump objcopy python3; do command -v "$t" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: $t is not installed"; exit 2; }; done
[ -f "$GEN" ] || { echo "⛔ GATE REFUSE(2) [$G]: $GEN absent"; exit 2; }
[ -f "$TSV" ] || { echo "⛔ GATE REFUSE(2) [$G]: $TSV absent"; exit 2; }
[ -f "$TAB" ] || { echo "⛔ GATE REFUSE(2) [$G]: $TAB absent -- run: python3 ../harness/scripts/util_gen_rt_entry_table.py --write"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
echo "  HOLDS: the clobber set of every asm-runtime entry is derived from the assembled objects by the ABI walker, held in the runtime entry table, and read by the emitter -- a leaf declares nothing, saves nothing, and the call site re-establishes exactly what the leaf can change"
python3 -I "$GEN" --check-asm > "$T/check.txt" 2>&1; rc=$?
if [ $rc -eq 0 ] && grep -q 'RT-ENTRY-ASM FRESH' "$T/check.txt"; then echo "  arm 1 PASS: $(grep -o 'FRESH entries=[0-9]* clobbering=[0-9]*' "$T/check.txt")"
elif [ $rc -eq 2 ]; then echo "⛔ GATE REFUSE(2) [$G]: the table could not be derived: $(head -c 300 "$T/check.txt")"; exit 2
else echo "⛔ arm 1 RED: the entry table disagrees with the objects (rc=$rc):"; sed 's/^/      /' "$T/check.txt" | head -12; RC=1; fi
python3 - "$TSV" "$T/doctored.tsv" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
for i, ln in enumerate(lines):
    f = ln.split('\t')
    if len(f) == 7 and not ln.startswith('#') and f[1] == 'asm' and f[4] != '-':
        f[4] = 'r9' if f[4] == 'none' else 'none'
        lines[i] = '\t'.join(f)
        open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines))
        sys.exit(0)
sys.exit(2)
PY
if [ $? -ne 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: could not doctor a copy of the table"; exit 2; fi
python3 -I "$GEN" --check-asm --tsv "$T/doctored.tsv" > "$T/plant.txt" 2>&1; prc=$?
if [ $prc -eq 1 ] && grep -q 'STALE' "$T/plant.txt"; then echo "  arm 2 PASS: PLANTED -- one doctored mask reads STALE under --check-asm (rc 1), so a wrong mask cannot hide"
else echo "⛔ arm 2 RED: the planted wrong mask was NOT refused (rc=$prc): $(head -c 200 "$T/plant.txt")"; RC=1; fi
if grep -q 'rt_entry_table.inc' "$ROOT/src/emitter/emit.cpp" && grep -q 'emit_rtx_clob_mask' "$ROOT/src/emitter/emit.cpp" && grep -q 'g_rt_entries' "$ROOT/src/emitter/emit.cpp" && grep -q 'emit_rtx_clob_mask(sym)' "$ROOT/src/templates/x86/x86_asm.h"; then echo "  arm 3 PASS: emit.cpp includes rt_entry_table.inc and defines emit_rtx_clob_mask over g_rt_entries; x86_asm.h's x86_rtcc_clob_raw calls it"
else echo "⛔ arm 3 RED: the emitter does not read the entry table (emit.cpp include / emit_rtx_clob_mask / g_rt_entries / x86_rtcc_clob_raw)"; RC=1; fi
if grep -qE '^\s*$|/\*|//' "$TAB"; then echo "⛔ arm 4 RED: the generated table carries a comment or a blank line"; RC=1
else echo "  arm 4 PASS: the generated src/ file carries no comment and no blank line"; fi
if [ $RC -eq 0 ]; then echo "GATE PASS(0) [$G]: the clobber set of every asm entry is derived from the objects, refused when stale, read by the emitter, and clean"; else echo "⛔ GATE RED(1) [$G]"; fi
exit $RC
