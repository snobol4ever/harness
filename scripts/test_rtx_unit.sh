#!/usr/bin/env bash
# test_rtx_unit.sh — RTX differential batteries (asm family vs its c_* body).
# Every RTX family owes one of these: same inputs, both implementations, bit-identical results.
# Usage: bash ../harness/scripts/test_rtx_unit.sh
set -uo pipefail
cd "$(dirname "$0")/../../SCRIP"
RC=0
for T in src/runtime/rtx/rtx_unit_test.c src/runtime/rtx/rtx_alloc_test.c src/runtime/rtx/rtx_str_test.c src/runtime/rtx/rtx_varval_test.c src/runtime/rtx/rtx_arith_test.c src/runtime/rtx/rtx_misc_test.c src/runtime/rtx/rtx_sname_test.c src/runtime/rtx/rtx_tins_test.c src/runtime/rtx/rtx_sval_test.c src/runtime/rtx/rtx_relop_test.c src/runtime/rtx/rtx_direct_test.c; do
  [ -f "$T" ] || continue
  B="/tmp/$(basename "$T" .c)"
  # ⛔ -Isrc/ir IS WHERE descr.h LIVES. This line said -Isrc/contracts, a directory DELETED in the 2026-08-24
  # srcreorg, so THREE of the four batteries had not compiled since -- rtx_unit_test, rtx_str_test and
  # rtx_varval_test each printed a BUILD FAIL that this runner reported as RTX UNIT: FAILURES, and nothing wires
  # this runner into make test, so nobody saw it. ⭐ The alloc battery kept passing because it includes no header
  # from the moved directory, which is why the runner still printed one PASS line and looked like it was working.
  # Fixed 2026-09-13 by hq_R (not this runner's owner) while making rtx_unit_test the behavioural arm of
  # test_gate_mint_op_is_one_numbering.sh -- a stale -I is the same decay class as the stale literal that row cures.
  gcc -O0 -g -w -Isrc -Isrc/ir -Isrc/runtime/rt -Isrc/runtime/core -o "$B" "$T" \
      -Wl,-rpath,"$PWD/out" -L"$PWD/out" -lscrip_rt -lm -lpthread 2>&1 | head -5
  [ -x "$B" ] || { echo "  BUILD FAIL: $T"; RC=1; continue; }
  timeout -k 5 30s "$B" < /dev/null; [ $? -eq 0 ] || RC=1
done
[ $RC -eq 0 ] && echo "RTX UNIT: ALL PASS" || echo "RTX UNIT: FAILURES"
exit $RC

D="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/src/ir/descr.h"
body="$(awk '/^typedef struct DESCR_t \{/{f=1;next} f&&/^\} DESCR_t;/{exit} f' "$D")"
[ -n "$body" ] || { echo "RTX DESCR SHAPE: REFUSES rc=2 -- could not extract the DESCR_t body from $D"; exit 2; }
if printf '%s\n' "$body" | grep -q '\['; then
  echo "RTX DESCR SHAPE: FAIL -- DESCR_t carries an ARRAY member: $(printf '%s\n' "$body" | grep '\[' | head -1 | sed 's/^ *//')"
  echo "  a char array inside DESCR_t turns the toolchain's default -fstack-protector-strong on for EVERY C function holding a DESCR_t local (canary + 16-byte movaps temporaries); on 2026-09-19 uint8_t src_node[3] alone took a SNOBOL4 rungs entry from green to SIGSEGV with the emitted asm byte-identical (ceo, row gc-the-frame-map-is-write-only). Spell multi-byte fields as named bytes."
  exit 1
fi
echo "RTX DESCR SHAPE: PASS -- no array member in DESCR_t ($(printf '%s\n' "$body" | grep -c ';') fields)"
