#!/usr/bin/env bash
# test_gate_pl_gnu_unget_get_key_and_the_implicit_stream_culprit_answer_as_gprolog.sh -- GNU Prolog's CHARACTER I/O EDGES ANSWER AS gprolog (cfo 2026-10-15,
# row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/char_io_driver).
#
# (1) unget_char/1,2, unget_code/1,2 and unget_byte/1,2 check as gprolog's char_io_c.c: the stream first (its type: unget_byte needs a binary stream,
# the others a text one), then the value -- a variable is an instantiation_error, unget_char a one-character atom else type_error(character, X)
# (end_of_file and 1 included), unget_code an integer else type_error(integer, X) and a code in 1..255 else representation_error(character_code)
# (gprolog's Is_Valid_Code), unget_byte a byte else type_error(byte, X). They used to accept 'ab' (pushing its first byte) or fail silently, and the
# 1-arity forms' assembly wrappers (rtx_plunify.s PL_CTX_LEAF) dropped the ball; they now raise it (PL_CTX_LEAF_BALL). unget_char pushes every byte
# of a multibyte character. (2) Outside the SWI dialect an error about the implicit stream of a 1-arity form names current_input_stream (or
# current_output_stream), and a 2-arity form names the stream as the caller wrote it (an alias stays the alias, also for past_end_of_stream) -- gprolog's
# pl_last_input_sora rule. (3) get_key/1,2 and get_key_no_echo/1,2 exist: on a non-terminal stream gprolog's Pl_Stream_Get_Key returns one byte and,
# unless it was a newline, discards the rest of the line up to the first control byte; -1 at the end; the stream checks before the integer check.
#
# THE ARM: one program (no SWI marker), 49 lines, the reference cut from gprolog 1.6.0 (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent (SCRIP 31a4cd718 rebuilt): 37 of 49 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~10 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_unget_get_key_and_the_implicit_stream_culprit_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
main :- open('a.txt', write, W), write(W, 'ab\nxyz\nqr\n'), close(W), open('b.bin', write, WB, [type(binary)]), put_byte(WB, 7), put_byte(WB, 8), close(WB),
  open('a.txt', read, _, [alias(u), eof_action(error)]),
  t(unget_char(u, z)), t((get_char(u, A), get_char(u, B))), t(unget_code(u, 0'y)), t(get_code(u, _)), t(unget_char(u, ab)), t(unget_char(u, end_of_file)), t(unget_char(u, 1)),
  t(unget_char(u, _)), t(unget_code(u, a)), t(unget_code(u, -3)), t(unget_code(u, 0)), t(unget_code(u, 256)), t(unget_byte(u, 1)),
  t((get_char(u, C1), get_char(u, C2), get_char(u, C3), get_char(u, C4), get_char(u, C5))), t(get_key(u, _)), t(get_key_no_echo(u, _)), t(get_key(u, _)),
  t(peek_code(u, _)), t(get_char(u, _)), close(u),
  open('b.bin', read, _, [type(binary), alias(r)]), t(unget_byte(r, 9)), t((get_byte(r, X1), get_byte(r, X2))), t(unget_byte(r, 256)), t(unget_byte(r, a)), t(unget_byte(r, _)),
  t(unget_char(r, a)), t(get_char(r, _)), t(get_key(r, _)), t(get_key(r, a)),
  set_input(r), t(get_char(_)), t(unget_char(a)), t(get_code(_)), t(peek_char(_)), t(get_key(_)), t(get_key_no_echo(_)), set_input(user_input), close(r),
  open('a.txt', read, I), set_input(I), t(get_byte(_)), t(unget_byte(5)), t(unget_char(_)), t(unget_code(a)), t(get_key(_)), t(get_key(a)), t(unget_char(q)), t(get_key_no_echo(_)), t(get_key(_)),
  t(get_key(_)), set_input(user_input), close(I),
  t(get_key(_, _)), t(get_key_no_echo(nosuch, _)), t(get_key(user_output, _)), t(unget_char(nosuch, a)), t(unget_code(_, 97)).
PL
want="$(cat <<'WANT'
unget_char(u,z) => [unget_char(u,z)]
get_char(u,A),get_char(u,B) => [(get_char(u,z),get_char(u,a))]
unget_code(u,121) => [unget_code(u,121)]
get_code(u,A) => [get_code(u,121)]
unget_char(u,ab) => error(type_error(character,ab))
unget_char(u,end_of_file) => error(type_error(character,end_of_file))
unget_char(u,1) => error(type_error(character,1))
unget_char(u,A) => error(instantiation_error)
unget_code(u,a) => error(type_error(integer,a))
unget_code(u,-3) => error(representation_error(character_code))
unget_code(u,0) => error(representation_error(character_code))
unget_code(u,256) => error(representation_error(character_code))
unget_byte(u,1) => error(permission_error(input,text_stream,u))
get_char(u,A),get_char(u,B),get_char(u,C),get_char(u,D),get_char(u,E) => [(get_char(u,b),get_char(u,'\n'),get_char(u,x),get_char(u,y),get_char(u,z))]
get_key(u,A) => [get_key(u,10)]
get_key_no_echo(u,A) => [get_key_no_echo(u,113)]
get_key(u,A) => [get_key(u,-1)]
peek_code(u,A) => error(permission_error(input,past_end_of_stream,u))
get_char(u,A) => error(permission_error(input,past_end_of_stream,u))
unget_byte(r,9) => [unget_byte(r,9)]
get_byte(r,A),get_byte(r,B) => [(get_byte(r,9),get_byte(r,7))]
unget_byte(r,256) => error(type_error(byte,256))
unget_byte(r,a) => error(type_error(byte,a))
unget_byte(r,A) => error(instantiation_error)
unget_char(r,a) => error(permission_error(input,binary_stream,r))
get_char(r,A) => error(permission_error(input,binary_stream,r))
get_key(r,A) => error(permission_error(input,binary_stream,r))
get_key(r,a) => error(permission_error(input,binary_stream,r))
get_char(A) => error(permission_error(input,binary_stream,current_input_stream))
unget_char(a) => error(permission_error(input,binary_stream,current_input_stream))
get_code(A) => error(permission_error(input,binary_stream,current_input_stream))
peek_char(A) => error(permission_error(input,binary_stream,current_input_stream))
get_key(A) => error(permission_error(input,binary_stream,current_input_stream))
get_key_no_echo(A) => error(permission_error(input,binary_stream,current_input_stream))
get_byte(A) => error(permission_error(input,text_stream,current_input_stream))
unget_byte(5) => error(permission_error(input,text_stream,current_input_stream))
unget_char(A) => error(instantiation_error)
unget_code(a) => error(type_error(integer,a))
get_key(A) => [get_key(97)]
get_key(a) => error(type_error(integer,a))
unget_char(q) => [unget_char(q)]
get_key_no_echo(A) => [get_key_no_echo(113)]
get_key(A) => [get_key(113)]
get_key(A) => [get_key(-1)]
get_key(A,B) => error(instantiation_error)
get_key_no_echo(nosuch,A) => error(existence_error(stream,nosuch))
get_key(user_output,A) => error(permission_error(input,stream,user_output))
unget_char(nosuch,a) => error(existence_error(stream,nosuch))
unget_code(A,97) => error(instantiation_error)
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f a.txt b.bin && "$@" 2>/dev/null | grep ' => ')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $n_want of $n_want lines as gprolog"
    else echo "  $label RED: $n of $n_want gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -20 | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
