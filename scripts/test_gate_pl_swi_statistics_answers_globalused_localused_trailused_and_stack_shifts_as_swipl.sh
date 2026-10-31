#!/usr/bin/env bash
# test_gate_pl_swi_statistics_answers_globalused_localused_trailused_and_stack_shifts_as_swipl.sh -- statistics/2 KEYS SWI'S GC TESTS READ (hq_icon 2026-10-31, row prolog-swi-to-100-the-failing-cases-ceo-1930, SWI core/test_gc gc_leak).
# THE FEATURE: statistics(globalused|localused|trailused, Bytes) -- the used element of SCRIP's global_stack, local_stack and trail_stack, the figure swipl's own keys report -- and statistics(stack_shifts, [0,0,0]), which is
# TRUE of SCRIP, whose stacks are mmap'd regions that never shift (src/parsers/prolog/prolog_parse.c, the statistics/2 prelude beside global_shifts); under the GNU dialect the keys stay a domain_error as gprolog answers them.
# THE WITNESS: 13 labelled lines -- each key is an integer (or a list of three), an unbound key is an instantiation_error, an unknown key a domain_error(statistics_key), and the two SHAPES of SWI's core/test_gc that
# read them: a deterministic freeze/bind loop of 1000 rounds grows the trail by less than 100 bytes (det_freeze_no_space), and 10000 throw/catch rounds change no stack_shifts count (throw_gc).  Values are not compared (they are
# the engines' own); the verdicts are, as `label => true|false|the error's formal`.  swipl 9.0.4 cuts the want in this run.
# ARMS: the oracle answers the whole witness (its last line is present; an oracle that cannot REFUSES rc 2), then mode 3 and mode 4 each equal it line for line.
# RED BEFORE (measured 2026-10-31 on the tree before the cure): core/test_gc gc_leak det_freeze_no_space and throw_gc read "domain_error(statistics_key,trailused)" and "true check failed" in both modes; every key line here is that error.
# FAIL-ONCE: shown red against the oracle's different answer (a scratch copy of this gate whose scrip run is given a different label for one line).
# NOT COVERED, KNOWN: core/test_gc gc_leak early_reset -- after length(X, 10) on a dead argument, swipl's collector resets the trail entry of the unreachable variable and reclaims the list ("early reset"); SCRIP's keeps both
# (measured Used 32+480 bytes after one garbage_collect), a collector change that is hq_collector's, named to it by bus.
# rc 0 both modes agree with swipl - rc 1 a divergence - rc 2 REFUSAL (no swipl, no build).  ~5 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_statistics_answers_globalused_localused_trailused_and_stack_shifts_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
k(L, G) :- catch(( call(G) -> R = true ; R = false ), error(E, _), ( E = domain_error(K, _) -> R = domain_error(K) ; R = E )), format("~w => ~w~n", [L, R]).
det_freeze_loop(N, T) :- ( succ(N2, N) -> freeze(X, true), X = a, det_freeze_loop(N2, T) ; garbage_collect, statistics(trailused, T) ).
main :-
    k(globalused_int, ( statistics(globalused, G), integer(G), G > 0 )),
    k(localused_int, ( statistics(localused, L), integer(L), L >= 0 )),
    k(trailused_int, ( statistics(trailused, T), integer(T), T >= 0 )),
    k(stack_shifts_three, ( statistics(stack_shifts, [A, B, C]), integer(A), integer(B), integer(C) )),
    k(globalused_grows, ( garbage_collect, statistics(globalused, G0), length(Big, 5000), statistics(globalused, G1), G1 > G0, Big = [] )),
    k(globalused_after_gc_shrinks, ( length(Big2, 20000), Big2 = [_|_], garbage_collect, statistics(globalused, G2), garbage_collect, statistics(globalused, G3), G3 =< G2 )),
    k(unbound_key, statistics(_, _)),
    k(unknown_key, statistics(nokey_zz, _)),
    k(det_freeze_no_space, ( garbage_collect, statistics(trailused, T0), det_freeze_loop(1000, T1), TD is T1 - T0, TD < 100 )),
    k(throw_gc, ( statistics(stack_shifts, [S0, _, _]), ( between(1, 10000, _), catch(throw(foo), _, true), fail ; true ), statistics(stack_shifts, [S1, _, _]), S0 == S1 )),
    k(runtime_still_pair, ( statistics(runtime, [R1, R2]), integer(R1), integer(R2) )),
    k(global_stack_still_pair, ( statistics(global_stack, [U, F]), integer(U), integer(F) )),
    k(cputime_still_number, ( statistics(cputime, CT), number(CT) )).
PL
( cd "$D" && timeout -k 5 60 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
[ "$(wc -l < "$D/want")" -ge 13 ] || refuse "swipl answered fewer than 13 lines -- the witness did not run to its end: $(tail -1 "$D/want")"
( cd "$D" && timeout -k 5 120 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err )
( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out=w.s w.pl < /dev/null 2> m4.err && gcc w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 120 ./w < /dev/null > m4 2>> m4.err )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
