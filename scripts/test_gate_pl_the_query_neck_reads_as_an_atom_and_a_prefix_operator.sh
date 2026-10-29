#!/usr/bin/env bash
# test_gate_pl_the_query_neck_reads_as_an_atom_and_a_prefix_operator.sh -- THE TOKEN ?- READS AS THE ATOM (?-) AND AS THE PREFIX OPERATOR 1200 fx (ISO 6.3.4.4, table 7).
# hq_prolog 2026-09-25, CEO-1270; the cure is prolog_parse.c: the lexer made a TK_QUERY token and the primary-term parser had no case for it
# (TK_NECK, the :- token, had one), so [(?-)] and X = (?- G) were syntax errors. Logtalk operators lgt_operators_19 died on it: its whole case program
# failed to parse. Clause-level "?- G." is left as it reads now: gprolog ignores such a line and swipl runs it, so no oracle rules it.
# THE EXPECTATIONS ARE gprolog's and swipl's (2026-09-25). RED BEFORE on origin: a parse error, no output, m3 AND m4.
set -u
GATE_NAME=test_gate_pl_the_query_neck_reads_as_an_atom_and_a_prefix_operator
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
main :- X = [(?-), (:-)], writeq(X), nl, Y = (?- p(1)), writeq(Y), nl, Y = '?-'(A), writeq(A), nl.
:- initialization(main).
EOP
want='[?-,:-]
?-p(1)
p(1)'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: (?-) reads as an atom and ?- G as a 1200 fx term, both modes as gprolog and swipl"
exit 0
