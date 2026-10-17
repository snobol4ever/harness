#!/usr/bin/env bash
# test_gate_pl_asserting_a_conjunction_of_sixty_thousand_goals_does_not_overflow_the_default_stack_answers_as_swipl.sh -- A RUN-TIME CLAUSE WHOSE BODY IS A SIXTY-THOUSAND-GOAL CONJUNCTION ASSERTS INSIDE THE DEFAULT 4 MB STACK, IN BOTH MODES
# (hq_prolog 2026-10-15, row prolog-asserting-a-long-conjunction-or-a-deep-term-overflows-three-stages-and-the-frame-layout-is-superquadratic-swi-test-db-big-clause,
# CEO-1784; SWI db/test_db.pl res_compiler:big_clause asserts a 60000-goal clause).
# THE CURE (stages 1 and 2 of the row, the runtime's and the lowerer's, the ceo's split): every pass that walked a right-nested conjunction by recursion now iterates
# down the last child -- pl_cell_tree (the clause-to-tree reader; its variable lookup is a hash instead of a linear scan), pl_db_body_ill_typed, and in the lowerer
# pl_flatten_conj, pl_rewrite_control, pb_expand_goal, tr_assign_slots (whose slot map hashes names past 24) and collect_conj -- so the C stack no longer grows with the goal
# count.  The body is sixty thousand `true` goals (lowering drops them, so only the passes above are measured, not the emitter that hq_zetas owns): RED BEFORE, on the
# parent, from twenty thousand goals ERROR 246 stack overflow; GREEN now at sixty thousand.  The program prints ok as swipl does.
# THE ARM: cut against swipl -q in this run and diffed in mode 3 and mode 4.
# rc=0 both modes agree with swipl - rc=1 a divergence - rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_asserting_a_conjunction_of_sixty_thousand_goals_does_not_overflow_the_default_stack_answers_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
mk(0, B, B) :- !.
mk(N, A, B) :- N1 is N-1, mk(N1, (true, A), B).
main :- mk(60000, true, Body), assertz((p :- Body)), p, write(ok), nl.
PL
( cd "$D" && timeout -k 5 60 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ "$(cat "$D/want")" = ok ] || refuse "swipl did not print ok: $(cat "$D/want")"
( cd "$D" && timeout -k 5 60 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 60 ./w < /dev/null > m4 2>> m4.err )
red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: 60000 conjuncts asserted and called, ok as swipl"
    else echo "  $m RED: [$(head -c 100 "$D/$m")] $(head -c 160 "$D/$m.err")"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
