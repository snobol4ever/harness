#!/usr/bin/env bash
# test_gate_pl_ssu_rules_answer_as_swipl.sh -- SWI-PROLOG 9'S SINGLE-SIDED-UNIFICATION RULES (Head, Guard => Body) ANSWER AS
# SWIPL, IN BOTH MODES (cfo 2026-10-10, row prolog-swi-class-ssu-arrow-rules, re-owned to the cfo by CEO-1592; the ceo's
# ruling: "the parser recognizes the neck and the guard into the pruned parse tree as the grammar produces it, and the
# lowerer places the semantics").
#
# THE CURE.  The parser reads => as op(1200, xfx) and keeps the rule that fired, =>(Head or (Head, Guard), Body), as the
# DCG neck is kept.  prolog_lower.c keys the rule by its inner head and carries it as head arguments plus one goal
# =>(GuardProgram, BodyProgram).  lower_prolog.c's first pass, pl_ssu_rewrite, places the semantics: the head MATCHES the
# call by subsumption -- subsumes_term('$ssu'(Patterns), '$ssu'(Params)), so a caller's argument is never bound -- then
# '$ssu'(Patterns) = '$ssu'(Params) binds only the rule's own variables, then the guard, then the commit (a cut), then the
# body; a predicate whose last rule is SSU gains a last clause throwing existence_error(matching_rule, Goal), so a call no
# rule matches is an error while a rule that commits and then fails makes the call fail.  The prelude injector pulls
# subsumes_term/2 for a program (or a vendored library) that has an SSU rule.
#
# THE ARM: the row's DONE-WHEN witness -- a guarded rule (and its guard's own error on an unbound argument), a caller
# variable left unbound, commit then fail, and the no-match error -- cut against swipl -q in this run, variable names
# normalized, diffed in mode 3 and mode 4.  FAIL-ONCE, measured: on the parent (SCRIP 46e6f4cb7, where => is no operator)
# 12 of 12 lines missed in both modes; with pl_ssu_rewrite ablated (an SSU rule lowered as an ordinary clause) 12 of 12.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSED(2) [test_gate_pl_ssu_rules_answer_as_swipl]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate test_gate_pl_ssu_rules_answer_as_swipl || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
p(X), X > 0 => writeq(pos(X)), nl.
p(0) => writeq(zero), nl.
p(_) => writeq(neg), nl.
q(f(Y)) => writeq(qf(Y)), nl.
r(X, Y) => Y = got(X).
s(a) => fail.
s(_) => writeq(s_other), nl.
t(G) :- catch((call(G) -> true ; (writeq(failed(G)), nl)), error(E, _), (writeq(caught(E)), nl)).
main :- t(p(3)), t(p(0)), t(p(-2)), t(p(_)), t(q(f(1))), t((q(V), writeq(after(V)), nl)), t(q(g)), t((r(1, R), writeq(R), nl)), t(s(a)), t(s(b)), t((s(Z), writeq(unbound_after(Z)), nl)).
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null 2> /dev/null | sed -E 's/_[0-9]+/_V/g' > want )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null 2> m3.err | sed -E 's/_G?[0-9]+/_V/g' > m3 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null 2>> m4.err | sed -E 's/_G?[0-9]+/_V/g' > m4 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -8 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS test_gate_pl_ssu_rules_answer_as_swipl"
exit "$red"
