#!/usr/bin/env bash
# test_gate_pl_iso_rung2_runtime_heads_and_meta_call_wrappers.sh -- PROLOG ISO LADDER, RUNG 2 (cto, CEO-617, 2026-09-12).
# THE RUNG: a database builtin whose head, clause or predicate indicator is only known at RUN TIME -- asserta(_),
# four(F), asserta(F), retract((H :- B)) with H bound by a helper, clause(_, B), abolish(foo/X), retractall(T) --
# raises the ISO error term ($db_t_guard: instantiation_error, type_error(callable), permission_error on a control
# construct, a builtin or a static procedure, type_error(predicate_indicator) and abolish's atom/integer/
# not_less_than_zero/max_arity) or else acts on the predicate's store found BY KEY at run time (a registry in
# dynamic cell 0, bound to every compile-time cell by $db_bind at program start, growing an off-root store for a
# predicate the compiler never saw); a predicate first created at run time is reachable by name afterwards
# (rt_proc_register before the flags); an abolished predicate answers existence_error; the file clauses of a
# dynamic predicate are seeded once from the $db_seed/0 graph before any directive runs; the meta-call wrappers
# cover assert/asserta/assertz/retract/retractall/abolish/clause so call(assertz(foo(1))) works; a predicate
# unknown at compile time is a run-time meta-call instead of a compile-time existence_error, which also cures
# the $fc/3 helper's self-recursion (it was compiled to existence_error, so a meta-called ','/2 whose left
# conjunct was itself a conjunction raised existence_error('$fc'/3)).
# WITNESS: the Logtalk ISO groups this rung moves, graded one --group at a time in BOTH modes against the floors
# measured at landing. RED BEFORE (after rung 1, m3): asserta_1 16/24, assertz_1 16/24, abolish_1 12/16,
# retract_1 13/18, retractall_1 10/15, clause_2 11/16, cut_0 16/21. A later rung may only raise a floor.
set -u
GATE_NAME=test_gate_pl_iso_rung2_runtime_heads_and_meta_call_wrappers
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
floor() {
    local group="$1" want="$2" line pass
    line="$(python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "${PL_RUNG_JOBS:-8}" --group "$group" 2>/dev/null | grep -m1 '^LOGTALK_ISO_BOARD ')"
    [ -n "$line" ] || { echo "  ⛔ $group: the grader printed no LOGTALK_ISO_BOARD line"; red=$((red+1)); total=$((total+1)); return; }
    pass="$(printf '%s\n' "$line" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p')"
    total=$((total+1))
    if [ "${pass:-0}" -ge "$want" ]; then echo "  ok  $group m3_pass=$pass (floor $want)  $line"
    else echo "  RED $group m3_pass=$pass < floor $want  $line"; red=$((red+1)); fi
    case "$MODES" in *m4*)
        local p4; p4="$(printf '%s\n' "$line" | sed -n 's/.*m4_pass=\([0-9]*\).*/\1/p')"
        if [ -n "$p4" ] && [ "$p4" -lt "$want" ]; then echo "  RED $group m4_pass=$p4 < floor $want (modes may diverge as an optimization, never here)"; red=$((red+1)); fi ;;
    esac
}
floor asserta_1 24
floor assertz_1 24
floor abolish_1 16
floor retract_1 15
floor retractall_1 12
floor clause_2 12
floor cut_0 18
floor call_1 16
floor call_N 26
echo "$GATE_NAME: groups=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
exit 0
