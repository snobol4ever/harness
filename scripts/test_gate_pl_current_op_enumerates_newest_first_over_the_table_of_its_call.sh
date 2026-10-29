#!/usr/bin/env bash
# test_gate_pl_current_op_enumerates_newest_first_over_the_table_of_its_call.sh -- current_op/3 ENUMERATES NEWEST FIRST OVER THE OPERATORS OF ITS CALL (as gprolog; Logtalk current_op_3 iso_current_op_3_40).
# hq_prolog 2026-09-25, CEO-1270; the cure is lower_prolog.c pl_cc_gen2_desc: the enumeration walked the table oldest-first, so a case that
# removes an operator after printing another -- op(444,fy,baz), op(444,fy,quux), current_op(444,fy,Op), write(Op), op(0,fy,quux), fail -- printed
# baz and never quux, where the suite accepts bazquux or quuxbaz. It now counts down from the table size taken at the call: an operator added
# meanwhile is not visited, one removed meanwhile is skipped (gprolog's answer; swipl alone also keeps the removed one).
# RED BEFORE on origin: "baz" and "a1a2a3", m3 AND m4.
set -u
GATE_NAME=test_gate_pl_current_op_enumerates_newest_first_over_the_table_of_its_call
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
main :- ( op(444, fy, baz), op(444, fy, quux), current_op(444, fy, Op), write(Op), op(0, fy, quux), fail ; true ), nl,
        ( op(445, fy, a1), op(445, fy, a2), op(445, fy, a3), current_op(445, fy, O2), write(O2), op(0, fy, a1), fail ; true ), nl.
:- initialization(main).
EOP
want='quuxbaz
a3a2'
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
echo "GATE PASS [$GATE_NAME]: current_op/3 walks the operators of its call newest-first, both modes as gprolog"
exit 0
