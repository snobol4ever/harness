#!/usr/bin/env bash
# util_regen_parser_benchmarks.sh [--cut-refs] -- THE SEVEN BOOTSTRAP PARSERS AS SNOCONE BENCHMARKS (Lon 2026-09-30, in-chat to the
# ceo, verbatim: "Add the seven parser_lang.sc programs as DEMOS and benchmarks for Snocone."; the demo half landed in
# util_regen_parser_demos.sh -- this is the benchmark half, Lon re-asked 2026-10-01: "Ensure the seven parser.sc programs become
# official DEMOS and BENCHMARKS. They need REF files for a good sample input. They need to be included in the Snocone demos.").
# For each language L, corpus/benchmarks/snocone/parsers/parser_L.sc is REGENERATED from the already-regenerated demo copy
# corpus/demos/snocone/parser_L/parser_L.sc (run util_regen_parser_demos.sh first if that is stale) by APPENDING one small,
# purely-additive kernel function + a // *BENCH marker (RULES.md FACT RULE THE KERNEL CONVENTION; ../harness/scripts/bench_wrap_snocone.py's
# MARKED mode uses the WHOLE file verbatim -- `body = lines` -- so appending after the existing driver changes nothing about the
# pristine program's own output; only a function DEFINITION and a // comment are added, neither executes on its own).
# All seven bootstrap parsers call their top-level rule the same way -- `Src ? *Compiland` -- so ONE kernel body is correct for
# all seven (verified this sitting, grep across all seven demo .sc, zero mismatches); the kernel re-runs InitCounter/InitStack
# (the same reset ParseOne() already does per call) + the parse alone, discarding the tree, so repeated timing calls do not also
# repeat the tree dump.
# THE SAMPLE: each language's EXISTING .work file (corpus/demos/snocone/parser_L/parser_L.work -- already a real, substantial
# source of L, already proven to run clean at the demo's declared heap/stack via its workhorse timing role) becomes
# parser_L.input here, a GOOD sample per Lon's ask, not the demo's small parser_L.in. --cut-refs writes parser_L.ref from the
# Snocone oracle: sbl -bf running the transpiled twin (scrip --transpile) of THIS file on parser_L.input, at the SAME heap/stack
# declared beside the demo (already proven sufficient for .work). HEAP/STACK sidecars are copied from the demo beside it.
# rc 0 written; 2 a demo copy, its .work, the transpile or the oracle missing.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); ROOT=$(cd "$W/.." && pwd)
D="$ROOT/corpus/demos/snocone"; BD="$ROOT/corpus/benchmarks/snocone/parsers"
SBL="${SBL:-/home/resources/x64/bin/sbl}"; CUT=0; [ "${1:-}" = --cut-refs ] && CUT=1
mkdir -p "$BD"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
for L in snobol4 snocone icon prolog rebus raku pascal; do
    dd="$D/parser_$L"
    [ -s "$dd/parser_$L.sc" ]   || { echo "REFUSE(2): no $dd/parser_$L.sc -- run util_regen_parser_demos.sh first"; exit 2; }
    [ -s "$dd/parser_$L.work" ] || { echo "REFUSE(2): no $dd/parser_$L.work (the workhorse sample)"; exit 2; }
    [ -s "$dd/parser_$L.heap" ] || { echo "REFUSE(2): no $dd/parser_$L.heap"; exit 2; }
    [ -s "$dd/parser_$L.stack" ] || { echo "REFUSE(2): no $dd/parser_$L.stack"; exit 2; }
    cp "$dd/parser_$L.sc" "$BD/parser_$L.sc"
    cat >> "$BD/parser_$L.sc" <<'KERNEL'

function ParseKernel(ZPN) {
    ZPI = 0;
ZPBL:
    InitCounter();
    InitStack();
    if (Src ? *Compiland) { ZPT = Pop(); }
    if (ZPI = LT(ZPI, ZPN) ZPI + 1) goto ZPBL;
    ParseKernel = ZPI;
    return;
}
// *BENCH kernel=ParseKernel check=1 bud=1000 flr=20
KERNEL
    cp "$dd/parser_$L.work" "$BD/parser_$L.input"
    cp "$dd/parser_$L.heap" "$BD/parser_$L.heap"
    cp "$dd/parser_$L.stack" "$BD/parser_$L.stack"
    kb=$(cut -f2 "$BD/parser_$L.heap"); sb=$(cut -f2 "$BD/parser_$L.stack")
    if [ $CUT = 1 ]; then
        [ -x "$SBL" ] || { echo "REFUSE(2): no oracle at $SBL"; exit 2; }
        "$W/scrip" --transpile "$BD/parser_$L.sc" > "$T/$L.sno" 2> "$T/$L.err" && [ -s "$T/$L.sno" ] || { echo "REFUSE(2): transpile of parser_$L failed: $(head -2 "$T/$L.err")"; exit 2; }
        ( timeout -k 5 300 "$SBL" -bf -d${kb}k -s${sb}k "$T/$L.sno" < "$BD/parser_$L.input" > "$T/$L.ref" 2> "$T/$L.sbl.err" ); rc=$?
        [ $rc -eq 0 ] && [ -s "$T/$L.ref" ] && ! grep -q '^Parse Error' "$T/$L.ref" || { echo "REFUSE(2): sbl -bf did not print a tree for parser_$L on its sample (rc=$rc): $(head -2 "$T/$L.sbl.err" "$T/$L.ref" | tr '\n' ' ' | cut -c1-200)"; exit 2; }
        cp "$T/$L.ref" "$BD/parser_$L.ref"
    fi
    echo "parser_$L: $(wc -l < "$BD/parser_$L.sc") lines, input $(wc -c < "$BD/parser_$L.input") bytes$( [ $CUT = 1 ] && echo ", ref $(wc -l < "$BD/parser_$L.ref") lines from sbl -bf")"
done
