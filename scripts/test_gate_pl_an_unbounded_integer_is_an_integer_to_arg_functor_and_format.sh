#!/usr/bin/env bash
# test_gate_pl_an_unbounded_integer_is_an_integer_to_arg_functor_and_format.sh -- AN UNBOUNDED INTEGER IS AN INTEGER TO arg/3, functor/3 AND format ~d / ~Nd / ~D (Logtalk unbounded functor_03, arg_01, arg_04, format_01, format_02).
# hq_prolog 2026-09-25, CEO-1270; the cure is by_name_dispatch.c pl_anum_check (arg/3 and functor/3 took DT_I alone as an integer, so a big
# integer raised type_error(integer, N) before its sign or size was looked at; its sign now comes from rt_big_cmp) and unification.c's format
# (~d went through plc_fmt_int, DT_I only; a big integer is now written from rt_big_str through the same digit core, plc_fmt_digits, that the
# machine-integer path now also uses). NO MONITOR BRACKET: error and output expectations, compared line for line. THE ORACLE IS swipl ALONE:
# gprolog's integers are bounded and 2^150 wraps to 0 there. RED BEFORE on origin, m3 AND m4: type_error(integer, ...) on lines 2-4 and every
# format line raising.
set -u
GATE_NAME=test_gate_pl_an_unbounded_integer_is_an_integer_to_arg_functor_and_format
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
t(G) :- catch((G -> write(yes) ; write(no)), error(E, _), (E = representation_error(_) -> write(representation_error) ; write(E))), nl.
main :- B is 2^150, N is -(2^150), t(arg(B, t(1,2,3), _)), t(arg(N, t(1,2,3), _)), t(functor(_, t, B)), t(functor(_, t, N)),
        t(format("~d", [B])), t(format("~2d", [B])), t(format("~D", [B])), t(format("~d", [N])), t(format("~2d", [314])).
:- initialization(main).
EOP
want='no
domain_error(not_less_than_zero,-1427247692705959881058285969449495136382746624)
representation_error
domain_error(not_less_than_zero,-1427247692705959881058285969449495136382746624)
1427247692705959881058285969449495136382746624yes
14272476927059598810582859694494951363827466.24yes
1,427,247,692,705,959,881,058,285,969,449,495,136,382,746,624yes
-1427247692705959881058285969449495136382746624yes
3.14yes'
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
echo "GATE PASS [$GATE_NAME]: a big integer is an integer to arg/3, functor/3 and format, both modes as swipl"
exit 0
