#!/usr/bin/env bash
# test_gate_pl_gnu_term_streams_aliases_and_mirrors_answer_as_gprolog.sh -- GNU Prolog's TERM STREAMS (open_input/output_atom/chars/codes_stream and their
# close_*), SEVERAL ALIASES PER STREAM (add_stream_alias/2, current_alias/2), MIRRORS (open/4 mirror(M), add_stream_mirror/2, remove_stream_mirror/2,
# current_mirror/2) AND current_stream/1 ANSWER AS gprolog (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks:
# BipsPl/stream_driver, its first half).
#
# A term stream is an unlinked tmpfile in the stream table (no FILE ever points into the moving heap), named "constant term stream" as gprolog names it,
# marked by its direction (fh_slot_t.tsk) so gprolog's close checks hold: close/1 on it is system_error('special stream: needs appropriate close predicate'),
# close_input_* takes any input term stream and close_output_* any output one (domain_error(term_stream_or_alias), permission_error(close, stream)), the
# output text read back as an atom, chars or codes, and a sink that does not unify leaves the stream open. A stream keeps its first alias in the slot and
# any further ones as atom ids in a raw heap block (fh_slot_t.xal), found by the alias lookup and enumerated by stream_property/2, which outside the SWI
# dialect no longer stops at the first alias(A) or mirror(M) of a bound stream. Mirrors are slot indices (fh_slot_t.mir, dropped when a mirror closes):
# every character an input stream's reader consumes (pl_getc_cp) is written to each, once per mirror however often it was added. gnu_builtins.pl checks
# as gprolog's stream.pl and stream_c.c (the stream argument unbound first, chars/codes in 1..255 as gprolog's Is_Valid_Code, stream-or-alias resolution).
#
# THE ARM: one program (no SWI marker), 51 lines, the reference cut from gprolog 1.6.0 through gprolog_output_filter (2026-10-15), mode 3 and mode 4;
# every stream is named by alias, since the numbers inside stream terms differ by system.
# FAIL-ONCE, measured on the parent (SCRIP 988c9d8a6 rebuilt): 51 of 51 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_term_streams_aliases_and_mirrors_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
chars(S, Cs) :- get_char(S, C), ( C == end_of_file -> Cs = [] ; Cs = [C|T], chars(S, T) ).
main :- open_input_atom_stream('hello world', A), add_stream_alias(A, ta), t((chars(ta, Cs), atom_chars(X, Cs))), t(close(ta)), t(close_input_atom_stream(ta)),
  open_input_chars_stream([a, b, c], B), add_stream_alias(B, tb), t(read_term(tb, _, [])), t(close_input_codes_stream(tb)),
  open_input_codes_stream([0'f, 0'(, 0'1, 0'), 0'.], C), add_stream_alias(C, tc), t(read(tc, _)), t(close_input_chars_stream(tc)),
  open_output_atom_stream(O1), add_stream_alias(O1, o1), write(o1, foo(bar)), t(close_output_atom_stream(o1, 'foo(baz)')), t(close_output_atom_stream(o1, _)),
  open_output_chars_stream(O2), add_stream_alias(O2, o2), write(o2, ab), t(close_output_chars_stream(o2, _)),
  open_output_codes_stream(O3), add_stream_alias(O3, o3), writeq(o3, 'x y'), t(close_output_codes_stream(o3, _)),
  open_output_atom_stream(O4), add_stream_alias(O4, o4), t(close_input_atom_stream(o4)), t(close_output_atom_stream(o4, [])), t(close_output_chars_stream(o4, x)),
  t(close_output_atom_stream(o4, _)),
  t(open_input_atom_stream(_, _)), t(open_input_atom_stream(a, b)), t(open_input_chars_stream([a|_], _)), t(open_input_chars_stream([ab], _)),
  t(open_input_codes_stream([0], _)), t(open_input_codes_stream([300], _)), t(open_input_codes_stream(x, _)), t(open_output_chars_stream(z)),
  t(close_input_atom_stream(_)), t(close_input_atom_stream(nosuch)), t(close_input_atom_stream(3)), t(close_input_atom_stream(user_input)),
  open('f1.txt', write, W1), write(W1, 'xyz\n'), close(W1), open('m1.txt', write, _, [alias(mo)]), open('f1.txt', read, _, [alias(fr), mirror(mo)]),
  t(\+ \+ (current_alias(S1, fr), current_alias(M1, mo), current_mirror(S1, M1))), t((get_char(fr, Q1), get_code(fr, Q2))), t(remove_stream_mirror(fr, mo)),
  t(get_char(fr, _)), t(add_stream_mirror(fr, mo)), t(add_stream_mirror(fr, mo)), t(get_char(fr, _)), close(fr), close(mo),
  open('m1.txt', read, _, [alias(mr)]), t(chars(mr, _)), close(mr),
  open('f1.txt', read, R2), add_stream_alias(R2, r2a), t(add_stream_alias(r2a, r2a)), t(add_stream_alias(r2a, r2b)), t(add_stream_alias(r2b, r2a)), t(add_stream_alias(r2a, user_input)),
  t(findall(Al, (current_alias(S2, Al), current_alias(S2, r2a)), _)), t(get_char(r2b, _)), t(\+ \+ (current_alias(S3, r2b), current_stream(S3))), close(R2),
  t(current_alias(_, r2b)), t(get_char(r2b, _)),
  t(current_stream(x)), t(current_alias(x, _)), t(current_mirror(_, 1)), t(add_stream_alias(_, a)), t(add_stream_alias(user_input, 3)),
  t(open('f1.txt', read, _, [mirror(nosuch)])), t(open('f1.txt', read, _, [mirror(user_input)])).
PL
want="$(cat <<'WANT'
chars(ta,A),atom_chars(B,A) => [(chars(ta,[h,e,l,l,o,' ',w,o,r,l,d]),atom_chars('hello world',[h,e,l,l,o,' ',w,o,r,l,d]))]
close(ta) => error(system_error('special stream: needs appropriate close predicate'))
close_input_atom_stream(ta) => [close_input_atom_stream(ta)]
read_term(tb,A,[]) => error(syntax_error('constant term stream:1 (char:4) . or operator expected after expression'))
close_input_codes_stream(tb) => [close_input_codes_stream(tb)]
read(tc,A) => [read(tc,f(1))]
close_input_chars_stream(tc) => [close_input_chars_stream(tc)]
close_output_atom_stream(o1,'foo(baz)') => []
close_output_atom_stream(o1,A) => [close_output_atom_stream(o1,'foo(bar)')]
close_output_chars_stream(o2,A) => [close_output_chars_stream(o2,[a,b])]
close_output_codes_stream(o3,A) => [close_output_codes_stream(o3,[39,120,32,121,39])]
close_input_atom_stream(o4) => error(permission_error(close,stream,o4))
close_output_atom_stream(o4,[]) => []
close_output_chars_stream(o4,x) => error(type_error(list,x))
close_output_atom_stream(o4,A) => [close_output_atom_stream(o4,'')]
open_input_atom_stream(A,B) => error(instantiation_error)
open_input_atom_stream(a,b) => error(uninstantiation_error(b))
open_input_chars_stream([a|A],B) => error(instantiation_error)
open_input_chars_stream([ab],A) => error(type_error(character,ab))
open_input_codes_stream([0],A) => error(representation_error(character_code))
open_input_codes_stream([300],A) => error(representation_error(character_code))
open_input_codes_stream(x,A) => error(type_error(list,x))
open_output_chars_stream(z) => error(uninstantiation_error(z))
close_input_atom_stream(A) => error(instantiation_error)
close_input_atom_stream(nosuch) => error(existence_error(stream,nosuch))
close_input_atom_stream(3) => error(domain_error(stream_or_alias,3))
close_input_atom_stream(user_input) => error(domain_error(term_stream_or_alias,user_input))
\+ \+ (current_alias(A,fr),current_alias(B,mo),current_mirror(A,B)) => [\+ \+ (current_alias(C,fr),current_alias(D,mo),current_mirror(C,D))]
get_char(fr,A),get_code(fr,B) => [(get_char(fr,x),get_code(fr,121))]
remove_stream_mirror(fr,mo) => [remove_stream_mirror(fr,mo)]
get_char(fr,A) => [get_char(fr,z)]
add_stream_mirror(fr,mo) => [add_stream_mirror(fr,mo)]
add_stream_mirror(fr,mo) => [add_stream_mirror(fr,mo)]
get_char(fr,A) => [get_char(fr,'\n')]
chars(mr,A) => [chars(mr,[x,y,'\n'])]
add_stream_alias(r2a,r2a) => [add_stream_alias(r2a,r2a)]
add_stream_alias(r2a,r2b) => [add_stream_alias(r2a,r2b)]
add_stream_alias(r2b,r2a) => [add_stream_alias(r2b,r2a)]
add_stream_alias(r2a,user_input) => error(permission_error(add_alias,source_sink,alias(user_input)))
findall(A,(current_alias(B,A),current_alias(B,r2a)),C) => [findall(D,(current_alias(E,D),current_alias(E,r2a)),[r2a,r2b])]
get_char(r2b,A) => [get_char(r2b,x)]
\+ \+ (current_alias(A,r2b),current_stream(A)) => [\+ \+ (current_alias(B,r2b),current_stream(B))]
current_alias(A,r2b) => []
get_char(r2b,A) => error(existence_error(stream,r2b))
current_stream(x) => error(domain_error(stream,x))
current_alias(x,A) => error(domain_error(stream,x))
current_mirror(A,1) => error(domain_error(stream,1))
add_stream_alias(A,a) => error(instantiation_error)
add_stream_alias(user_input,3) => error(type_error(atom,3))
open('f1.txt',read,A,[mirror(nosuch)]) => error(existence_error(stream,nosuch))
open('f1.txt',read,A,[mirror(user_input)]) => error(permission_error(output,stream,user_input))
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f f1.txt m1.txt && "$@" 2>/dev/null | grep .)"
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
