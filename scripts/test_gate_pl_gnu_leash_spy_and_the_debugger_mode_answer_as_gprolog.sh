#!/usr/bin/env bash
# test_gate_pl_gnu_leash_spy_and_the_debugger_mode_answer_as_gprolog.sh -- GNU Prolog's DEBUGGER STATE BUILT-INS leash/1, spy/1, nospy/1, nospyall/0,
# spypoint_condition/3 AND debugging/0 ANSWER AS gprolog, MESSAGE FOR MESSAGE (cfo 2026-10-15, row
# prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/debugger_driver).
#
# gnu_builtins.pl writes them as gprolog's debugger.pl does, its state in hidden nb variables and the debug flag: leash/1 (full, half, loose, tight,
# none or a port list, the mask shown in port order, domain_error(leash_ports, L)); spy/1 and nospy/1 over a name, N/A, N/A1-A2 or a list, matching the
# program's predicates in gprolog's order (its table walk prepends, so the order is the reverse of definition, read here from prolog_line), the placed /
# already / removed / no-spypoint messages and the "no matching predicate" warning (N/any for a bare name); spy switches the debugger on when it is
# off; the predicate-indicator errors; spypoint_condition/3; nospyall/0; debugging/0 (mode, leashing, the unknown flag, the spypoints). Outside the SWI
# dialect nodebug/0 resets the leash to full, as gprolog's $debug_switch_off does. debug/0, nodebug/0 and notrace/0 print NOTHING in every dialect:
# both systems define them, swipl prints nothing and gprolog prints its mode line, and CEO-1536 takes SWI in a GNU/SWI conflict -- so the two mode lines
# leave this comparison as they leave the board's (gnu_prolog EXCLUDED_LINES.tsv, BipsPl/debugger.pl). The witness turns the debugger off after each
# call that can switch it on (r/1), because gprolog 1.6.0 itself raises existence_error('$get_cut_level'/1) in a consulted if-then-else once its
# debugger is on (see BipsPl/debugger_driver.pl).
#
# THE ARM: one program (no SWI marker), 89 lines after the two excluded mode lines, the reference cut from gprolog 1.6.0 through gprolog_output_filter
# (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent (SCRIP fb39ba0f7 rebuilt): 88 of 89 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_leash_spy_and_the_debugger_mode_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
r(G) :- catch(G, E, true), nodebug, r2(G, E).
r2(G, E) :- var(E), !, \+ \+ ( numbervars(G, 0, _), writeq(G), write(' => true'), nl ).
r2(G, error(F, _)) :- !, \+ \+ ( numbervars(G-F, 0, _), writeq(G), write(' => '), writeq(error(F)), nl ).
r2(G, B) :- \+ \+ ( numbervars(G-B, 0, _), writeq(G), write(' => '), writeq(ball(B)), nl ).
d_foo(1).
d_foo(_, _).
d_bar(_, _).
dz(_, _, _).
dz.
dz(_, _).
dz(_).
qa(_).
qb(_).
qc(_).
main :- t(leash([exception, call])), t(debugging), t(leash(half)), r(spy(d_foo/0-3)), t(debugging), r(spy([d_foo/1, d_bar/2])), r(spy(nonesuch)), r(spy(nonesuch/1-2)),
  r(spy(d_bar/9)), r(nospy(d_bar)), r(nospy([d_foo/2, nonesuch/1])), t(debugging), r(spypoint_condition(nonesuch(_), call, true)), t(spypoint_condition(3, call, true)),
  t(spy(d_foo/(-1))), t(spy(3/1)), t(spy(_/1)), t(spy(d_foo/_)), t(spy(d_foo/_-2)), set_prolog_flag(unknown, fail), t(debugging), set_prolog_flag(unknown, warning), t(debugging),
  set_prolog_flag(unknown, error), r(nospyall), r(nospyall), t(debugging), r(debug), r(notrace), t(leash(_)), t(leash([call|bogus])),
  r(spy(dz)), r(spy([qc/1, qa/1, qb/1])), t(debugging), r(spy(dz/1-2)).
PL
want="$(cat <<'WANT'
Using leashing stopping at [call,exception] ports
leash([exception,call]) => [leash([exception,call])]
Using leashing stopping at [call,exception] ports
Undefined predicates will raise an existence_error
Spypoints:
debugging => [debugging]
Using leashing stopping at [call,redo] ports
leash(half) => [leash(half)]
Spypoint placed on d_foo/2
Spypoint placed on d_foo/1
spy(d_foo/0-3) => true
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will raise an existence_error
Spypoints:
   d_foo/2
   d_foo/1
debugging => [debugging]
There is already a spypoint on d_foo/1
Spypoint placed on d_bar/2
spy([d_foo/1,d_bar/2]) => true
Warning: spy nonesuch/any - no matching predicate
spy(nonesuch) => true
Warning: spy nonesuch/1-2 - no matching predicate
spy(nonesuch/1-2) => true
Warning: spy d_bar/9 - no matching predicate
spy(d_bar/9) => true
Spypoint removed from d_bar/2
nospy(d_bar) => true
Warning: spy nonesuch/1 - no matching predicate
Spypoint removed from d_foo/2
nospy([d_foo/2,nonesuch/1]) => true
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will raise an existence_error
Spypoints:
   d_foo/1
debugging => [debugging]
Warning: The predicate nonesuch/1 is undefined
spypoint_condition(nonesuch(A),call,true) => true
spypoint_condition(3,call,true) => error(type_error(callable,3))
spy(d_foo/ -1) => error(domain_error(not_less_than_zero,-1))
spy(3/1) => error(type_error(atom,3))
spy(A/1) => error(instantiation_error)
spy(d_foo/A) => error(instantiation_error)
spy(d_foo/A-2) => error(instantiation_error)
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will fail
Spypoints:
   d_foo/1
debugging => [debugging]
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will display a warning message and fail
Spypoints:
   d_foo/1
debugging => [debugging]
All spypoints removed
nospyall => true
All spypoints removed
nospyall => true
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will raise an existence_error
Spypoints:
debugging => [debugging]
debug => true
notrace => true
leash(A) => error(instantiation_error)
leash([call|bogus]) => error(domain_error(leash_ports,[call|bogus]))
Spypoint placed on dz/1
Spypoint placed on dz/2
Spypoint placed on dz/0
Spypoint placed on dz/3
spy(dz) => true
Spypoint placed on qc/1
Spypoint placed on qa/1
Spypoint placed on qb/1
spy([qc/1,qa/1,qb/1]) => true
Using leashing stopping at [call,exit,redo,fail,exception] ports
Undefined predicates will raise an existence_error
Spypoints:
   dz/1
   dz/2
   dz/0
   dz/3
   qc/1
   qa/1
   qb/1
debugging => [debugging]
There is already a spypoint on dz/1
There is already a spypoint on dz/2
spy(dz/1-2) => true
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep . | grep -v -e '^The debugger is switched off' -e '^The debugger will first leap -- showing spypoints (debug)')"
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
