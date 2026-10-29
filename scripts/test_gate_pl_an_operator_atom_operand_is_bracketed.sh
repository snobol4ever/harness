#!/usr/bin/env bash
# test_gate_pl_an_operator_atom_operand_is_bracketed.sh -- AN ATOM THAT IS AN OPERATOR, WRITTEN AS THE OPERAND OF AN INFIX OPERATOR, IS BRACKETED
# (ISO 7.10.5 h: "an atom which is an operator ... is output with brackets" as an operand, so the text reads back as the same term; hq_prolog
# 2026-09-25, CEO-1266; the cure is unification.c plc_wt's infix arm and plc_first_char).
# THE DEFECT. The prefix-operator arm already bracketed an operator-atom operand (-(-)); the infix arm never looked, so write((<)/(>)) printed
# `</ >`, writeq((:-)/2) printed `:-/2`, writeq((-)-1) printed `--1` -- text that does not read back as the term written (--1 is -(-(1))).
# THE EXPECTATIONS ARE THE ORACLES': gprolog and swipl print the eleven lines below identically (2026-09-25). The two lines they disagree on --
# p:-(dynamic) (dynamic is no operator in gprolog) and - (1) against - 1 -- are left out on purpose; neither is this defect.
# RED BEFORE on origin 62a21f70f, m3 AND m4: lines 1, 2, 4, 5 and 6 read </ >, :-/2, 1- -, --1, a= \+ .
set -u
GATE_NAME=test_gate_pl_an_operator_atom_operand_is_bracketed
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/wop.pl" <<'EOP'
main :- write((<)/(>)), nl, writeq((:-)/2), nl, writeq(- (-)), nl, writeq(1 - (-)), nl, writeq((-) - 1), nl, writeq(a = (\+)), nl,
        writeq([-, +]), nl, writeq(f(:-, <)), nl, write(a+b), nl, writeq(- - a), nl, writeq((a :- b)), nl.
:- initialization(main).
EOP
want='(<)/(>)
(:-)/2
- (-)
1-(-)
(-)-1
a=(\+)
[-,+]
f(:-,<)
a+b
- -a
a:-b'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 20 "$SCRIP" "$TMPD/wop.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/wop.s" "$TMPD/wop.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/wop.s" -o "$TMPD/wop.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 20 "$TMPD/wop.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/wop.s" "$TMPD/wop.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: an operator atom written as an infix operand is bracketed, both modes as gprolog and swipl"
exit 0
