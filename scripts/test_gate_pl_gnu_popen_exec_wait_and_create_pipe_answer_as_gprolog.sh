#!/usr/bin/env bash
# test_gate_pl_gnu_popen_exec_wait_and_create_pipe_answer_as_gprolog.sh -- popen/3, exec/4,5, wait/2 AND create_pipe/2 EXIST AND ANSWER AS gprolog
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/os_interf_driver).
#
# GNU Prolog's process built-ins were absent from SCRIP (existence_error for popen/3, exec/5, create_pipe/2). gnu_builtins.pl now defines them over
# three new ops of the '$gnu_os'/3 leaf (by_name_dispatch.c): popen runs the command through popen(3) after fflush(NULL) and registers the FILE as a
# stream (read: the command's stdout; write: its stdin); exec makes three pipe2(O_CLOEXEC) pipes, forks, dup2s them onto the child's 0/1/2 and runs
# /bin/sh -c Command, and answers the three streams and the pid; wait/2 is waitpid and answers the exit status. create_pipe/2 is pipe/2. The argument
# checks are gprolog's: a variable command or mode instantiation_error, a non-atom type_error(atom), an unknown mode domain_error(io_mode), a non-integer
# pid type_error(integer).
#
# THE ARM: one program (no SWI marker), twelve lines, the reference cut from gprolog 1.4.5 (2026-10-15), mode 3 and mode 4: popen read and write,
# exec with stdin, stdout, stderr and an exit status of 3 and of 0, a create_pipe round trip, and the error terms.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP a5e3d2d5a): all 12 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_popen_exec_wait_and_create_pipe_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
all(S, Cs) :- get_char(S, C), ( C == end_of_file -> Cs = [] ; Cs = [C|R], all(S, R) ).
pr(Cmd, T) :- popen(Cmd, read, S), all(S, Cs), close(S), atom_chars(T, Cs).
pw(T) :- popen('cat > pw.txt', write, S), write(S, T), close(S), open('pw.txt', read, I), all(I, Cs), close(I), atom_chars(Back, Cs), write(Back), nl.
ex(Cmd, In, Out, Err, St) :- exec(Cmd, I, O, E, P), write(I, In), close(I), all(O, Oc), close(O), all(E, Ec), close(E), wait(P, St), atom_chars(Out, Oc), atom_chars(Err, Ec).
cp(T, B) :- create_pipe(R, W), write(W, T), close(W), all(R, Cs), close(R), atom_chars(B, Cs).
main :- t(pr('echo one; echo two', _)), pw(written_through_popen), t(ex('tr a-z A-Z; echo oops >&2; exit 3', hello, _, _, _)), t(ex('exit 0', '', _, _, _)), t(cp(piped, _)),
  t(popen(_, read, _)), t(popen(true, sideways, _)), t(popen(true, 3, _)), t(popen(3, read, _)), t(exec(_, _, _, _, _)), t(wait(_, _)), t(wait(x, _)).
PL
want="$(cat <<'WANT'
pr('echo one; echo two',A) => [pr('echo one; echo two','one\ntwo\n')]
written_through_popen
ex('tr a-z A-Z; echo oops >&2; exit 3',hello,A,B,C) => [ex('tr a-z A-Z; echo oops >&2; exit 3',hello,'HELLO','oops\n',3)]
ex('exit 0','',A,B,C) => [ex('exit 0','','','',0)]
cp(piped,A) => [cp(piped,piped)]
popen(A,read,B) => error(instantiation_error)
popen(true,sideways,A) => error(domain_error(io_mode,sideways))
popen(true,3,A) => error(type_error(atom,3))
popen(3,read,A) => error(type_error(atom,3))
exec(A,B,C,D,E) => error(instantiation_error)
wait(A,B) => error(instantiation_error)
wait(x,A) => error(type_error(integer,x))
WANT
)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f pw.txt && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 12 of 12 lines as gprolog"
    else echo "  $label RED: $n of 12 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
