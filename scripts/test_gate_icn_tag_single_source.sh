#!/usr/bin/env bash
# test_gate_icn_tag_single_source.sh -- GOAL-ICON-100 Z-5(a): DT_* tag numbers live in ONE place.
#
# THE CLASS (third recurrence, s237): a hand-written .S file carries its own `#define DT_x <lit>`.
# It compiles, it links, the _Static_assert in rtx_init.c still passes (that assert guards descr.h
# drift, NOT the .S hardcode), and the shipped .so ends up holding TWO DIFFERENT VALUES FOR ONE TAG.
# Measured s237: rtx_icnagg.s/rtx_icnsub.s defined DT_DATA as 100 AFTER including rtx_abi.inc (which
# has supplied the correct 0x70 via descr_tags.inc since s230), so dat_field_get shipped
# `cmp $0x64,%esi` while every C site used `cmp $0x70`. The guard is a RANGE test (v < DT_DATA -> C)
# and DT_FAIL is 0x68 = 104, so the stale boundary sat BELOW DT_FAIL and admitted a FAIL descriptor
# into the record walk -- silent corruption. The icnsub equality arms simply never matched, so
# RTX-24's list fast path was silently dead.
#
# LOCK 1: zero `#define DT_*` in any .S outside src/ir/descr_tags.inc.
# LOCK 2: every .S naming a DT_ tag must reach the single source (include rtx_abi.inc or descr_tags.inc).
# LOCK 3: descr_tags.inc and descr.h agree on every tag both define.
# Exit 0 = green, exit 2 = CANNOT-MEASURE (SRC/HDR missing -- not a verdict on the invariant).
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
SRC=src/ir/descr_tags.inc
HDR=src/ir/descr.h
[ -f "$SRC" ] || { echo "REFUSED (rc=2) -- single source $SRC does not exist, cannot grade LOCK 1/2/3"; exit 2; }
[ -f "$HDR" ] || { echo "REFUSED (rc=2) -- header $HDR does not exist, cannot grade LOCK 3"; exit 2; }
rc=0
echo "== LOCK 1: no tag literals defined outside $SRC =="
hits=$(grep -rnE '^[[:space:]]*#define[[:space:]]+DT_[A-Z0-9_]+' --include=*.S --include=*.inc src/ 2>/dev/null | grep -v "$SRC" || true)
if [ -n "$hits" ]; then echo "FAIL -- tag literal(s) shadowing the single source:"; echo "$hits" | cut -c1-160; rc=1; else echo "OK   -- 0 shadowing defines"; fi
echo "== LOCK 2: every .S using a DT_ tag reaches the single source =="
for f in $(grep -rlE '\bDT_[A-Z0-9_]+\b' --include=*.S src/ 2>/dev/null); do
  if ! grep -qE '#include[[:space:]]+"(rtx_abi|descr_tags)\.inc"' "$f"; then echo "FAIL -- $f names DT_ tags but includes neither rtx_abi.inc nor descr_tags.inc"; rc=1; fi
done
[ $rc -eq 0 ] && echo "OK   -- every DT_-using .S reaches the single source"
echo "== LOCK 3: $SRC agrees with $HDR =="
n=0
while read -r name val; do
  hv=$(grep -oE "\b$name[[:space:]]*=[[:space:]]*0x[0-9a-fA-F]+" "$HDR" 2>/dev/null | grep -oE '0x[0-9a-fA-F]+$' | head -1)
  [ -z "$hv" ] && continue
  if [ "$((val))" -ne "$((hv))" ]; then echo "FAIL -- $name: $SRC=$val but $HDR=$hv"; rc=1; fi
  n=$((n+1))
done < <(grep -oE '^#define[[:space:]]+DT_[A-Z0-9_]+[[:space:]]+0x[0-9a-fA-F]+' "$SRC" | awk '{print $2, $3}')
[ $rc -eq 0 ] && echo "OK   -- $n tags agree"
echo "---"
if [ $rc -eq 0 ]; then echo "GATE GREEN (tag single source)"; else echo "GATE RED (tag single source)"; fi
exit $rc
