#!/usr/bin/env bash
# census_zdp_sources.sh — corpus-wide ZDP TOP-source histogram + tier totals.  Re-run at every zeta-traversal handoff; the ACTIVATION percentage must be explainable, never merely low.
# ZDP corpus sweep: TOP-source op histogram + tier totals.  Reads compile STDERR only; never touches committed .s artifacts.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
OUT=${1:-/tmp/zdp_sweep_out}
mkdir -p "$OUT"; : > "$OUT/sources.txt"; : > "$OUT/tiers.txt"
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): corpus/probe/ was
# deleted wholesale (corpus-crosscheck-probe-total-conversion) -- dropped from the sweep. ALL.sno
# (THE ONE FLAT RUNGS, tests/snobol4/ALL.sno) is explicitly excluded too: it is a suite DATA file,
# one test per LINE, and is never a standalone program -- feeding it to `--compile` whole produces a
# few hundred spurious "duplicate label 'END'" errors that would otherwise pollute this histogram.
# ⛔ KNOWN LIMITATION, NOT FIXED HERE: excluding ALL.sno means the ~1500+ entries it now holds are
# invisible to this census (previously reachable as individual loose files) -- restoring that
# coverage needs the census to walk ALL.csv/harness-decompose the rungs, a bigger follow-up than a
# dead-path repoint. Flagged, not silently accepted as "the corpus is just smaller now."
n=0
for f in $(find $S4E/corpus/tests/snobol4 -name '*.sno' ! -name 'ALL.sno' | sort); do
    n=$((n+1))
    SCRIP_ZDP=2 timeout -k 5 15 ./scrip --compile "$f" < /dev/null 2>"$OUT/.err" >/dev/null
    grep "^\[ZDP\]   node" "$OUT/.err" | sed 's/.*op=\([A-Za-z0-9_]*\) \([A-Z-]*\) tier=\([A-Z]*\).*/\1 \2 \3/' >> "$OUT/sources.txt"
    grep "^\[ZDP\] graph" "$OUT/.err" | sed 's/.*TIER spine=\([0-9]*\) activation=\([0-9]*\) standing=\([0-9]*\)/\1 \2 \3/' >> "$OUT/tiers.txt"
done
echo "programs swept: $n"
echo "=== TOP-SOURCE op x class histogram ==="
sort "$OUT/sources.txt" | uniq -c | sort -rn
echo "=== TIER totals (spine activation standing) ==="
awk '{s+=$1; a+=$2; t+=$3} END {printf "spine=%d activation=%d standing=%d  total=%d  activation_pct=%.2f\n", s,a,t,s+a+t,100.0*a/(s+a+t)}' "$OUT/tiers.txt"
