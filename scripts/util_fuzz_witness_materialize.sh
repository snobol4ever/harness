#!/usr/bin/env bash
# util_fuzz_witness_materialize.sh — rebuild row `fuzz-nondeterminism-rootcause`'s 5-witness set into ONE
# directory, so util_fuzz_witness_stability.sh / util_fuzz_witness_predicate_ladder.sh have something to
# point FUZZ_DIR at.  Prints the directory path on stdout (and nothing else on stdout), so it composes:
#     FUZZ_DIR="$(bash ../harness/scripts/util_fuzz_witness_materialize.sh)" bash ../harness/scripts/util_fuzz_witness_stability.sh
#
# ⛔⭐ WHY THIS EXISTS — THE ROW'S WITNESSES STOPPED BEING FILES AND ITS INSTRUMENTS DID NOT NOTICE.
# Both instruments defaulted FUZZ_DIR to corpus/tests/snobol4/probe_loose/fuzz.  The one-flat-suite
# cutover (corpus c06960a1, Lon 2026-08-29 total-conversion ruling) DELETED that directory: 4 of the 5
# witnesses were absorbed into the rungs suite as XFAIL block entries under NEW names, and only the
# 5th (fz_red_m4b, explicitly held out in ALL.excluded.txt) survives as a loose pair.  The instruments
# refused correctly (rc=2 "witness dir missing") rather than reporting an empty set as stable — the law
# working — but a refusal is not a measurement, and the row was left with NO instrument at all.
# ⭐ The witnesses did not become unavailable, only unreachable BY PATH: `corpus_suite_harness.py extract`
# reproduces each absorbed entry exactly.  This script is that recipe, so the next session runs one
# command instead of rediscovering the rename.
#
# ⛔ THE ENTRY NAMES ARE DERIVED FROM ALL.csv, NEVER HARDCODED.  Absorption renamed every witness
# (fz_segv_09 -> fence_pos_len_replace_branch_2, and so on); a hardcoded list would rot at the next
# rename exactly the way the FUZZ_DIR default just did.  ALL.csv's `family` column still carries the
# pre-absorption origin, so the mapping is recoverable from the corpus itself.  ⛔ Extraction goes
# through the harness's own `extract` verb and never through hand-copied text: seat11 measured that
# hand-retyped copies of these witnesses give a FALSE-CLEAN signal.
#
# EXIT: 0 = all 5 materialized · 2 = REFUSE, could not materialize the full set (an incomplete witness
# set is not a smaller witness set, it is a DIFFERENT experiment — this row has already been misled once
# by a set whose membership was not what the reader believed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
T="$ROOT/corpus/tests/snobol4"; HARNESS="$SD/../harness/scripts/corpus_suite_harness.py"
OUT="${OUT_DIR:-$(mktemp -d)}"
say() { printf '%s\n' "$*" >&2; }
[ -f "$T/ALL.sno" ] && [ -f "$T/ALL.ref" ] && [ -f "$T/ALL.csv" ] || { say "⛔ REFUSE(rc=2): rungs suite triple missing under $T"; exit 2; }
[ -f "$HARNESS" ] || { say "⛔ REFUSE(rc=2): harness missing at $HARNESS"; exit 2; }
mkdir -p "$OUT" || { say "⛔ REFUSE(rc=2): cannot create $OUT"; exit 2; }
n=0
# (a) the 4 ABSORBED witnesses — entry name from column 2, origin family from column 4.
while IFS=, read -r entry family; do
    [ -n "$entry" ] || continue
    short="$(printf '%s' "$family" | sed 's/^probe_loose_fuzz_//; s/_arbno_defer_blob$//; s/_blob_alt_fence_defer$//; s/_blob_defer_fence$//')"
    if python3 "$HARNESS" extract "$T/ALL.sno" "$T/ALL.ref" "$entry" "$OUT/$short.sno" --out-ref "$OUT/$short.ref" >/dev/null 2>&1; then
        n=$((n+1)); say "  materialized  $short  <- rungs entry $entry"
    else
        say "⛔ REFUSE(rc=2): harness could not extract rungs entry '$entry' (origin $family)"; exit 2
    fi
done < <(awk -F, 'NR>1 && $4 ~ /^probe_loose_fuzz_/ {print $2","$4}' "$T/ALL.csv")
# (b) the HELD-OUT witness that is still a loose pair (ALL.excluded.txt).  ⭐ It is not an oversight that
# this one is a file: it is the ONLY member of the five whose distribution straddles PASS, so converting
# it would have put a coin-flip verdict into the graded floor.  See the FINDING for the measurement.
for f in "$T"/probe_loose_fuzz_*.sno; do
    [ -e "$f" ] || continue
    b="$(basename "$f" .sno)"; short="$(printf '%s' "$b" | sed 's/^probe_loose_fuzz_//; s/_blob_defer_fence$//')"
    cp "$f" "$OUT/$short.sno" || { say "⛔ REFUSE(rc=2): cannot copy $f"; exit 2; }
    [ -f "${f%.sno}.ref" ] && cp "${f%.sno}.ref" "$OUT/$short.ref"
    n=$((n+1)); say "  materialized  $short  <- loose pair (held out of the rungs by ALL.excluded.txt)"
done
[ "$n" -eq 5 ] || { say "⛔ REFUSE(rc=2): materialized $n witnesses, expected 5 — the set changed; re-census ALL.csv and ALL.excluded.txt before grading anything against it"; exit 2; }
say "── 5/5 witnesses materialized into $OUT"
printf '%s\n' "$OUT"
