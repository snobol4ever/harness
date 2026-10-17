#!/usr/bin/env bash
# test_gate_pl_a_list_goal_consults_its_files_directly_and_through_call.sh -- A LIST GOAL [File|Files] CONSULTS ITS FILES, WRITTEN IN A BODY, IN A DIRECTIVE OR CALLED
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/consult_driver, its last two lines).
#
# gprolog and swipl both run a list goal as consult/1 of its elements (consult.pl: [File|Files] :- consult([File|Files])). SCRIP's lowerer already turned a
# list written in goal position into consult/1 calls, but consult/1 was linked only when the program's text named it, so ['f.pl'] alone died with
# existence_error(procedure, consult/1); and a list reached through call/1 (or findall, catch, ...) was resolved by name as './2' and died with
# existence_error(procedure, '.'/2). Now prolog_inject_prelude links consult/1 when a clause body or directive holds a list goal (through , ; -> *-> \+
# and the goal arguments of call, once, ignore, not, forall, catch, findall, bagof and setof), and the meta-call's rt_pl_goal_key resolves a list cell
# called with no extra arguments as consult/1 of that list. A program whose only list goal is data handed to call/1 still does not link consult/1 and
# says existence_error(procedure, consult/1) -- an honest refusal, not a wrong answer.
#
# THE ARMS: two programs, each in mode 3 and mode 4 -- g.pl (no SWI marker, the reference cut from gprolog 1.4.5, five lines; it reconsults, which the GNU
# dialect replaces) and s.pl (an SWI marker, the reference cut from swipl 9.0.4, three lines; no reconsult, since SCRIP's SWI consult still appends).
# Both cut 2026-10-15; each writes its small source files into its scratch dir.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP def8a2529): g.pl 5 of 5 lines differ and s.pl 3 of 3, in both modes.
# rc=0 every arm agrees with its oracle · rc=1 a divergence · rc=2 REFUSAL (no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_list_goal_consults_its_files_directly_and_through_call
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
T="t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \\+ \\+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl )."
cat > "$D/g.pl" <<PL
:- initialization(main).
$T
main :- open('lq.pl', write, S), write(S, 'lq(7).'), nl(S), close(S), ['lq.pl'], lq(X), write(X), nl,
  t((['lq.pl'], lq(_))), t([lq]), t([nosuch]), G = ['lq.pl'], t((call(G), lq(_))).
PL
cat > "$D/s.pl" <<PL
:- use_module(library(lists)).
:- initialization(main).
$T
main :- open('lq.pl', write, S), write(S, 'lq(7).'), nl(S), close(S), open('lr.pl', write, S2), write(S2, 'lr(8).'), nl(S2), close(S2),
  ['lq.pl'], lq(X), write(X), nl, G = ['lr.pl'], t((call(G), lr(_))), t([nosuch]).
PL
want_g="$(cat <<'WANT'
7
['lq.pl'],lq(A) => [(['lq.pl'],lq(7))]
[lq] => [[lq]]
[nosuch] => error(existence_error(source_sink,'nosuch.pl'))
call(['lq.pl']),lq(A) => [(call(['lq.pl']),lq(7))]
WANT
)"
want_s="$(cat <<'WANT'
7
call(['lr.pl']),lr(A) => [(call(['lr.pl']),lr(8))]
[nosuch] => error(existence_error(source_sink,nosuch))
WANT
)"
red=0
arm() {
    local label="$1" want="$2" oracle="$3"; shift 3
    local got n t
    got="$(cd "$D" && rm -f lq.pl lr.pl && "$@" 2>/dev/null | grep .)"
    t="$(printf '%s\n' "$want" | grep -c .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $t of $t lines as $oracle"
    else echo "  $label RED: $n of $t $oracle lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
for p in g s; do
    if [ "$p" = g ]; then w="$want_g"; o=gprolog; else w="$want_s"; o=swipl; fi
    arm "$p.pl m3" "$w" "$o" timeout -k 5 20 "$B/scrip" --run $([ "$p" = g ] && printf %s --dialect=gnu) "$p.pl" < /dev/null
    if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile $([ "$p" = g ] && printf %s --dialect=gnu) -o "$p.s" "$p.pl" < /dev/null > /dev/null 2>&1 && [ -s "$p.s" ] \
         && gcc -m64 -no-pie "$p.s" -o "$p.bin" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
        arm "$p.pl m4" "$w" "$o" timeout -k 5 20 "./$p.bin" < /dev/null
    else echo "  $p.pl m4 RED: the program did not compile or link in mode 4"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
