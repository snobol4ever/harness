#!/usr/bin/env bash
# test_gate_a_descr_is_minted_whole_never_field_by_field.sh -- NO C SITE BUILDS A DESCR_t FIELD BY FIELD FROM AN UNINITIALISED
# DECLARATION (cfo 2026-10-01; the class behind SCRIP 770ff507d and the cto's bisect of a GVA "raw pair" to 99d429d4c).
# DESCR_t is {v:1, src_node0..2:3, slen:4, ptr:8}; `DESCR_t r; r.v = ...; r.slen = ...; r.u = ...;` leaves src_node as stack garbage,
# and word 0 is read whole -- by the one-stack census (a legal DT_DATA record cell read as "stack" because its garbage made word 0
# equal GVA slot 7's address) and by dword tag compares in asm fast paths. The cure is `DESCR_t r = {0};` (src_node 0, UNSTAMPED) or
# a compound literal; util_descr_whole_mint_census.py --apply writes the former.
# ARMS: (1) the census's selftest holds (planted sites in both directions); (2) FAIL_ONCE=1 turns a selftest arm red, so (1) can
# fail; (3) the census reads 0 sites over every C file under src/. rc 2 when the census is missing: a missing instrument is not green.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
G=test_gate_a_descr_is_minted_whole_never_field_by_field; C="$HERE/util_descr_whole_mint_census.py"
[ -f "$C" ] || { echo "⛔ GATE REFUSE(2) [$G]: $C is missing"; exit 2; }
red=0
st="$(python3 "$C" --selftest 2>&1)"; src=$?
if [ "$src" = 0 ]; then echo "  ok   (1) the census selftest holds: $(printf '%s\n' "$st" | tail -1 | sed 's/^ *//')"
else echo "  FAIL (1) the census selftest: $(printf '%s\n' "$st" | grep RED | head -3 | tr '\n' ' ')"; red=$((red+1)); fi
fo="$(FAIL_ONCE=1 python3 "$C" --selftest 2>&1)"; frc=$?
if [ "$frc" = 0 ] && printf '%s\n' "$fo" | grep -q 'FAIL-ONCE PROVED'; then echo "  ok   (2) $(printf '%s\n' "$fo" | tail -1 | sed 's/^ *//')"
else echo "  FAIL (2) FAIL_ONCE=1 did not turn a selftest arm red, so arm (1) cannot fail"; red=$((red+1)); fi
out="$(python3 "$C" 2>&1)"; crc=$?
if [ "$crc" = 0 ]; then echo "  ok   (3) $(printf '%s\n' "$out" | tail -1)"
elif [ "$crc" = 1 ]; then echo "  FAIL (3) $(printf '%s\n' "$out" | tail -1) -- mint the DESCR whole (DESCR_t r = {0}; or a compound literal):"
     printf '%s\n' "$out" | grep '^  SITE' | head -20 | sed 's/^/     /'; red=$((red+1))
else echo "⛔ GATE REFUSE(2) [$G]: the census exited rc=$crc: $(printf '%s\n' "$out" | tail -1)"; exit 2; fi
[ "$red" = 0 ] && { echo "✅ GATE PASS(0) [$G]: every C site under src/ mints its DESCR whole (3 arms)"; exit 0; }
echo "⛔ GATE RED(1) [$G]: $red of 3 arms red"; exit 1
