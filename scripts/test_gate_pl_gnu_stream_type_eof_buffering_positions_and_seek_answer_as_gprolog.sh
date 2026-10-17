#!/usr/bin/env bash
# test_gate_pl_gnu_stream_type_eof_buffering_positions_and_seek_answer_as_gprolog.sh -- GNU Prolog's set_stream_type/2, set_stream_eof_action/2,
# set_stream_buffering/2 AND THE buffering PROPERTY AND OPTION, stream_position/2, stream_line_column/3, set_stream_line_column/3 AND seek/4 ANSWER AS
# gprolog (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/stream_driver, its second half).
#
# gnu_builtins.pl writes them as gprolog's stream.pl / stream_c.c, over '$gnu_os' ts_* ops: set_stream_type refuses a stream that has done I/O
# (permission_error(modify, stream)); set_stream_eof_action refuses an output stream; set_stream_buffering and open/4 buffering(none|line|block) outside the
# SWI dialect store the mode in a new slot field (fh_slot_t.buf), which stream_property(S, buffering(B)) answers when asked by name (an SWI-style
# enumeration of a stream's properties is unchanged); stream_position/2 answers gprolog's '$stream_position'(Offset, Chars, Line, LinePos), which
# set_stream_position/2 now also accepts outside the SWI dialect; stream_line_column/3 and set_stream_line_column/3 count lines and columns from 1, the
# setter re-reading from the start as gprolog does and failing past a line's end; seek/4 takes gprolog's order (Whence, Offset) on a binary stream and
# swipl's (Offset, Method) in the SWI dialect or for a call shaped that way. at_end_of_stream/0,1 no longer leaves the end-of-file flag its probe set,
# so stream_property end_of_stream reads at, not past (both oracles). Lines where swipl and gprolog differ on a predicate both define (line_count's
# base, character_count's type check, stream_property's alias argument, eof_action(reset) at the end) are not in this witness: CEO-1536 takes SWI.
#
# THE ARM: one program (no SWI marker), 52 lines, the reference cut from gprolog 1.6.0 through gprolog_output_filter (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent (SCRIP c4b036bd9 rebuilt): 52 of 52 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_stream_type_eof_buffering_positions_and_seek_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
sp(A, P) :- current_alias(S, A), stream_property(S, P).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
main :- open('a.txt', write, W), write(W, 'abcd\nxy\nz\n'), close(W), open('b.bin', write, WB, [type(binary)]), put_byte(WB, 1), put_byte(WB, 2), put_byte(WB, 3), put_byte(WB, 4), close(WB),
  open('a.txt', read, _, [alias(r)]), open('a.txt', read, _, [alias(t)]), open('b.bin', read, _, [type(binary), alias(b)]), open('o.txt', write, _, [alias(w), buffering(none)]),
  open('a.txt', read, _, [alias(np), reposition(false), eof_action(error)]),
  t(sp(r, buffering(_))), t(sp(w, buffering(_))), t(set_stream_buffering(w, line)), t(sp(w, buffering(_))), t(set_stream_buffering(w, x)), t(set_stream_buffering(w, _)),
  t(set_stream_type(t, binary)), t(sp(t, type(_))), t(set_stream_type(t, text)), t(set_stream_type(t, foo)), t(set_stream_type(t, _)), t(get_char(r, _)), t(set_stream_type(r, binary)), t(set_stream_type(r, text)),
  t(set_stream_eof_action(w, error)), t(set_stream_eof_action(r, x)), t(set_stream_eof_action(r, _)), t(set_stream_eof_action(nosuch, error)),
  t(stream_line_column(r, _, _)), t(set_stream_line_column(r, 2, 2)), t(stream_line_column(r, _, _)), t(get_char(r, _)), t(set_stream_line_column(r, 3, 5)), t(stream_line_column(r, _, _)),
  t(set_stream_line_column(r, 0, 1)), t(set_stream_line_column(r, a, 1)), t(set_stream_line_column(np, 1, 1)), t(set_stream_line_column(b, 1, 1)), t(stream_line_column(b, _, _)), t(stream_line_column(r, x, _)),
  t((stream_position(r, P), get_char(r, C1), set_stream_position(r, P), get_char(r, C2))), t((stream_position(r, P2), P2 = '$stream_position'(_, _, _, _))), t(stream_position(r, foo)), t(stream_position(r, '$stream_position'(a, 1, 1, 1))),
  t((stream_position(np, P3), set_stream_position(np, P3))),
  t(seek(b, bof, 2, _)), t((seek(b, current, 1, N1), get_byte(b, Y1))), t(seek(b, eof, -1, _)), t(seek(b, bof, 1, 2)), t(seek(b, middle, 0, _)), t(seek(b, 1, 0, _)), t(seek(b, bof, a, _)), t(seek(r, bof, 0, _)),
  t(seek(np, bof, 0, _)), t(seek(b, bof, 0, x)),
  t(set_stream_eof_action(r, error)), set_stream_line_column(r, 3, 1), t((get_char(r, Z1), get_char(r, Z2))), t(at_end_of_stream(r)), t(sp(r, end_of_stream(_))), t(get_char(r, _)), t(get_char(r, _)),
  t(open('a.txt', read, _, [buffering(huge)])).
PL
want="$(cat <<'WANT'
sp(r,buffering(A)) => [sp(r,buffering(block))]
sp(w,buffering(A)) => [sp(w,buffering(none))]
set_stream_buffering(w,line) => [set_stream_buffering(w,line)]
sp(w,buffering(A)) => [sp(w,buffering(line))]
set_stream_buffering(w,x) => error(domain_error(buffering_mode,x))
set_stream_buffering(w,A) => error(instantiation_error)
set_stream_type(t,binary) => [set_stream_type(t,binary)]
sp(t,type(A)) => [sp(t,type(binary))]
set_stream_type(t,text) => [set_stream_type(t,text)]
set_stream_type(t,foo) => error(domain_error(stream_type,foo))
set_stream_type(t,A) => error(instantiation_error)
get_char(r,A) => [get_char(r,a)]
set_stream_type(r,binary) => error(permission_error(modify,stream,r))
set_stream_type(r,text) => [set_stream_type(r,text)]
set_stream_eof_action(w,error) => error(permission_error(modify,stream,w))
set_stream_eof_action(r,x) => error(domain_error(eof_action,x))
set_stream_eof_action(r,A) => error(instantiation_error)
set_stream_eof_action(nosuch,error) => error(existence_error(stream,nosuch))
stream_line_column(r,A,B) => [stream_line_column(r,1,2)]
set_stream_line_column(r,2,2) => [set_stream_line_column(r,2,2)]
stream_line_column(r,A,B) => [stream_line_column(r,2,2)]
get_char(r,A) => [get_char(r,y)]
set_stream_line_column(r,3,5) => []
stream_line_column(r,A,B) => [stream_line_column(r,2,3)]
set_stream_line_column(r,0,1) => []
set_stream_line_column(r,a,1) => error(type_error(integer,a))
set_stream_line_column(np,1,1) => error(permission_error(reposition,stream,np))
set_stream_line_column(b,1,1) => error(permission_error(reposition,binary_stream,b))
stream_line_column(b,A,B) => error(permission_error(access,binary_stream,b))
stream_line_column(r,x,A) => error(type_error(integer,x))
stream_position(r,A),get_char(r,B),set_stream_position(r,A),get_char(r,C) => [(stream_position(r,'$stream_position'(7,7,1,2)),get_char(r,'\n'),set_stream_position(r,'$stream_position'(7,7,1,2)),get_char(r,'\n'))]
stream_position(r,A),A='$stream_position'(B,C,D,E) => [(stream_position(r,'$stream_position'(8,8,2,0)),'$stream_position'(8,8,2,0)='$stream_position'(8,8,2,0))]
stream_position(r,foo) => error(domain_error(stream_position,foo))
stream_position(r,'$stream_position'(a,1,1,1)) => error(domain_error(stream_position,'$stream_position'(a,1,1,1)))
stream_position(np,A),set_stream_position(np,A) => error(permission_error(reposition,stream,np))
seek(b,bof,2,A) => [seek(b,bof,2,2)]
seek(b,current,1,A),get_byte(b,B) => [(seek(b,current,1,3),get_byte(b,4))]
seek(b,eof,-1,A) => [seek(b,eof,-1,3)]
seek(b,bof,1,2) => []
seek(b,middle,0,A) => error(domain_error(stream_seek_method,middle))
seek(b,1,0,A) => error(type_error(atom,1))
seek(b,bof,a,A) => error(type_error(integer,a))
seek(r,bof,0,A) => error(permission_error(reposition,text_stream,r))
seek(np,bof,0,A) => error(permission_error(reposition,stream,np))
seek(b,bof,0,x) => error(type_error(integer,x))
set_stream_eof_action(r,error) => [set_stream_eof_action(r,error)]
get_char(r,A),get_char(r,B) => [(get_char(r,z),get_char(r,'\n'))]
at_end_of_stream(r) => [at_end_of_stream(r)]
sp(r,end_of_stream(A)) => [sp(r,end_of_stream(at))]
get_char(r,A) => [get_char(r,end_of_file)]
get_char(r,A) => error(permission_error(input,past_end_of_stream,r))
open('a.txt',read,A,[buffering(huge)]) => error(domain_error(stream_option,buffering(huge)))
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f a.txt b.bin o.txt && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $n_want of $n_want lines as gprolog"
    else echo "  $label RED: $n of $n_want gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -20 | sed 's/^/    /'; red=1; fi
}
arm m3 timeout 20 "$B/scrip" --run --dialect=gnu g.pl < /dev/null
if ( cd "$D" && timeout 60 "$B/scrip" --compile --dialect=gnu -o g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
