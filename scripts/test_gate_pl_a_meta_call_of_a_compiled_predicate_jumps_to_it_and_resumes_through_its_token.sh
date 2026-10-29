#!/usr/bin/env bash
# test_gate_pl_a_meta_call_of_a_compiled_predicate_jumps_to_it_and_resumes_through_its_token.sh -- A META-CALL ENTERS A COMPILED PREDICATE THE WAY A STATIC CALL DOES.
# hq_prolog 2026-10-03, row prolog-bb-a-meta-call-of-a-compiled-predicate-jumps-to-it-and-resumes-through-its-token-not-rt-pl-goal-spine-prep-gen-h-resume-h-1863-call-sites
# (CEO-1499 re-mint; ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 4). ARM 1: zebra.pl's and queens_8.pl's mode-4 text name none of rt_pl_goal_spine_prep,
# rt_pl_goal_gen_h, rt_call_value_resume_h -- the call/N box resolves the goal through one value service (the fn and the goal's arity), dereferences the
# goal again after the poll, copies its cells and the extra arguments onto its spine as the block, bumps the level inline, jumps with its wires and lands
# as the static block arm does; a refusal is an armed ball and omega. ARMS 2-6: five witnesses vs swipl in m3 AND m4: call/1 and call/N of compiled
# predicates with a nondeterministic callee resumed through its token (findall, ->, a conjunction of two meta-calls); meta-called builtins, a conjunction
# and a disjunction as the goal, \+ inside call; the four refusals (unbound goal, a non-callable, two undefined predicates) each caught; a cut inside the
# goal is local to it; 10000-deep recursion through call/1 (a meta-call is not a tail call: 200000 overflows the default stack on origin too) and a meta-call inside a runtime-asserted clause (the fragment road of 51a54222f).
# The expected text is the oracle's, cut with /usr/bin/swipl -q -t halt at gate-writing time.
# RED BEFORE on origin 51a54222f: arm 1 names the three (zebra: 27 each, queens_8: 27 each -- measured by SCRIP_BIN on that build); the witnesses pass
# there (they are the behaviour the box must keep), so the gate's FAIL-ONCE is arm 1.
set -u
GATE_NAME=test_gate_pl_a_meta_call_of_a_compiled_predicate_jumps_to_it_and_resumes_through_its_token
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$B/zebra.pl" ] && [ -f "$B/queens_8.pl" ] || refuse "no corpus kernels at $B/zebra.pl, $B/queens_8.pl"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
named=""
for k in zebra queens_8; do
    timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$k.s" "$B/$k.pl" </dev/null 2>"$TMPD/err" || refuse "$k.pl did not compile: $(head -c 200 "$TMPD/err")"
    for h in rt_pl_goal_spine_prep rt_pl_goal_gen_h rt_call_value_resume_h; do
        c=$(grep -cE "call\s+(qword ptr \[rip \+ ${h}@GOTPCREL\]|${h}(@PLT)?)\s*$" "$TMPD/$k.s"); [ "$c" = 0 ] || named="$named $k:$h:$c"
    done
done
if [ -z "$named" ]; then echo "  ok  arm 1: zebra.pl's and queens_8.pl's mode-4 text call none of the three meta-call helpers"
else echo "  RED arm 1: mode-4 text still calls:$named"; red=$((red+1)); fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_pred <<'EOP'
p(1). p(2). p(3).
q(X, Y) :- Y is X * 10.
main :- G = p(X), findall(X, call(G), L), write(L), nl, call(q(4), R), write(R), nl, ( call(p(X2)), X2 > 1 -> write(X2) ; write(none) ), nl, findall(A-B, (call(p(A)), call(p, B), B > A), L2), write(L2), nl.
:- initialization(main).
EOP
mkw w_builtin <<'EOP'
main :- call(write(hi)), nl, call(atom_length(abcd), N), write(N), nl, call(atom_codes(ab), Cs), write(Cs), nl, G = (X = 1, Y = 2), call(G), write(X-Y), nl, H = (Z = a ; Z = b), findall(Z, H, L), write(L), nl, ( call(\+ fail) -> write(yes) ; write(no) ), nl.
:- initialization(main).
EOP
mkw w_ball <<'EOP'
main :- catch(call(_), error(E1, _), (write(E1), nl)), catch(call(3), error(E2, _), (write(E2), nl)), catch(call(nosuch(1, 2)), error(E3, _), (write(E3), nl)), catch(call(foo, 1), error(E4, _), (write(E4), nl)), write(done), nl.
:- initialization(main).
EOP
mkw w_cut <<'EOP'
t(1). t(2). t(3).
c(X) :- call(t(X)), !.
main :- findall(X, c(X), L), write(L), nl, ( call((t(Y), !, Y > 0)) -> write(Y) ; write(no) ), nl, findall(Z, (call(t(Z)), Z >= 2), L2), write(L2), nl.
:- initialization(main).
EOP
mkw w_deep <<'EOP'
count(0) :- !.
count(N) :- N1 is N - 1, G = count(N1), call(G).
main :- count(10000), write(deep), nl, assertz((d(N,R) :- G = s(N, R), call(G))), assertz(s(A, B) :- B is A + 1), d(41, X), write(X), nl.
:- initialization(main).
EOP
want_w_pred='[1,2,3]
40
2
[1-2,1-3,2-3]'
want_w_builtin='hi
4
[97,98]
1-2
[a,b]
yes'
want_w_ball='instantiation_error
type_error(callable,3)
existence_error(procedure,nosuch/2)
existence_error(procedure,foo/1)
done'
want_w_cut='[1]
1
[2,3]'
want_w_deep='deep
42'
for w in w_pred w_builtin w_ball w_cut w_deep; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: zebra.pl's and queens_8.pl's mode-4 text call none of the three meta-call helpers, and the five witnesses (compiled predicates and tokens, builtins and control goals, the four refusals, a local cut, deep recursion and the asserted-clause road) match swipl in both modes"
exit 0
