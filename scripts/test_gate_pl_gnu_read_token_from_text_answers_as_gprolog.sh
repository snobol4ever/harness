#!/usr/bin/env bash
# test_gate_pl_gnu_read_token_from_text_answers_as_gprolog.sh -- GNU's read_token_from_atom/2, read_token_from_chars/2 AND
# read_token_from_codes/2 ANSWER THE FIRST TOKEN OF A TEXT AS gprolog 1.6.0 DOES (cfo 2026-10-14, row
# prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: GNU BipsPl/const_io_driver's read_token cases).
#
# The three did not exist (existence_error). gnu_builtins.pl (SCRIP's own GNU text) now reads the first token after layout and
# comments ('$gnu_b_tok'/2): a name atom, var(Name) for an upper-case or underscore start, a number (decimal, float with a fraction
# and an exponent, 0x/0o/0b, 0'c -- '1.' and '1.e' stop before the dot), string(Atom) for "...", back_quotes(Atom) for `...`, a quoted
# atom, punct(P) for ( ) [ ] { } | and end_of_file, punct(full_stop) for an end dot, the solo atoms , ! ; and a symbol-char atom;
# an unbound text is instantiation_error and a non-atom type_error(atom, X). The token's value is read by SCRIP's own reader where it
# has one (a number, a quoted text).
#
# THE ARM: one program, 39 lines, the reference cut from gprolog 1.6.0 (the pristine oracle, 2026-10-14) and written out here, mode 3
# and mode 4. FAIL-ONCE, measured on the parent 8dceace06 rebuilt: 39 of 39 lines differ in both modes (the three do not exist);
# with the cure 39 of 39 as gprolog in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_read_token_from_text_answers_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
t(A) :- catch((read_token_from_atom(A, T) -> R = T ; R = no), error(E, _), R = err(E)), writeq(A-R), nl.
:- initialization(main).
main :- forall(member(A, ['foo(bar)', 'X', '_', '_Var', '123 abc', '3.25', '1.0e10', '0x1F', '0''a', '"str"', '`bq`', '''q a''', '', '   ', '( x', ')', '[', ']', '{', '}', ',', '|', '.', 'a.b', '+ 1', '=..', '- 5', '-5', '% c\nx', '/* c */ y', 'foo bar', '"a\\nb"', '1.', '1.e', 'Abc_1']), t(A)),
  catch(read_token_from_atom(_, _), error(E, _), (writeq(E), nl)),
  catch(read_token_from_atom(f(x), _), error(E2, _), (writeq(E2), nl)),
  read_token_from_codes("3.25", C1), writeq(C1), nl, read_token_from_chars([',', a], C2), writeq(C2), nl.
PL
want="$(cat <<'WANT'
'foo(bar)'-foo
'X'-var('X')
'_'-var('_')
'_Var'-var('_Var')
'123 abc'-123
'3.25'-3.25
'1.0e10'-10000000000.0
'0x1F'-31
'0''a'-97
'"str"'-string(str)
'`bq`'-back_quotes(bq)
'''q a'''-'q a'
''-punct(end_of_file)
'   '-punct(end_of_file)
'( x'-punct('(')
')'-punct(')')
'['-punct('[')
']'-punct(']')
'{'-punct('{')
'}'-punct('}')
(',')-(',')
('|')-punct('|')
'.'-punct(full_stop)
'a.b'-a
'+ 1'-(+)
(=..)-(=..)
'- 5'-(-)
'-5'-(-)
'% c\nx'-x
'/* c */ y'-y
'foo bar'-foo
'"a\\nb"'-string('a\nb')
'1.'-1
'1.e'-1
'Abc_1'-var('Abc_1')
instantiation_error
type_error(atom,f(x))
3.25
','
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 39 of 39 lines as gprolog"
    else echo "  $label RED: $n of 39 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
