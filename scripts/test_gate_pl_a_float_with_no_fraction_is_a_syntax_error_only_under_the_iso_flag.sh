#!/usr/bin/env bash
# test_gate_pl_a_float_with_no_fraction_is_a_syntax_error_only_under_the_iso_flag.sh -- 1e33 READS AS swipl READS IT BY DEFAULT, AND IS A
# SYNTAX ERROR UNDER set_prolog_flag(iso, true), AS ISO 6.4.5 AND gprolog HAVE IT (ceo CEO-1524, 2026-10-05, on the cfo's ask: the SWI
# suite's own sources carry dotless floats -- test_format.pl 1e100, test_real.pl 1e18 -- so the default is swipl's; the strict reading is a
# feature of the flag). cfo, row prolog-logtalk-numbers-read-accepts-1e33-with-no-fraction-where-iso-wants-a-syntax-error.
# THE CURE: prolog_lex.c S_INT takes the dotless-exponent branch only when the lexer's iso bit is clear (prolog_parse_ex copies the flag into
# it, so read/1, read_term/2,3, atom_to_term/3 and consult all see it); pl_parse_number refuses a float with no '.' under the flag, so
# number_codes/2 and number_chars/2 raise syntax_error as gprolog does. RED BEFORE on origin f4b897b5a: the iso half read every line, m3 AND m4.
# The default half is swipl's reading line for line (swipl 9, measured: it ignores the iso flag here); the iso half is gprolog 1.4.5's verdict
# for each input (gprolog has no iso flag; it reads strictly always). NO MONITOR BRACKET: a reader decision compared line for line.
set -u
GATE_NAME=test_gate_pl_a_float_with_no_fraction_is_a_syntax_error_only_under_the_iso_flag
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
printf '1e33.\n1E-3.\n1.0e33.\n2.5E+2.\n7.\n' > "$TMPD/f.in"
cat > "$TMPD/w.pl" <<'EOP'
r(S) :- catch((read(S, X), (X == end_of_file -> true ; writeq(got(X)), nl, r(S))), error(syntax_error(_), _), (write(syntax_error), nl, r(S))).
t(G) :- catch((G -> writeq(G) ; write(failed)), error(syntax_error(_), _), write(syntax_error)), nl.
pass :- open('f.in', read, S), r(S), close(S),
        t(number_codes(_, "1e33")), t(number_chars(_, ['1','E','3'])), t(atom_to_term('1e33', _, _)), t(number_codes(_, "1.5e3")).
main :- write(default), nl, pass, set_prolog_flag(iso, true), write(iso), nl, pass.
:- initialization(main).
EOP
want="$(cat <<'EOW'
default
got(1.0e+33)
got(0.001)
got(1.0e+33)
got(250.0)
got(7)
number_codes(1.0e+33,[49,101,51,51])
number_chars(1000.0,['1','E','3'])
atom_to_term('1e33',1.0e+33,[])
number_codes(1500.0,[49,46,53,101,51])
iso
syntax_error
syntax_error
got(1.0e+33)
got(250.0)
got(7)
syntax_error
syntax_error
syntax_error
number_codes(1500.0,[49,46,53,101,51])
EOW
)"
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
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-400)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a dotless float reads as swipl reads it by default and is a syntax error under the iso flag, both modes"
exit 0
