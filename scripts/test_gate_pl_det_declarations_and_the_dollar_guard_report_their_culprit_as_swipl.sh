#!/usr/bin/env bash
# test_gate_pl_det_declarations_and_the_dollar_guard_report_their_culprit_as_swipl.sh -- :- det(PI) ENFORCES A DETERMINISM PROPERTY, A
# $ GUARD'S LAST CALL IS CHECKED, AND BOTH NAME THE CULPRIT AS swipl DOES (cfo 2026-10-14, SWI core/test_det_decl.pl 6 -> 22 of 22).
#
# (1) det/1 did not exist (every :- det(...) was an existence_error warning, and no declared predicate was ever checked). The
# declaration now wraps each declared predicate (lower_prolog.c pl_det_rewrite, modelled on :- table's wrapper): the clauses move to
# '$det name'/N, the predicate itself is one clause calling '$det_prop'(CulpritPI, OwnPI, '$det name'(Args)), which lowers like $G
# (pl_lower_det_prop): a nondet exit raises error(determinism_error(PI, det, nondet, property), context(PI, _)), a failure the same with
# fail. swipl names the predicate that owns the choice point or failed, found past the single-clause last-call chain (np -> np1 -> np2
# reports np2/1); with the debug flag true it names the declared predicate and keeps the callee in the context. The chain is the
# program's own single-clause last calls, followed statically.
# (2) A $ guard's last call took the last-call arm, so nothing checked it: ga(X) :- $, nd3(X) answered yes for a nondeterministic exit.
# A guarded clause whose last goal is a plain call to ANOTHER predicate now keeps its check (pl_lower_conj_guard); the error is
# determinism_error(Culprit, det, nondet|fail, guard_in_caller) with the same chain rule, `guard` with the clause's own predicate when
# the last goal is not a call. A self-recursive last call keeps its last-call arm (the 500000-deep $ recursion of the marks gate).
# (3) The $G error's goal is the user's goal, not the unit's renamed 'plunit_u:nd'(...).
# (4) A module file's or unit's det/1 names were not renamed with its predicates (prolog_lower.c): det is renamed like dynamic.
# NOT HERE: the context member_/3 swipl gives for a library last call; the culprit of a multi-clause chain whose clauses end in calls.
#
# THE ARMS: two programs (a plain file of 18 lines, a unit file of 4), stdout cut against swipl in this run, mode 3 and mode 4.
# FAIL-ONCE, measured on the parent 41dfbffc2 rebuilt: 16 of 22 lines differ in both modes (det/1 does not exist, the guard last call is
# unchecked, the $G goal is unit-qualified); with the cure 22 of 22 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_det_declarations_and_the_dollar_guard_report_their_culprit_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
PLUNIT="${S4E_CORPUS:-$B/../corpus}/tests/prolog/plunit.pl"; [ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/v1.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- det((p1/1, np/1, q/0)).
p1(1).
p1(2).
p1(2).
np(X) :- np1(X).
np1(X) :- np2(X).
np2(1).
np2(2).
q.
q.
nd(X) :- nd2(X).
nd2(X) :- nd3(X).
nd3(1).
nd3(2).
nd3(2).
ga(X) :- $, nd3(X).
gb(X) :- $, true, nd3(X).
gc(X) :- $, nd3(X), true.

ge(X) :- $, nd(X).
gcall :- $, call(nd3(_)).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, C), R = err(E, C)), \+ \+ ( numbervars(N-R, 0, _), write_term(N-R, [quoted(true), numbervars(true)]), nl ).
main :- t(p1_det, p1(1)), t(p1_nondet, p1(2)), t(p1_fail, p1(3)), t(np_nondet, np(_)), t(np_fail, np(3)), t(np_det, np(1)), t(q, q),
    t(ga, ga(2)), t(ga_fail, ga(3)), t(gb, gb(2)), t(gc, gc(2)), t(ge, ge(2)), t(ge_fail, ge(3)), t(ge_det, ge(1)), t(gcall, gcall),
    set_prolog_flag(debug, true),
    t(dbg_np, np(_)), t(dbg_ge, ge(2)), t(dbg_p1, p1(2)).
PL
cat > "$D/v2.pl" <<'PL'
:- use_module(library(plunit)).
:- begin_tests(u).
nd(X) :- nd2(X), garbage_collect.
nd2(X) :- nd3(X).
nd3(1).
nd3(2).
nd3(2).
end.
d(X) :- $nd(X), end.
d1 :- $nd3(X), u(X).
u(_).
pt(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), \+ \+ ( numbervars(N-R, 0, _), write_term(N-R, [quoted(true), numbervars(true)]), nl ).
test(a) :- pt(goal_det, d(1)), pt(goal_nondet, d(2)), pt(goal_fail, d(3)), pt(goal_var, d1).
:- end_tests(u).
PL
printf ':- initialization(run_tests).\n' > "$D/g.pl"
norm() { grep -E '^\.?[a-z_0-9]+-' | sed 's/^\.//'; }
want="$( (cd "$D" && timeout -k 5 20 "$SW" -q v1.pl -t halt < /dev/null 2>/dev/null | norm; timeout -k 5 20 "$SW" -q -g run_tests -t halt v2.pl < /dev/null 2>/dev/null | norm) )"
[ "$(printf '%s\n' "$want" | grep -c .)" = 22 ] || refuse "swipl did not answer the twenty-two lines: [$(printf '%s\n' "$want" | grep -c .)]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o v1.s v1.pl < /dev/null > /dev/null 2>&1 && [ -s v1.s ] && gcc -m64 -no-pie v1.s -o v1.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 \
  && timeout -k 5 60 "$B/scrip" --compile -o v2.s "$PLUNIT" v2.pl g.pl < /dev/null > /dev/null 2>&1 && [ -s v2.s ] && gcc -m64 -no-pie v2.s -o v2.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1" got n; shift
    got="$( (cd "$D" && "$1" v1 | norm; "$1" v2 | norm) )"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 22 of 22 lines as swipl"
    else echo "  $label RED: $n of 22 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
m3run() { if [ "$1" = v1 ]; then timeout -k 5 30 "$B/scrip" --run v1.pl < /dev/null 2>/dev/null; else timeout -k 5 30 "$B/scrip" --run "$PLUNIT" v2.pl g.pl < /dev/null 2>/dev/null; fi; }
m4run() { timeout -k 5 30 "./$1.bin" < /dev/null 2>/dev/null; }
arm m3 m3run
if [ "$m4ok" = 1 ]; then arm m4 m4run; else echo "  m4 RED: a program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
