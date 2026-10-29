#!/usr/bin/env bash
# test_gate_pl_gnu_read_token_read_atom_read_integer_and_read_number_answer_as_gprolog.sh -- GNU Prolog's TOKEN READERS read_token/1,2, read_atom/1,2,
# read_integer/1,2 AND read_number/1,2 EXIST AND ANSWER AS gprolog, TOKEN FOR TOKEN, ERROR FOR ERROR (cfo 2026-10-15, row
# prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/read_driver).
#
# The four were absent from SCRIP (existence_error). They are now gprolog's scanner (scan_supp.c, parse_supp.c) ported to C beside the run-time reader
# (by_name_dispatch.c, the '$gnu_os' ops read_token, read_atom, read_integer, read_number), over the stream's FILE with pushback: gprolog's character
# classes byte by byte, names, variables, numbers (0'c, 0b 0o 0x, floats only with a digit after the point, an exponent only with a digit after it),
# quoted atoms, strings and back quotes with their escapes and errors, punctuation, the open-immediately parenthesis, the full stop, both comment forms.
# A token's position is gprolog's: the line, and the BYTE column of its first character. An error answers syntax_error('FILE:LINE (char:COL) MESSAGE')
# with gprolog's message (read_integer and read_number name no file, as gprolog), leaves the stream where gprolog leaves it, and is recorded for
# syntax_error_info/4. gnu_builtins.pl checks the value argument before the stream, as gprolog's read_c.c.
#
# THE ARM: one program (no SWI marker), 75 lines, the reference cut from gprolog 1.6.0 (2026-10-15), mode 3 and mode 4: a two-line token stream
# read to its end, then the value readers and their errors, the recorded error, and the argument checks.
# FAIL-ONCE, measured on the parent (SCRIP d40277faa rebuilt): every line differs in both modes (the four predicates do not exist there).
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~10 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_read_token_read_atom_read_integer_and_read_number_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
toks(S, Ts) :- catch(read_token(S, T), error(F, _), T = err(F)), ( T == punct(end_of_file) -> Ts = [T] ; Ts = [T|R], toks(S, R) ).
main :- open('tok.txt', write, W), write(W, 'f(X_1, _, "s\\x41\\t", `bq`, [a|B], {c}) :- 0''a + 0''\\n - 0b101 * 0o17 / 0xff, 12.5e3 =.. 1.e5; 12.e, ''it''''s'' ! a.b +-* /* c */ % c\n.x ''bad\\q'' 0x 7 ''open\n'),
  close(W), open('tok.txt', read, S), toks(S, Ts), close(S), forall(member(T, Ts), (writeq(T), nl)),
  open('num.txt', write, W2), write(W2, 'hello ''quoted atom'' 42 -17 3.5 0''a abc 7 "dq" - x'), close(W2), open('num.txt', read, R, [alias(rn)]),
  t(read_atom(rn, _)), t(read_atom(rn, _)), t(read_integer(rn, _)), t(read_integer(rn, _)), t(read_number(rn, _)), t(read_number(rn, _)), t(read_integer(rn, _)),
  t(read_atom(rn, 7)), t(read_atom(rn, _)), t(read_integer(rn, _)), t(read_atom(rn, _)), t(read_number(rn, _)), t(read_number(rn, _)), t(syntax_error_info(_, _, _, _)), close(R),
  t(read_atom(nosuch, _)), t(read_number(_, _)), t(read_integer(user_output, _)), t(read_number(user_input, a)), t(read_integer(user_input, 1.5)), t(read_token(_)).
PL
want="$(cat <<'WANT'
f
punct('(')
var('X_1')
','
var('_')
','
string(sAt)
','
back_quotes(bq)
','
punct('[')
a
punct('|')
var('B')
punct(']')
','
punct('{')
c
punct('}')
punct(')')
:-
97
+
10
-
5
*
15
/
255
','
12500.0
=..
1
'.'
e5
;
12
'.'
e
','
'it''s'
!
a
'.'
b
+-*
'.'
x
err(syntax_error('tok.txt:2 (char:9) unknown escape sequence'))
0
x
7
err(syntax_error('tok.txt:2 (char:22) unexpected newline'))
punct(end_of_file)
read_atom(rn,A) => [read_atom(rn,hello)]
read_atom(rn,A) => [read_atom(rn,'quoted atom')]
read_integer(rn,A) => [read_integer(rn,42)]
read_integer(rn,A) => [read_integer(rn,-17)]
read_number(rn,A) => [read_number(rn,3.5)]
read_number(rn,A) => [read_number(rn,97)]
read_integer(rn,A) => error(syntax_error('(char:36) invalid start of number'))
read_atom(rn,7) => error(type_error(atom,7))
read_atom(rn,A) => error(syntax_error('num.txt:1 (char:40) cannot start an atom (use quotes ?)'))
read_integer(rn,A) => [read_integer(rn,7)]
read_atom(rn,A) => error(syntax_error('num.txt:1 (char:42) cannot start an atom (use quotes ?)'))
read_number(rn,A) => error(syntax_error('(char:42) invalid start of number'))
read_number(rn,A) => error(syntax_error('(char:49) invalid start of number'))
syntax_error_info(A,B,C,D) => [syntax_error_info('',1,49,'invalid start of number')]
read_atom(nosuch,A) => error(existence_error(stream,nosuch))
read_number(A,B) => error(instantiation_error)
read_integer(user_output,A) => error(permission_error(input,stream,user_output))
read_number(user_input,a) => error(type_error(number,a))
read_integer(user_input,1.5) => error(type_error(integer,1.5))
read_token(A) => [read_token(punct(end_of_file))]
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f tok.txt num.txt && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $n_want of $n_want lines as gprolog"
    else echo "  $label RED: $n of $n_want gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -20 | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
