#!/usr/bin/env bash
# util_prolog_template_emptiness_audit.sh — PA-2 (GOAL-PROLOG-BB.md).
#
# Makes the EMITTER half of PJ-AG-WIRE (AGW-9) MEASURABLE.
#
# The five Prolog control-flow BB templates —
#     bb_pl_seq, bb_pl_call, bb_pl_choice, bb_pl_alt, bb_pl_cut
# — must each emit inline x86 for their four-port (α/β/γ/ω) logic, translating
# the matching `case` in IR_interp.c (HQ Invariant 11, INLINE-ALL). Today they are
# empty stubs: `return std::string();` with ZERO emission calls, so Mode-4
# Prolog four-port logic lives in the C graph-walker (IR_interp.c) instead of in
# the template — the root of the D grade in the HQ-ALIGNMENT AUDIT.
#
# A template is EMPTY if its `<name>_str` body contains NO emission call
# (s_1asm/s_2asm/s_L*asm/s_comment/s_directive/emit_fmt/bytes/u32le/u64le).
# This script FAILs (exit 1) while ANY of the five are empty, printing the
# running empty-count. As AGW-9 fills one template per commit, the count
# decrements; the EMITTER half closes (and the D grade lifts) only at 0.
set -u
cd "$(dirname "$0")/../../SCRIP/src/templates" || exit 2

TEMPLATES="bb_pl_seq bb_pl_call bb_pl_choice bb_pl_alt bb_pl_cut"
# Tokens that prove the template actually emits something.
EMIT_RE='s_1asm|s_2asm|s_L[0-9]*asm|s_comment|s_directive|emit_fmt|bytes\(|u32le|u64le|emit_text'

empty=0
filled=0
missing=0
echo "=== Prolog control-flow template emptiness audit (PA-2 / AGW-9) ==="
for t in $TEMPLATES; do
  f="$t.cpp"
  if [ ! -f "$f" ]; then
    printf "  %-14s MISSING\n" "$t"
    missing=$((missing+1))
    continue
  fi
  # Count emission calls anywhere in the file body (the _str fn is the only
  # place they can appear; the extern "C" wrapper just calls _str).
  hits=$(grep -cE "$EMIT_RE" "$f")
  if [ "$hits" -eq 0 ]; then
    printf "  %-14s EMPTY  (stub — delegates to IR_interp.c C walker)\n" "$t"
    empty=$((empty+1))
  else
    printf "  %-14s FILLED (%s emission calls)\n" "$t" "$hits"
    filled=$((filled+1))
  fi
done

echo "---"
echo "EMPTY=$empty FILLED=$filled MISSING=$missing  (target: EMPTY=0)"

if [ "$missing" -ne 0 ]; then
  echo "AUDIT RED — a Prolog template file is missing."
  exit 2
fi
if [ "$empty" -ne 0 ]; then
  echo "AUDIT INCOMPLETE — $empty Prolog four-port template(s) still delegate to the C walker (AGW-9 open)."
  exit 1
fi
echo "AUDIT GREEN — all Prolog four-port templates emit inline x86 (AGW-9 closed)."
exit 0
