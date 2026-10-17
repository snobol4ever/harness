#!/usr/bin/env bash
# test_gate_parser_demos_match_bootstrap.sh -- the seven Snocone parser demos corpus/demos/snocone/parser_<lang>/parser_<lang>.sc are
# byte-identical to the concatenation of the 14-file bootstrap runtime chain and bootstrap/parser_<lang>.sc -- a demo that drifted from
# SCRIP/bootstrap is a stale copy, cured by ../harness/scripts/util_regen_parser_demos.sh. rc 0 all seven match; 1 a drift named; 2 no demo tree.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); ROOT=$(cd "$W/.." && pwd); D="$ROOT/corpus/demos/snocone"; G=parser_demos_match_bootstrap
[ -d "$D" ] || { echo "GATE REFUSE(2) [$G]: no $D"; exit 2; }
CHAIN="global case assign match counter stack tree ShiftReduce tdump gen qize semantic omega trace"
n=0; bad=""
for L in snobol4 snocone icon prolog rebus raku pascal; do
    d="$D/parser_$L"; [ -s "$d/parser_$L.sc" ] || { bad="$bad parser_$L(missing)"; continue; }
    n=$((n+1))
    if ! { for f in $CHAIN; do cat "$W/bootstrap/$f.sc"; done; cat "$W/bootstrap/parser_$L.sc"; } | cmp -s - "$d/parser_$L.sc"; then bad="$bad parser_$L(drifted)"; fi
done
[ $n -eq 7 ] && [ -z "$bad" ] && { echo "GATE PASS(0) [$G]: 7 of 7 parser demos are the concatenation of their chain"; exit 0; }
echo "GATE FAIL(1) [$G]: $n of 7 present, stale or missing:$bad -- run ../harness/scripts/util_regen_parser_demos.sh"; exit 1
