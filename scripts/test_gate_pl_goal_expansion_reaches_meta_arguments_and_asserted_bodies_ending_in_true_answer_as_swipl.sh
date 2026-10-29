#!/usr/bin/env bash
# test_gate_pl_goal_expansion_reaches_meta_arguments_and_asserted_bodies_ending_in_true_answer_as_swipl.sh -- load-time GOAL EXPANSION REACHES A USER META-ARGUMENT AND A MODULE'S TERM EXPANSION SEES ITS OWN
# CLAUSES; A DYNAMIC BODY ENDING IN `true` INSIDE A DISJUNCTION ARM RUNS AS swipl RUNS IT; current_predicate(N//A)
# AND `dynamic M:PI` ANSWER AS swipl (cfo 2026-10-14, SWI core/test_expand, row prolog-swi-... test_expand).
#
# Four defects measured on the parent, one program each family, stdout cut against swipl in this run, mode 3 and mode 4:
#  (a) expand_goal stopped at the control constructs and the six builtin meta goals it knew: a user `:- meta_predicate run(0)`
#      never had its goal argument expanded (run(foo) called foo/0). The lowerer now emits the program's meta_predicate
#      specs as $meta_add facts whenever the program defines goal_expansion/2, and $expand_ctl walks the 0-arguments; not/1,
#      call_cleanup/2 and setup_call_cleanup/3 join the walked builtins.
#  (b) a goal_expansion result that is an if-then (X->true) is wrapped (R, true) as SWI wraps it, so a disjunct `onetime(G)`
#      keeps the else arm: one(X) answers [1,2].
#  (c) a module file's facts are renamed M:name, so a term_expansion(make_dcg, ...) never saw them: $load_item now carries
#      the file's module and de-qualifies a term it hands to term_expansion, loading the unqualified result.
#  (d) a conjunction whose goal `true` closed a disjunct arm of an ASSERTED or dynamic clause lowered `true` as a bare SUCCEED:
#      (X=1, true ; X=2) answered [1] and ((X=1;X=3), true ; X=2) HUNG; pl_lower_conj now drops `true` from a multi-goal
#      conjunction (a lone `true` stays).
#  plus: current_predicate(N//A) is the DCG-arity form; `dynamic user:p/1` marks p/1 dynamic at the parser stage;
#  set_module/1 and '$clausable'/1 exist.
# FAIL-ONCE, measured on the parent rebuilt: w1 and w2 each lines missing or different (hang in w2 killed by the 20 s ceiling).
# rc=0 both modes agree with swipl on both programs · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_goal_expansion_reaches_meta_arguments_and_asserted_bodies_ending_in_true_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w1.pl" <<'PL'
:- initialization(main).
:- dynamic user:hook/1.
:- set_module(base(user)).
:- '$clausable'(foo/2).
foo --> [].
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), writeq(N-R), nl.
main :- t(direct_def, current_predicate(foo//0)), t(direct_undef, current_predicate(no_a//0)), t(called, call(current_predicate(foo//0))), t(var_arity, (current_predicate(foo//A), writeq(A), nl)),
  t(neg, \+ current_predicate(no_a//0)), G = current_predicate(no_a//0), t(meta_undef, G), t(enumerate, (current_predicate(foo//N0), writeq(N0), nl)),
  t(dyn_mpi, current_predicate(hook/1)), t(clausable, '$clausable'(foo/2)).
PL
cat > "$D/w2.pl" <<'PL'
:- module(w2, [main/0]).
:- multifile user:term_expansion/2, user:goal_expansion/2.
:- dynamic user:term_expansion/2, user:goal_expansion/2.
:- discontiguous goal_expansion/2.
term_expansion(make_dcg, (a --> "")).
goal_expansion(g_b, g_c).
make_dcg.
g_c.
e_not :- not(g_b).
goal_expansion(foo, bar).
:- meta_predicate run(0).
test_foo_bar :- run(foo).
bar.
run(Goal) :- Goal.
goal_expansion(onetime(X), (X->true)).
one(X) :- ( onetime(X=1) ; X = 2 ).
:- dynamic da/1, db/1, dc/1.
main :- ( e_not -> writeq(e_not-yes) ; writeq(e_not-no) ), nl,
    ( test_foo_bar -> writeq(foo-yes) ; writeq(foo-no) ), nl,
    findall(X, one(X), L), writeq(one-L), nl,
    ( clause(a(L0, L1), B), B == (L0=L1) -> writeq(dcg-yes) ; writeq(dcg-no) ), nl,
    assertz((da(X1) :- ((X1=1->true), true ; X1=2))), assertz((db(X2) :- ((X2=1;X2=3), true ; X2=2))), assertz((dc(X3) :- (X3=1, true ; X3=2))),
    findall(Y1, da(Y1), L1a), writeq(da-L1a), nl, findall(Y2, db(Y2), L2a), writeq(db-L2a), nl, findall(Y3, dc(Y3), L3a), writeq(dc-L3a), nl.
:- initialization(main).
PL
red=0
for w in w1 w2; do
    want="$(cd "$D" && timeout -k 5 20 "$SW" -q $w.pl -t halt < /dev/null 2>/dev/null | grep .)"
    [ -n "$want" ] || refuse "swipl did not answer $w"
    m4ok=1
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=$w.s $w.pl < /dev/null > /dev/null 2>&1 && [ -s $w.s ] \
      && gcc -m64 -no-pie $w.s -o $w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
    arm() {
        local label="$1"; shift
        local got n
        got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
        n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
        if [ "$got" = "$want" ]; then echo "  $w $label GREEN: $(printf '%s\n' "$want" | grep -c .) of $(printf '%s\n' "$want" | grep -c .) lines as swipl"
        else echo "  $w $label RED: $n swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
    }
    arm m3 timeout -k 5 20 "$B/scrip" --run $w.pl < /dev/null
    if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./$w.bin < /dev/null; else echo "  $w m4 RED: the program did not compile or link in mode 4"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
