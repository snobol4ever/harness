#!/usr/bin/env bash
# test_conformance_spitbol_manual.sh -- row `conformance-sweep-spitbol-manual`.
#
# Re-runs every witness under corpus/tests/snobol4/probe_loose/conformance/ (minted by the SPITBOL-manual conformance sweep --
# each witness is sourced from the manual's OWN worked example, v3.7) through test_one_witness.sh (m3 + m4
# vs the live x64 sbl oracle, -bf) and reports a compact PASS/DIFF table plus a summary line. A DIFF here
# reproduces an already-filed conformance-sweep queue row (see corpus/tests/snobol4/probe_loose/conformance/*.sno headers /
# the sweep's FINDING for which row owns which witness) -- this script is a fast re-check, not a triage
# tool: it does not classify NEW divergences, it only tells you whether a KNOWN one is still present.
#
# usage: bash ../harness/scripts/test_conformance_spitbol_manual.sh [--quiet]
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
D="$ROOT/../corpus/tests/snobol4/probe_loose/conformance"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
# ⛔⭐ THIS REFUSAL STANDS, AND HERE IS THE ANSWER TO ITS OWN QUESTION SO NOBODY RE-INVESTIGATES
# (hq_B 2026-08-30, row graders-denominator-audit-six-families). It asks "has the conformance sweep
# ever minted a witness?" -- YES: 132 of them. They were absorbed into the flat set by corpus
# 11a36c87 (Lon's ZERO-SUBFOLDERS + total-absorption ruling), which deleted probe_loose/ entirely.
# ⭐ BUT THIS IS NOT A COVERAGE HOLE AND MUST NOT BE "FIXED" BY RE-POINTING IT: all 132 carry a
# conformance origin/family in tests/snobol4/ALL.csv, NONE is in ALL.excluded.txt, and
# test_corpus_snobol4.sh grades the whole set (total=1726). So the witnesses ARE graded, every run.
# Re-pointing this script at ALL.* would duplicate the rungs board, not add coverage. It is a
# retirement candidate or a focused view, not a defect -- a corpus-layout call, deliberately not
# taken here. Contrast test_snocone_crosscheck_suites.sh, whose identical-looking refusal WAS a real
# hole (181 entries graded by nothing) and was re-pointed: the discriminator is whether a rung suite
# board over the family's ALL.* set exists, and it must be checked per family, never assumed.
[ -d "$D" ] || { echo "UNPROVEN (rc=2): no $D. Its 132 witnesses were absorbed into tests/snobol4/ALL.* by corpus 11a36c87 and ARE graded by test_corpus_snobol4.sh (total=1726, none excluded) -- redundant here, not missing. See the comment above before 'fixing' this."; exit 2; }
total=0; pass=0; diverge=0
for f in "$D"/*.sno; do
  [ -f "$f" ] || continue
  total=$((total+1))
  b="$(basename "$f" .sno)"
  line="$(bash "$ROOT/../harness/scripts/test_one_witness.sh" "$f" "conf_$b" 2>&1)"
  if printf '%s' "$line" | grep -q 'm3=PASS *m4=PASS'; then
    pass=$((pass+1))
    [ "$QUIET" = 1 ] || printf 'AGREE    %s\n' "$b"
  else
    diverge=$((diverge+1))
    printf 'DIVERGE  %s :: %s\n' "$b" "$line"
  fi
done
printf 'conformance-sweep-spitbol-manual: %d witnesses, %d agree, %d diverge\n' "$total" "$pass" "$diverge"
[ "$diverge" -eq 0 ]
