#!/usr/bin/env bash
# test_gate_pl_a_prefix_operator_wins_the_write_over_a_postfix_one.sh -- AN ATOM THAT IS BOTH A PREFIX AND A POSTFIX OPERATOR WRITES o(X) IN PREFIX FORM (as gprolog and swipl; Logtalk op_3 iso_op_3_20).
# hq_prolog 2026-09-25, CEO-1270; the cure is unification.c plc_op_info/plc_op_is_postfix: the writer took whichever user definition it met
# first and chose postfix whenever ANY postfix definition existed, so after op(555, xf, o) beside op(555, fx, o), o(2) printed "2 o".
# BRACKET-FREE: an output divergence on the writer, compared line for line with gprolog. A postfix-only atom still writes postfix (last line).
# RED BEFORE on origin: 2 o / 3 o / 9 o, m3 AND m4.
set -u
GATE_NAME=test_gate_pl_a_prefix_operator_wins_the_write_over_a_postfix_one
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
o(1). o(2). o(3).
main :- ( op(555, fx, o), o(X), write(o(X)), nl, op(555, xf, o), fail ; true ), write(o(9)), nl,
        op(0, fx, o), write(o(9)), nl.
:- initialization(main).
EOP
want='o 1
o 2
o 3
o 9
9 o'
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
echo "GATE PASS [$GATE_NAME]: a prefix definition wins the write, a postfix-only one still writes postfix, both modes as gprolog"
exit 0
