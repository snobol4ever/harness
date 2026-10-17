#!/usr/bin/env bash
# test_gate_pl_gnu_statistics_stacks_and_format_errors_answer_as_gprolog.sh -- statistics/2 ANSWERS THE FOUR STACK KEYS, AND format/2,3 IN THE GNU DIALECT REPORTS ITS ERRORS AS gprolog 1.6.0 DOES
# (cfo 2026-10-14, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/stat_driver and
# BipsPl/format_driver).
#
# statistics(local_stack | global_stack | trail_stack | cstr_stack, [Used, Free]) raised domain_error(statistics_key, K); they now answer from the
# real measures ('$gnu_os'(stack_used | stack_free, K, N): the machine stack against RLIMIT_STACK, the GC heap's bytes in use and free, the offset
# of the trail top inside its arena, and an empty constraint stack).
# format/2,3 outside the SWI dialect (rt_pl_dialect_swi false) now reports what gprolog reports: an exhausted argument list is
# domain_error(non_empty_list, []) where it said format_arguments, a directive character format does not know is
# domain_error(format_control_sequence, Char) (a dangling tilde: the empty atom) where it was silently dropped, ~c of a non-code is
# representation_error(character_code), and the text produced BEFORE the error stays written (gprolog writes as it goes). The SWI dialect is
# untouched.
#
# THE ARM: one program, eleven lines, the reference cut from the pristine gprolog 1.6.0 (2026-10-14) and written out here, mode 3 and mode 4.
# FAIL-ONCE, measured on the parent rebuilt: 10 of 11 lines differ in both modes; with the cure 11 of 11 as gprolog in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_statistics_stacks_and_format_errors_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
t(G) :- catch((G -> R = ok ; R = no), error(E, _), R = err(E)), writeq(R), nl.
o(G) :- write('<'), catch(( G -> R = true ; R = fail ), error(F, _), R = error(F)), write('> '), writeq(R), nl.
:- initialization(main).
main :- t(\+ \+ (statistics(local_stack, [A, B]), integer(A), integer(B), A >= 0, B >= 0)),
  t(\+ \+ (statistics(global_stack, [A, B]), integer(A), integer(B), A >= 0, B >= 0)),
  t(\+ \+ (statistics(trail_stack, [A, B]), integer(A), integer(B), A >= 0, B >= 0)),
  t(\+ \+ (statistics(cstr_stack, [A, B]), integer(A), integer(B), A >= 0, B >= 0)),
  o(format('~a', [])), o(format('x~a ~a', [y])), o(format('~y', [x])), o(format('ab~y', [x])), o(format('~c', [-1])),
  o(format('~a', [1])), o(format('p~w~', [x])).
PL
want="$(cat <<'WANT'
ok
ok
ok
ok
<> error(domain_error(non_empty_list,[]))
<xy > error(domain_error(non_empty_list,[]))
<> error(domain_error(format_control_sequence,y))
<ab> error(domain_error(format_control_sequence,y))
<> error(representation_error(character_code))
<> error(type_error(atom,1))
<px> error(domain_error(format_control_sequence,''))
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu -o w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 11 of 11 lines as gprolog"
    else echo "  $label RED: $n of 11 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
