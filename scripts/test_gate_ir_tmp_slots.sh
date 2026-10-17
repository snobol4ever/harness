#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_ir_tmp_slots.sh — GROUND ZERO #5 (GOAL-IR-IMMUTABLE-EMIT) B0 keystone lock.
# Pins the JCON ir_Tmp contract that ir_tmp_slot_assign() establishes in LOWER: every value-PRODUCING
# node carries a result slot and every control node does NOT. Checks STRUCTURE, not exact offsets.
# RE-PINNED 2026-07-12: the slot is displayed as the self-column NAME (sN = zls slot N, nN = no slot);
# the older lhs=/tmp= payload tokens are gone (lhs= died at 19cbedd5 when lhs->tmp landed; tmp= died when
# zls naming absorbed it) — this gate was red against both and nobody noticed. ASSIGN is re-pinned as a
# slot CARRIER: assignment is a value in Icon/SNOBOL4 and today's LOWER grants it one (measured, s64).
# Dump kind names are IR_-prefix-less as of 2026-07-12 (Lon directive); slotless nodes render @LINE (Lon:
# numbers in the dump mean SLOTS — node ids are verbose-only), so the noslot arm matches @, never nN.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet  DATE: 2026-06-27 / 2026-07-12
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../SCRIP" && pwd)"
SCRIP="${ROOT}/scrip"
[ -x "${SCRIP}" ] || { echo "FAIL: ${SCRIP} not built"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
PROG="${TMP}/keystone.icn"
printf 'procedure main();x := a + b;write(x);end\n' > "${PROG}"
DUMP="$("${SCRIP}" --dump-ir "${PROG}" < /dev/null 2>&1)"

echo "=== B0 keystone: ir_Tmp slot contract on --dump-ir ==="
fails=0
chk() { # chk "<label>" "<grep-for-line>" "slot|noslot"
  local label="$1" line_pat="$2" mode="$3" line self
  line="$(printf '%s\n' "${DUMP}" | grep -E "${line_pat}" | head -1)"
  if [ -z "${line}" ]; then echo "  FAIL  ${label}: no '${line_pat}' line in dump"; fails=$((fails+1)); return; fi
  self="$(printf '%s' "${line}" | awk '{print $1}')"
  case "${self}" in
    *@) [ "${mode}" = noslot ] && echo "  ok    ${label} has no slot (${self})"  || { echo "  FAIL  ${label} must carry slot: ${line}"; fails=$((fails+1)); } ;;
    [0-9]*) [ "${mode}" = slot ]   && echo "  ok    ${label} carries slot (${self})" || { echo "  FAIL  ${label} must NOT carry slot: ${line}"; fails=$((fails+1)); } ;;
    *)  echo "  FAIL  ${label}: unparsable self field: ${line}"; fails=$((fails+1)) ;;
  esac
}

chk "BINOP (value producer)"   " BINOP "    slot
chk "VAR (value producer)"     " VAR "      slot
chk "CALL (value producer)"    " CALL"      slot
chk "ASSIGN (value producer)"  " ASSIGN "   slot
chk "SUCCEED (control port)"   " SUCCEED "  noslot
chk "FAIL (control port)"      " FAIL "     noslot

# A binop's operands must themselves be slotted producers (consumer reads off(operand)).
binop_ops="$(printf '%s\n' "${DUMP}" | grep -E " BINOP " | head -1 | sed -E 's/.*\[([sn0-9,]+)\].*/\1/')"
case "${binop_ops}" in
  [0-9]*) echo "  ok    BINOP operands are slotted: [${binop_ops}]" ;;
  *)  echo "  FAIL  BINOP operands not slotted: [${binop_ops}]"; fails=$((fails+1)) ;;
esac

echo "-------------------------------------------"
if [ "${fails}" -eq 0 ]; then echo "PASS: ir_Tmp slot contract holds."; exit 0; fi
echo "FAIL: ${fails} keystone contract violation(s)."; exit 1
