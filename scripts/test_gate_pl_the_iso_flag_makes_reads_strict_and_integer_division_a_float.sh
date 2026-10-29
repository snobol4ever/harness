#!/usr/bin/env bash
# test_gate_pl_the_iso_flag_makes_reads_strict_and_integer_division_a_float.sh -- set_prolog_flag(iso, true) MAKES AN ARGUMENT OVER PRIORITY 999 A SYNTAX ERROR AND 4 / 2 A FLOAT; THE DEFAULT IS UNCHANGED (ceo CEO-1272).
# hq_prolog 2026-09-25, CEO-1270/1272. RULED: under THE SUPERSET the default reads f(a:-b) and gives 4 / 2 = 2 as swipl does, so SWI and the
# swipl-cut refs do not move; ISO's answer -- a syntax error (6.3.4.1: an argument's priority is at most 999) and 2.0 (9.1.7) -- comes through
# ISO's own switch. THE CURE: the flag table gains iso (by_name_dispatch.c, rt_pl_iso_mode), / of two integers is a float under it, and the
# reader (prolog_parse.c) parses arguments and list elements at 999 when the flag is on -- seeded from the runtime flag for read/1 and set by a
# compile-time :- set_prolog_flag(iso, _) directive for the source, as double_quotes is. The Logtalk runner sets the flag as a suite directive
# (wg17_term_09/10, float_division_2 13/14). NO MONITOR BRACKET: a flag the engine did not have. THE ORACLE IS swipl (gprolog is always strict).
# RED BEFORE on origin: set_prolog_flag(iso, true) raised domain_error(prolog_flag, iso), m3 AND m4.
set -u
GATE_NAME=test_gate_pl_the_iso_flag_makes_reads_strict_and_integer_division_a_float
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
r(Text) :- open('isog.txt', write, W), write(W, Text), close(W), open('isog.txt', read, S),
    catch((read(S, T), write(read(T))), error(E, _), (functor(E, F, _), write(F))), close(S), nl.
d :- X is 4 / 2, Y is 7 / 2, Z is 4 // 2, write(X/Y/Z), nl.
main :- d, r('f(a:-b). '), set_prolog_flag(iso, true), current_prolog_flag(iso, V), write(V), nl, d,
        r('f(a:-b). '), r('f(:-b). '), r('[a:-b]. '), r('f((a:-b)). '), r('a :- b. '), r('f(a,-). '), set_prolog_flag(iso, false), d.
:- initialization(main).
EOP
want='2/3.5/2
read(f((a:-b)))
true
2.0/3.5/2
syntax_error
syntax_error
syntax_error
read(f((a:-b)))
read((a:-b))
read(f(a,-))
2/3.5/2'
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
echo "GATE PASS [$GATE_NAME]: the iso flag makes reads strict and / a float division, the default unchanged, both modes as swipl"
exit 0
