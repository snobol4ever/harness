#!/usr/bin/env bash
# test_gate_pl_gnu_sockets_answer_as_gprolog.sh -- GNU Prolog's SOCKET built-ins socket/2, socket_close/1, socket_bind/2, socket_listen/2, socket_accept/3,4,
# socket_connect/4 AND hostname_address/2 EXIST AND ANSWER AS gprolog (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks:
# BipsPl/sockets_driver).
#
# The seven were absent from SCRIP. They are '$gnu_os' ops in by_name_dispatch.c (pl_gs_sock: socket(2) with SO_REUSEADDR as gprolog sets it, close, bind on
# an AF_UNIX path after unlinking it or on AF_INET with INADDR_ANY and the assigned port read back by getsockname, listen, accept and connect answering a read
# stream and a write stream over the descriptor and its dup, the client's dotted address, getaddrinfo for a host) under gnu_builtins.pl wrappers that check
# as gprolog's sockets.pl and sockets_c.c: the stream arguments unbound first (uninstantiation_error), the socket an integer, the domain AF_UNIX or AF_INET
# (domain_error(socket_domain, D)), the address AF_UNIX(Path) or AF_INET(Host, Port) (domain_error(socket_address, A)), an unbound AF_INET host bound to the
# local host name and an unbound port to the port the system chose; an OS error is system_error(Message); an unknown host fails.
#
# THE ARM: one program (no SWI marker), 22 lines, the reference cut from gprolog 1.6.0 through gprolog_output_filter (2026-10-15), mode 3 and mode 4: an
# AF_INET round trip on the loopback through an assigned port, an AF_UNIX round trip, and the argument and OS errors. Needs only the loopback interface.
# FAIL-ONCE, measured on the parent (SCRIP cad183d7b rebuilt): 22 of 22 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_sockets_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
p(N, G) :- catch(( G -> R = true ; R = false ), E, ( E = error(F, _) -> R = error(F) ; R = ball(E) )), write(N), write(' => '), writeq(R), nl.
line(S, A) :- get_char(S, C), line(C, S, Cs), atom_chars(A, Cs).
line(end_of_file, _, []) :- !.
line('\n', _, []) :- !.
line(C, S, [C|Cs]) :- get_char(S, C1), line(C1, S, Cs).
inet(Up, Down, Who) :- socket('AF_INET', Srv), socket_bind(Srv, 'AF_INET'(_, P)), socket_listen(Srv, 2),
  socket('AF_INET', Cli), socket_connect(Cli, 'AF_INET'(localhost, P), CIn, COut), socket_accept(Srv, Who, SIn, SOut),
  write(COut, up_inet), nl(COut), flush_output(COut), line(SIn, Up), write(SOut, down_inet), nl(SOut), flush_output(SOut), line(CIn, Down),
  close(COut), close(CIn), close(SOut), close(SIn), socket_close(Srv).
unix(Up) :- Path = 'skt_w.sock', socket('AF_UNIX', Srv), socket_bind(Srv, 'AF_UNIX'(Path)), socket_listen(Srv, 1), socket('AF_UNIX', Cli),
  socket_connect(Cli, 'AF_UNIX'(Path), _, COut), socket_accept(Srv, SIn, _), write(COut, 'hello unix'), nl(COut), flush_output(COut), line(SIn, Up),
  close(COut), close(SIn), socket_close(Srv).
main :- t(inet(_, _, _)), t(unix(_)), t(socket(1, _)), t(socket('AF_INET', x)), t(socket_close(1)), t(socket_close(-4)),
  p(bind_type_errors, ( socket('AF_INET', S1), catch(socket_bind(S1, 'AF_INET'(3, _)), error(E1, _), true), catch(socket_bind(S1, 'AF_INET'(_, x)), error(E2, _), true),
    catch(socket_bind(S1, 'AF_UNIX'(9)), error(E3, _), true), catch(socket_bind(S1, f(a, b, c)), error(E4, _), true), socket_close(S1), write([E1, E2, E3, E4]), nl )),
  t(socket_bind(x, 'AF_UNIX'(a))), t(socket_listen(1, a)), t(socket_listen(a, 1)), t(socket_accept(_, _, _)), t(socket_accept(3, a, _)), t(socket_accept(3, _, b, _)),
  t(socket_connect(_, 'AF_UNIX'(a), _, _)), t(socket_connect(3, _, _, _)), t(socket_connect(3, nonsense, _, _)), t(socket_connect(3, 'AF_UNIX'(a), x, _)),
  t(hostname_address(localhost, '127.0.0.1')), t(hostname_address(localhost, x)), t(hostname_address(localhost, 12)), t(hostname_address('no-such-host.invalid', _)).
PL
want="$(cat <<'WANT'
inet(A,B,C) => [inet(up_inet,down_inet,'127.0.0.1')]
unix(A) => [unix('hello unix')]
socket(1,A) => error(type_error(atom,1))
socket('AF_INET',x) => error(uninstantiation_error(x))
socket_close(1) => error(system_error('Bad file descriptor'))
socket_close(-4) => error(system_error('Bad file descriptor'))
[type_error(atom,3),type_error(integer,x),type_error(atom,9),domain_error(socket_address,f(a,b,c))]
bind_type_errors => true
socket_bind(x,'AF_UNIX'(a)) => error(type_error(integer,x))
socket_listen(1,a) => error(type_error(integer,a))
socket_listen(a,1) => error(type_error(integer,a))
socket_accept(A,B,C) => error(instantiation_error)
socket_accept(3,a,A) => error(uninstantiation_error(a))
socket_accept(3,A,b,B) => error(uninstantiation_error(b))
socket_connect(A,'AF_UNIX'(a),B,C) => error(instantiation_error)
socket_connect(3,A,B,C) => error(instantiation_error)
socket_connect(3,nonsense,A,B) => error(domain_error(socket_address,nonsense))
socket_connect(3,'AF_UNIX'(a),x,A) => error(uninstantiation_error(x))
hostname_address(localhost,'127.0.0.1') => [hostname_address(localhost,'127.0.0.1')]
hostname_address(localhost,x) => []
hostname_address(localhost,12) => error(type_error(atom,12))
hostname_address('no-such-host.invalid',A) => []
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f skt_w.sock && "$@" 2>/dev/null | grep .)"
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
