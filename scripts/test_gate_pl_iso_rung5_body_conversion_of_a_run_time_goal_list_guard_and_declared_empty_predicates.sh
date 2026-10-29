#!/usr/bin/env bash
# test_gate_pl_iso_rung5_body_conversion_of_a_run_time_goal_list_guard_and_declared_empty_predicates.sh -- PROLOG ISO LADDER, RUNG 5 (cto, CEO-617, 2026-09-12).
# THE RUNG (ISO 7.6.2 body conversion, 8.10.1.3, 7.5.1 / 8.8): (1) a goal reaching call/1 is CONVERTED BEFORE IT RUNS:
# `call((fail, 1))` raises type_error(callable, (fail,1)) without running `fail`, `call((write(3), 1))` raises without
# printing, `call((1 ; true))` raises instead of succeeding -- whether the term is built at run time (the resolver on a
# control-construct key ,/2 ;/2 ->/2 *->/2 |/2) or is a compile-time control construct with a variable leaf bound at
# run time (the lowerer emits $pl_goal_guard on the whole term ahead of the inlined body); a NESTED unbound leaf is not
# an error (7.6.2: it becomes call(V)), so `call((fail, _))` fails. (2) findall/bagof/setof check their Instances
# argument BEFORE running the goal: neither a list nor a partial list raises type_error(list, Instances).
# (3) a predicate DECLARED (dynamic, multifile, discontiguous) with no clauses is defined: calling it fails,
# never existence_error -- the run-time wrapper for an unknown name asks the rung-3 key registry ($pl_declared/2).
# RED BEFORE on a clean origin build: call_1 16/20 (iso_call_1_13 fail, iso_call_1_15 succ, lgt_call_1_17/18
# existence_error), findall_3 12/14 (sics_findall_3_09, eclipse_findall_3_10 fail); witness 0 of 2 arms.
set -u
GATE_NAME=test_gate_pl_iso_rung5_body_conversion_of_a_run_time_goal_list_guard_and_declared_empty_predicates
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
    timeout -k 5 60 "$SCRIP" --compile --out="$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
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
cat > "$TMPD/conv.pl" <<'EOP'
:- initialization(main).
:- dynamic(emp/1).
:- multifile(fenix/1).
:- discontiguous(scattered/2).
one(1).
chk(N, G, Want) :- catch((call(G) -> R = yes ; R = no), error(E, _), R = E), ( R == Want -> write(ok(N)) ; write(bad(N, R)) ), nl.
lit_conj(One) :- catch((call((fail, One)) -> R = yes ; R = no), error(E, _), R = E), ( R == type_error(callable, (fail, 1)) -> write(ok(n)) ; write(bad(n, R)) ), nl.
lit_disj(One) :- catch((call((One ; true)) -> R = yes ; R = no), error(E, _), R = E), ( R == type_error(callable, (1 ; true)) -> write(ok(o)) ; write(bad(o, R)) ), nl.
lit_nested_unbound :- ( call((fail, _)) -> write(bad(p)) ; write(ok(p)) ), nl.
main :-
    one(One),
    chk(a, (fail, One), type_error(callable, (fail, 1))),
    chk(b, (write(3), One), type_error(callable, (write(3), 1))),
    chk(c, (One ; true), type_error(callable, (1 ; true))),
    chk(d, (fail, _), no),
    G1 = (true -> One ; true), chk(e, G1, type_error(callable, (true -> 1 ; true))),
    G2 = (fail, 1), chk(f, G2, type_error(callable, (fail, 1))),
    chk(g, emp(1), no), chk(h, fenix(_), no), chk(i, scattered(_, _), no),
    chk(j, findall(_, (write(never), nl), 12), type_error(list, 12)),
    chk(k, findall(_, true, [a|b]), type_error(list, [a|b])),
    chk(l, findall(X, member(X, [1,2]), [1|T]), yes), write(T), nl,
    chk(m, foobar(_), existence_error(procedure, foobar/1)),
    lit_conj(One), lit_disj(One), lit_nested_unbound,
    halt.
member(X,[X|_]). member(X,[_|T]) :- member(X,T).
EOP
arm a_run_time_goal_is_converted_before_it_runs_and_a_declared_empty_predicate_fails "$TMPD/conv.pl" "$(printf '%s\n' 'ok(a)' 'ok(b)' 'ok(c)' 'ok(d)' 'ok(e)' 'ok(f)' 'ok(g)' 'ok(h)' 'ok(i)' 'ok(j)' 'ok(k)' 'ok(l)' '[2]' 'ok(m)' 'ok(n)' 'ok(o)' 'ok(p)')" 0
floor call_1
floor findall_3
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
