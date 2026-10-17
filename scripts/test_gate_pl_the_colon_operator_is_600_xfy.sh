#!/usr/bin/env bash
# test_gate_pl_the_colon_operator_is_600_xfy.sh -- THE COLON IS op(600, xfy, :), AS IN gprolog AND swipl (and the Logtalk suite: lgt_operators_40).
# hq_prolog 2026-09-25, CEO-1270; the cure is prolog_parse.c's infix table, which carried ":" at 200 -- the priority of ^ -- so a:b+c read as
# (a:b)+c where both oracles read a:(b+c), and current_op(P, T, :) answered 200 xfy. NO MONITOR BRACKET: a reader table, compared line for line.
# RED BEFORE on origin: op(200,xfy) and +(:(a,b),c), m3 AND m4.
set -u
GATE_NAME=test_gate_pl_the_colon_operator_is_600_xfy
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
main :- ( current_op(P, T, :) -> write(op(P, T)) ; write(none) ), nl, X = (a:b+c), write_canonical(X), nl, Y = (a:b:c), write_canonical(Y), nl.
:- initialization(main).
EOP
want='op(600,xfy)
:(a,+(b,c))
:(a,:(b,c))'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: the colon is 600 xfy in the reader and in current_op/3, both modes as gprolog and swipl"
exit 0
