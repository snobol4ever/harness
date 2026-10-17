#!/usr/bin/env bash
# test_gate_pl_iso_rung1_database_builtins_and_call_local_cut.sh -- PROLOG ISO LADDER, RUNG 1 (cto, CEO-617, 2026-09-12).
# THE RUNG: the database builtins raise the ISO error terms for literal arguments (type_error(callable, T) for a
# number in head or body, permission_error(modify, static_procedure, PI) for a control construct or builtin head,
# permission_error(access, private_procedure, PI) for clause/2 on one, type_error(predicate_indicator, S) and
# abolish's atom/integer/not_less_than_zero/max_arity terms for a bad spec), a directive assert marks its predicate
# dynamic the way a clause-body assert always did, a number in goal position raises type_error(callable) BEFORE
# anything runs (call((write(3), 1)) prints nothing), a cut inside call/1 is local to the call (ISO 7.8.3.3) while
# a cut inside a branch of a disjunction in the SAME scope still prunes it, max_arity is 1024 and functor/3 raises
# representation_error(max_arity) above it, and standard order puts 1.0 before 1 (ISO 7.2.1).
# WITNESS: the Logtalk ISO conformance groups this rung moves, graded by the suite's own grader ONE GROUP AT A
# TIME (--group is the grader's own development aid, never a board) in BOTH modes, against the pass floors
# measured at landing. RED BEFORE (coo board 2026-09-12T15:59:54 at 55aaa01ad, m3): asserta_1 4/24, assertz_1
# 4/24, abolish_1 5/16, retract_1 7/18, retractall_1 6/15, clause_2 8/16, current_predicate_1 4/23, cut_0 13/21,
# call_1 15/20. The floors below are what this rung LANDED at; a later rung may only raise them.
set -u
GATE_NAME=test_gate_pl_iso_rung1_database_builtins_and_call_local_cut
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
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
floor asserta_1
floor assertz_1
floor abolish_1
floor retract_1
floor retractall_1
floor clause_2
floor current_predicate_1
floor cut_0
floor call_1
floor if_then_else_3
floor disjunction_2
floor term_comparison
floor compare_3
floor functor_3
echo "$GATE_NAME: groups=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
exit 0
