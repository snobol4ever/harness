#!/usr/bin/env bash
# util_regen_parser_demos.sh [--cut-refs] -- THE SEVEN BOOTSTRAP PARSERS AS SNOCONE DEMOS (Lon 2026-09-30, in-chat to the ceo,
# verbatim: "Add the seven parser_lang.sc programs as DEMOS and benchmarks for Snocone."; a demo is a test on its sample input and
# a workhorse benchmark on its full input, run once at wall clock -- Lon 2026-09-27, CEO-1312/1313).
# For each language L the demo corpus/demos/snocone/parser_L/parser_L.sc is REGENERATED from SCRIP/bootstrap: the 14-file runtime
# chain in run_scrip_parser.sh's order plus bootstrap/parser_L.sc, concatenated (a Snocone program cannot include a library; no
# .chain sidecar -- that name is the demo runner's own library declaration, corpus-relative -- the list lives here and in the gate). The demo's sample input parser_L.in and its workhorse
# input parser_L.work are corpus data (a small and a large program of L) and are NOT touched here; --cut-refs writes parser_L.ref
# from the Snocone oracle: sbl -bf running the transpiled twin of the demo (scrip --transpile) on parser_L.in -- the same program on
# the reference SNOBOL4, never this compiler's own output. A stale copy is what test_gate_parser_demos_match_bootstrap.sh reds.
# rc 0 written; 2 a chain file, a parser, the transpile or the oracle missing.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); ROOT=$(cd "$W/.." && pwd); B="$W/bootstrap"; D="$ROOT/corpus/demos/snocone"
SBL="${SBL:-/home/resources/x64/bin/sbl}"; CUT=0; [ "${1:-}" = --cut-refs ] && CUT=1
# The oracle cuts each ref at the sizes the chain declares for it, bootstrap/parser_<lang>.oracle_args (ceo CEO-1353, RULES.md
# clause 8 (g)(3): the one reader passes the oracle's declaration whenever a ref is cut), never a size typed here.
. "$here/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
CHAIN="global case assign match counter stack tree ShiftReduce tdump gen qize semantic omega trace"
for f in $CHAIN; do [ -f "$B/$f.sc" ] || { echo "REFUSE(2): no $B/$f.sc"; exit 2; }; done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
for L in snobol4 snocone icon prolog rebus raku pascal; do
    [ -f "$B/parser_$L.sc" ] || { echo "REFUSE(2): no $B/parser_$L.sc"; exit 2; }
    d="$D/parser_$L"; mkdir -p "$d"
    { for f in $CHAIN; do cat "$B/$f.sc"; done; cat "$B/parser_$L.sc"; } > "$d/parser_$L.sc"
    if [ $CUT = 1 ]; then
        [ -s "$d/parser_$L.in" ] || { echo "REFUSE(2): $d/parser_$L.in (the sample input) is missing"; exit 2; }
        [ -x "$SBL" ] || { echo "REFUSE(2): no oracle at $SBL"; exit 2; }
        "$W/scrip" --transpile "$d/parser_$L.sc" > "$T/$L.sno" 2> "$T/$L.err" && [ -s "$T/$L.sno" ] || { echo "REFUSE(2): transpile of parser_$L failed: $(head -2 "$T/$L.err")"; exit 2; }
        OARGS="$(declared_oracle_args_beside "$B/parser_$L.sc")" || { echo "REFUSE(2): bootstrap/parser_$L.oracle_args is refused"; exit 2; }
        ( cd "$d" && timeout -k 5 300 "$SBL" -bf $OARGS "$T/$L.sno" < "parser_$L.in" > "$T/$L.ref" 2> "$T/$L.sbl.err" ); rc=$?
        [ $rc -eq 0 ] && [ -s "$T/$L.ref" ] && ! grep -q '^Parse Error' "$T/$L.ref" || { echo "REFUSE(2): sbl -bf did not print a tree for parser_$L on its sample (rc=$rc): $(head -2 "$T/$L.sbl.err" "$T/$L.ref" | tr '\n' ' ' | cut -c1-200)"; exit 2; }
        cp "$T/$L.ref" "$d/parser_$L.ref"
    fi
    echo "parser_$L: $(wc -l < "$d/parser_$L.sc") lines$( [ $CUT = 1 ] && echo ", ref $(wc -l < "$d/parser_$L.ref") lines from sbl -bf")"
done
