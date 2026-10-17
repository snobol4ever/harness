#!/usr/bin/env bash
# WREG WIRE CENSUS -- the CORRECT instrument for "did the wires land?".
#
# ⛔ WHY THIS FILE EXISTS (s15b conviction, and it is the SECOND seat in a row):
#   s14 convicted the WREG claim gate for using `grep -c` (counts LINES) and printing the result
#   as `mentions` (occurrences).  s15 then measured wire emission with `grep -c 'lea r10'` against
#   emitter output that pads mnemonics with MULTIPLE SPACES (`lea              r10`).  That pattern
#   CANNOT MATCH.  It returned 0 on an arm that was emitting the wires correctly, and the 0 was
#   read as "the site glue never fired" -- producing two false claims that had to be retracted in
#   the same seat.  ONE INSTRUMENT FAMILY, TWO SEATS, SAME DEFECT: a grep whose UNITS were never
#   checked against its own input.  A zero from a grep is a CLAIM ABOUT TEXT and must be proven
#   like any other claim.  Hence: every pattern here is whitespace-tolerant (` +`) and word-
#   anchored (`\b`), and the script SELF-TESTS those patterns against a synthetic line before it
#   reports a single number.  If the self-test fails the script EXITS NONZERO and reports nothing,
#   because a silent zero is exactly the failure mode being prevented.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): corpus/probe/ was
# deleted wholesale (corpus-crosscheck-probe-total-conversion) -- this glob silently matched ZERO
# files against it (bash leaves an unmatched glob as a literal non-existent path with nullglob unset),
# so `for f in "$CORPUS"/*.sno` ran its body ZERO times, printing "TOTALS blobs=0 ... exits=0" and
# then "VERDICT: exits==blobs OK" -- 0==0 is a VACUOUS pass, not a real one, exactly the false-green
# shape this repo's own instrument laws exist to catch. Re-pointed to the flat tests/snobol4/ tree
# (real loose .sno files remain there); a hard population floor is added below since this script had
# none at all, unlike its ZDP-census siblings.
CORPUS=${CORPUS:-$S4E/corpus/tests/snobol4}
P_ENT='lea +r10\b'; P_EXG='jmp +r10\b'; P_EXO='jmp +r11\b'; P_BLOB='^\.LTp[0-9]+_α:'; P_PROC='lea +rcx, \[rip'
probe=$(printf '                        lea              r10, [rip + .Lx1]\n                                     jmp   r10\n.LTp0_α:\n')
t=0
echo "$probe" | grep -qE "$P_ENT"  || { echo "SELF-TEST FAIL: entry pattern"; t=1; }
echo "$probe" | grep -qE "$P_EXG"  || { echo "SELF-TEST FAIL: gamma pattern"; t=1; }
echo "$probe" | grep -qE "$P_BLOB" || { echo "SELF-TEST FAIL: blob-label pattern"; t=1; }
[ $t -eq 0 ] || { echo "⛔ INSTRUMENT SELF-TEST FAILED -- refusing to report numbers (s15b law)."; exit 2; }
echo "=== WREG WIRE CENSUS (self-test PASSED: patterns match padded emitter text) ==="
printf "%-24s %6s %6s %6s %6s %6s\n" program blobs entry jmp_r10 jmp_r11 proc_e
tb=0; te=0; tg=0; nsw=0
for f in "$CORPUS"/*.sno; do
  [ -e "$f" ] || continue   # unmatched glob with nullglob unset -- refuse below, never silently skip
  [ "$(basename "$f")" = "ALL.sno" ] && continue   # THE ONE FLAT RUNGS is suite data, never a standalone program
  nsw=$((nsw+1))
  b=$(basename "$f" .sno); [ -n "$1" ] && [ "$b" != "$1" ] && continue
  s=$(SCRIP_WREG=${SCRIP_WREG:-1} "$SCRIP" --compile "$f" 2>/dev/null < /dev/null) || continue
  nb=$(echo "$s" | grep -cE "$P_BLOB"); [ "$nb" = 0 ] && continue
  ne=$(echo "$s" | grep -cE "$P_ENT"); ng=$(echo "$s" | grep -cE "$P_EXG")
  no=$(echo "$s" | grep -cE "$P_EXO"); np=$(echo "$s" | grep -cE "$P_PROC")
  printf "%-24s %6s %6s %6s %6s %6s\n" "$b" "$nb" "$ne" "$ng" "$no" "$np"
  tb=$((tb+nb)); te=$((te+ne)); tg=$((tg+ng))
done
echo "---"
printf "TOTALS  blobs=%s  blob_entries=%s  gamma_exits=%s  programs_swept=%s\n" $tb $te $tg $nsw
if [ "$nsw" -eq 0 ]; then
  echo "⛔ REFUSE: zero programs swept from $CORPUS -- an exits==blobs verdict over an empty population is vacuous, not clean."
  exit 2
fi
echo "LAW: gamma_exits MUST equal blobs (every blob converts its own exit pair)."
echo "     blob_entries >= blobs is EXPECTED (several call sites may target one blob)."
[ "$tg" = "$tb" ] && echo "VERDICT: exits==blobs OK" || echo "⛔ VERDICT: exits($tg) != blobs($tb) -- unconverted blob exits exist"
