#!/usr/bin/env bash
# test_gate_rebus_derived_refs_match_their_rival_oracle.sh -- A NO-RIVAL LANGUAGE'S REF IS DERIVED, AND
# THE DERIVATION IS RE-COMPUTED HERE RATHER THAN BELIEVED.  CEO-607 (2026-09-12, hq_C's ASK, option (a)).
#
# ⛔ THE PROBLEM THIS EXISTS FOR.  Rebus has no independent rival implementation, so CEO-391's one-oracle-
# per-language has no binary to name for it and `corpus/benchmarks/rebus/*.reb` can never carry an
# oracle-cut ref.  The tempting repair -- run SCRIP and save what it printed -- is the one repair that
# measures nothing: A REF CUT FROM THE IMPLEMENTATION IT GRADES PROVES ONLY THAT THE IMPLEMENTATION IS
# DETERMINISTIC, and Rebus is the one language where that mistake is easy to make because nothing else can
# be asked.  CEO-607 rules the answer: the ref is DERIVED, the derivation is RECORDED beside it, and the
# strongest derivation is a CROSS-LANGUAGE COMPUTATION of the same kernel under a real oracle, with the
# hand arithmetic as the second witness.
#
# ⭐ AND A RECORDED DERIVATION THAT NOBODY RE-EXECUTES IS A CLAIM, NOT A MEASUREMENT.  A static sidecar
# rots exactly the way this tree's digests rot -- it stays readable and persuasive while the thing it
# describes moves underneath it.  So the record does not stand alone: this gate re-runs each rival kernel
# under the LIVE oracle every time and diffs that output against the .ref the Rebus kernel is graded by.
# The .derivation file is the human half; this gate is the half that can fail.
#
# THE ARMS, per kernel named in the table below:
#   1  the kernel, its .ref and its .derivation all exist (a derived ref with no derivation beside it is
#      exactly the authored-number-nobody-can-check that the ruling forbids).
#   2  the .derivation NAMES its rival fixture by path, and that fixture exists -- the record points at a
#      real program, never at a remembered one.
#   3  the rival runs under the live SNOBOL4 oracle (`sbl -bf`) and its stdout is BYTE-IDENTICAL to the
#      .ref.  This is the derivation itself, re-performed.
#   4  the hand arithmetic recorded as WITNESS 2 is present in the .derivation and names the same number
#      the .ref carries -- two independent witnesses agreeing, which is the whole point of recording two.
#
# ⛔ IT DOES NOT RUN SCRIP AT ALL, AND THAT IS DELIBERATE.  This gate grades the REF, not the compiler.
# Whether SCRIP agrees with the ref is the benchmark harness's question and a separate verdict; if this
# gate ran SCRIP too, a seat could satisfy it by changing the ref to whatever SCRIP prints -- which is the
# circularity the ruling exists to close.
#
# REFUSES rc=2 when it cannot measure (oracle missing, corpus missing, mktemp failure).  A test that
# cannot measure refuses; it never skips-as-success (RULES.md; CLAUDE.md § Testing).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
BENCH="$S4E/corpus/benchmarks/rebus"
FIX="$HERE/fixtures/rebus_derivation"
NAME="$(basename "$0")"

refuse() { echo "⛔ REFUSE(2) $NAME: $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot source lib_oracle_flags.sh -- the ONE oracle authority"
SBL="$(sbl_correctness_bin 2>/dev/null)" || refuse "sbl_correctness_bin refused -- no SNOBOL4 oracle to derive against"
SBLFLAGS="$(sbl_lang_flags 2>/dev/null)" || refuse "sbl_lang_flags refused"
[ -x "$SBL" ] || refuse "oracle not executable at '$SBL' (an absent oracle prints a full, plausible, entirely false all-FAIL table -- so this refuses instead)"
[ -d "$BENCH" ] || refuse "no corpus/benchmarks/rebus at '$BENCH'"
[ -d "$FIX" ] || refuse "no rival fixtures at '$FIX'"
TMP="$(mktemp -d)" || refuse "mktemp -d failed"
trap 'rm -rf "$TMP"' EXIT

# kernel                 hand-arithmetic number that WITNESS 2 must state (checked against the .ref too)
KERNELS="arith_loop fib_recur string_concat"
fails=0; checks=0
for k in $KERNELS; do
  reb="$BENCH/$k.reb"; ref="$BENCH/$k.ref"; drv="$BENCH/$k.derivation"; rival="$FIX/$k.sno"
  # ARM 1 -- the three files of a derived-ref entry
  for f in "$reb" "$ref" "$drv"; do
    checks=$((checks+1))
    if [ -f "$f" ]; then echo "ok   $k: exists $(basename "$f")"
    else echo "FAIL $k: missing $f -- a derived ref is the kernel, its ref AND its recorded derivation"; fails=$((fails+1)); fi
  done
  [ -f "$ref" ] && [ -f "$drv" ] || continue
  # ARM 2 -- the record names a rival fixture that exists, and names THIS one
  checks=$((checks+1))
  if grep -qF "fixtures/rebus_derivation/$k.sno" "$drv"; then echo "ok   $k: derivation names its rival fixture by path"
  else echo "FAIL $k: $k.derivation does not name fixtures/rebus_derivation/$k.sno -- the record must point at a real program"; fails=$((fails+1)); fi
  checks=$((checks+1))
  if [ -f "$rival" ]; then echo "ok   $k: rival fixture present"
  else echo "FAIL $k: rival fixture missing at $rival"; fails=$((fails+1)); continue; fi
  # ARM 3 -- THE DERIVATION, RE-PERFORMED: the rival under the live oracle, byte-identical to the ref
  cp "$rival" "$TMP/$k.sno" || refuse "cannot stage $rival"
  ( cd "$TMP" && timeout -k 5 120 "$SBL" $SBLFLAGS "$k.sno" < /dev/null > "$k.out" 2> "$k.err" )
  orc=$?
  checks=$((checks+1))
  if [ $orc -ne 0 ]; then
    echo "FAIL $k: oracle exited rc=$orc running the rival -- $(tr '\n' ' ' < "$TMP/$k.err" | cut -c1-200)"; fails=$((fails+1))
  elif diff -u "$ref" "$TMP/$k.out" > "$TMP/$k.diff" 2>&1; then
    echo "ok   $k: rival under $(basename "$SBL") $SBLFLAGS reproduces $k.ref byte-for-byte ($(tr -d '\n' < "$ref"))"
  else
    echo "FAIL $k: the live derivation DISAGREES with $k.ref --"; sed -n '1,12p' "$TMP/$k.diff"; fails=$((fails+1))
  fi
  # ARM 4 -- WITNESS 2 present and naming the same number
  want="$(tr -d '\n' < "$ref")"
  checks=$((checks+1))
  if grep -q 'WITNESS 2' "$drv" && grep -qF "$want" "$drv"; then echo "ok   $k: WITNESS 2 (hand arithmetic) present and states $want"
  else echo "FAIL $k: $k.derivation lacks a WITNESS 2 stating $want -- two independent witnesses is the ruling's shape"; fails=$((fails+1)); fi
done

echo "---- $NAME: $checks checks, $fails failed (oracle $SBL $SBLFLAGS)"
[ $fails -eq 0 ] || { echo "⛔ $NAME: FAIL"; exit 1; }
echo "✅ $NAME: PASS -- every Rebus derived ref was re-derived from its rival under the live oracle"
