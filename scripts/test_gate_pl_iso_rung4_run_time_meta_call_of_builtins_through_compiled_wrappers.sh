#!/usr/bin/env bash
# test_gate_pl_iso_rung4_run_time_meta_call_of_builtins_through_compiled_wrappers.sh -- PROLOG ISO LADDER, RUNG 4 (cto, CEO-617, 2026-09-12).
# THE RUNG: a goal bound AT RUN TIME reaches every builtin the lowerer knows (ISO 7.7.3 / 8.15.1 / 8.10 / 7.8.3):
# `G = current_op(_,xfx,is), call(G)`, likewise between/3, current_predicate/1, findall/3, sub_atom/5, call/1,
# catch/3, forall/2, \+/1, a nested conjunction or disjunction, the cut, `nl`, `fail` -- with FULL REDO (a run-time
# generator yields every solution under findall and under backtracking), call/N extra arguments appended, and an
# unknown name still raising existence_error(procedure, N/A) (or failing under unknown=fail) WITHOUT LOOPING.
# BEFORE THIS RUNG the run-time goal resolver (rt_pl_goal_gen_h_c / rt_pl_goal_spine_prep) looked the goal's
# Name/Arity up in the procedure registry and raised existence_error for every builtin that is lowered inline
# (only file predicates, run-time predicates, the rung-2 control-construct wrappers and the few leaf builtins
# that happen to be registered were reachable).
# THE MECHANISM: on a Name/Arity that is not a registered procedure the resolver compiles a ONE-CLAUSE WRAPPER
# `$mc:Name(A1..An) :- Name(A1..An)` through the same run-time predicate compiler the dynamic database uses
# (pl_runtime_define_pred -> the ordinary goal lowerer -> emit_chain: wired boxes, no interpreter), registers it
# under `$mc:Name/N` and calls it as any registered generator; a wrapper whose body itself lowered to a run-time
# meta-call of the SAME Name/Arity (the unknown case) is redefined as the ISO existence_error thrower (or `fail`
# under unknown=fail), so the resolver never recurses and the second call pays nothing.
# WITNESS: three engine programs compared LINE FOR LINE with the oracle's output in BOTH modes, plus floors on the
# Logtalk ISO groups this rung touches, graded one --group at a time in BOTH modes (RED BEFORE on a clean origin
# build 577298671: not_1 8/10; the other floors are the standing counts, held so a later change to the resolver
# cannot trade a group away). A later rung may only raise a floor.
# ⛔⭐ EXPECTATION CORRECTED 2026-09-13 (cto), and the correction is the point: this arm shipped expecting
# `ok(1=1,1==1)` -- which READS AS ok/2 and was the term writer emitting a(b,c) for a((b,c)), a DIFFERENT TERM
# and not a formatting difference. hq_R cured that in cb1578145 (three near-identical writers, each with its own
# operator table, unified into one plc_wt with maximum priority threaded), and this gate went red on the cure
# because its expectation was ANCHORED ON THE DEFECT (RULES.md INSTRUMENT LAWS, eighteenth batch). Both oracles
# agree on the corrected line: swipl 9 and gprolog 1.4.5 both write `ok((1=1,1==1))` and both read functor ok/1.
set -u
GATE_NAME=test_gate_pl_iso_rung4_run_time_meta_call_of_builtins_through_compiled_wrappers
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
# ⭐ THE FLOOR IS THE FAMILY'S POPULATION, READ FROM THE BOARD, NEVER A LITERAL (ceo CEO-1305, 2026-09-27): the literal floors
# stood above populations the CEO-1266 crawl shrank at 97ade7cf7 (coinduction declared unsupported, engine guards probed), so
# functor_3 read 19 of 19 under a floor of 21. A case the grader names GUARDED OUT has already left the population; a case it
# names OUTSIDE, UNGRADABLE or DEFERRED leaves the floor here, per mode, from its identity line. Every other case must PASS:
# the gate still reds on a lost pass, and a newly admitted case enters the floor the run it enters the population.
floor() {
    local group="$1" out line mode pass want idl
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "${PL_RUNG_JOBS:-8}" --group "$group" 2>/dev/null)"
    line="$(printf '%s\n' "$out" | grep -m1 '^LOGTALK_ISO_BOARD ')"
    total=$((total+1))
    [ -n "$line" ] || { echo "  ⛔ $group: the grader printed no LOGTALK_ISO_BOARD line"; red=$((red+1)); return; }
    for mode in $(printf '%s' "$MODES" | tr ',' ' '); do
        pass="$(printf '%s\n' "$line" | sed -n "s/.*${mode}_pass=\\([0-9]*\\).*/\\1/p")"
        idl="$(printf '%s\n' "$out" | grep -m1 "identity ${mode}:")"
        want="$(printf '%s\n' "$idl" | awk '{for (i = 1; i < NF; i++) { if ($i == "OUTSIDE" || $i == "UNGRADABLE" || $i == "DEFERRED") named += $(i+1); if ($i == "==") pop = $(i+1) } } END { if (pop != "") print pop - named }')"
        [ -n "$want" ] && [ -n "$pass" ] || { echo "  ⛔ $group $mode: the board printed no identity line or no pass count -- cannot read the population"; red=$((red+1)); continue; }
        if [ "$pass" -ge "$want" ]; then echo "  ok  $group ${mode}_pass=$pass (floor = its population less named outside/ungradable/deferred: $want)  $line"
        else echo "  RED $group ${mode}_pass=$pass < floor $want (its population less named outside/ungradable/deferred)  $line"; red=$((red+1)); fi
    done
    printf '%s\n' "$out" | grep -m1 '^GUARDED OUT' | sed -n 's/^GUARDED OUT.* named): \([0-9]* case(s)\).* -- \(.*\)$/        guarded out of the population, named: \1 -- \2/p'
}
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile -o "$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
arm() {
    local name="$1" src="$2" want_out="$3" want_rc="$4" mode got rc
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ] && [ "$rc" = "$want_rc" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: rc=$rc want $want_rc; out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
cat > "$TMPD/reach.pl" <<'EOP'
:- initialization(main).
t(G) :- ( catch(call(G), E, (write(caught(E)), nl, fail)) -> write(ok(G)), nl ; write(failed(G)), nl ).
main :-
    G1 = current_op(_,xfx,is), t(G1),
    G2 = between(1,3,_), t(G2),
    G3 = current_predicate(main/0), t(G3),
    G4 = atom_length(abc,_), t(G4),
    G5 = call(true), t(G5),
    G6 = (X = 1, X == 1), t(G6),
    G7 = findall(Y, member(Y,[a,b]), L), t(G7), write(L), nl,
    G8 = sub_atom(abc,_,1,_,b), t(G8),
    G9 = atom_codes(_, [0'h, 0'i]), t(G9),
    halt.
member(X,[X|_]). member(X,[_|T]) :- member(X,T).
EOP
arm every_lowerer_known_builtin_is_reachable_by_a_run_time_goal "$TMPD/reach.pl" "$(printf '%s\n' 'ok(current_op(700,xfx,is))' 'ok(between(1,3,1))' 'ok(current_predicate(main/0))' 'ok(atom_length(abc,3))' 'ok(call(true))' 'ok((1=1,1==1))' 'ok(findall(_G0,member(_G0,[a,b]),[a,b]))' '[a,b]' 'ok(sub_atom(abc,1,1,1,b))' 'ok(atom_codes(hi,[104,105]))')" 0
cat > "$TMPD/redo.pl" <<'EOP'
:- initialization(main).
main :-
    G1 = between(1,3,X), findall(X, call(G1), L1), write(L1), nl,
    G2 = between(1,3,Y), findall(Y, G2, L2), write(L2), nl,
    G3 = member(Z,[a,b,c]), ( call(G3), write(Z), nl, Z == b -> true ; true ),
    G4 = between(1), findall(W, call(G4, 2, W), L4), write(L4), nl,
    G5 = foo(1), catch(call(G5), error(E5,_), (write(E5), nl)),
    catch(call(G5), error(E6,_), (write(E6), nl)),
    G7 = !, ( call(G7) -> write(cut_true) ; write(cut_false) ), nl,
    G8 = (member(Q,[1,2,3]), Q > 1), findall(Q, G8, L8), write(L8), nl,
    G9 = atom_codes(A9, [0'h,0'i]), call(G9), write(A9), nl,
    G10 = current_op(P, xfx, is), findall(P, G10, L10), write(L10), nl,
    G11 = sub_atom(hello, B, 2, _, Sub), findall(B-Sub, G11, L11), write(L11), nl,
    G12 = (X12 = 1 ; X12 = 2), findall(X12, G12, L12), write(L12), nl,
    G13 = catch(throw(oops), oops, true), ( call(G13) -> write(catch_ok) ; write(catch_bad) ), nl,
    G14 = nl, call(G14),
    G15 = fail, ( call(G15) -> write(bad) ; write(fail_ok) ), nl,
    G16 = forall(member(F,[1,2]), F > 0), ( call(G16) -> write(forall_ok) ; write(forall_bad) ), nl,
    G17 = (\+ member(9,[1,2])), ( call(G17) -> write(neg_ok) ; write(neg_bad) ), nl,
    G18 = 3, catch(call(G18), error(E18,_), (write(E18), nl)),
    halt.
member(X,[X|_]). member(X,[_|T]) :- member(X,T).
EOP
arm a_run_time_generator_redoes_and_an_unknown_name_never_loops "$TMPD/redo.pl" "$(printf '%s\n' '[1,2,3]' '[1,2,3]' a b '[1,2]' 'existence_error(procedure,foo/1)' 'existence_error(procedure,foo/1)' cut_true '[2,3]' hi '[700]' '[0-he,1-el,2-ll,3-lo]' '[1,2]' catch_ok '' fail_ok forall_ok neg_ok 'type_error(callable,3)')" 0
cat > "$TMPD/unk.pl" <<'EOP'
:- initialization(main).
main :- set_prolog_flag(unknown, fail), G = nothere(1,2), ( call(G) -> write(bad) ; write(unknown_fail_ok) ), nl, ( call(G) -> write(bad) ; write(unknown_fail_ok) ), nl, halt.
EOP
arm an_unknown_name_under_unknown_fail_fails_twice_without_looping "$TMPD/unk.pl" "$(printf '%s\n' unknown_fail_ok unknown_fail_ok)" 0
floor not_1
floor call_1
floor findall_3
floor forall_2
floor once_1
floor between_3
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
exit 0
