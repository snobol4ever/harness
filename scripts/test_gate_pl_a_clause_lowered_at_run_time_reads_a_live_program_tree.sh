#!/usr/bin/env bash
# test_gate_pl_a_clause_lowered_at_run_time_reads_a_live_program_tree.sh -- A PREDICATE LOWERED AT RUN TIME READS THE PROGRAM TREE
# THE COMPILE REGISTERED, SO MODE 3 KEEPS THAT TREE ALIVE FOR THE RUN (cfo 2026-10-11, the coo's red on 43a241a77: SWI
# core/test_arith.pl died at start in mode 3, SIGSEGV at fault address 0x9 in pl_static_clause_term, 220 cases CRASH).
#
# THE ROAD: a program calling clause/2 with a head the compile cannot name (G = p(_), clause(G, B)) seeds every static predicate
# into the clause database ($db_seed_once), and the run-time seed lowers each one again (pl_db_store, recompile=1). A seeded body
# that calls clause/2 on a static predicate that is never seeded itself -- a '$'-named one, as library(error)'s current_type/3
# calls clause('$error_has_type'(T, V), B) -- reads that predicate's clauses from g_stage2.resolve_pred_table, whose entries point
# INTO the program tree. src/driver/scrip.c freed that tree in mode 3 between the compile and the run (ast_tree_free before the
# first box ran), so the run-time lowerer read freed compile-time arena blocks: while nothing reused them it read the old values and
# answered; once 43a241a77's larger gnu_builtins prelude moved the layout, ct_grow of the run-time g_proc_loc vector recycled the
# choice node's child array and child 31 read 0x9 (a gdb hardware watch on choice->c[31]; under SCRIP_CT_POISON=1 the drop that
# freed it is ast_tree_free from main). The tree's lifetime is the run (THE LIFETIME RULE): the cure keeps it, and the process
# exit reclaims the arena. Mode 4 never ran the free on this road and agreed before and after.
#
# THE ARM: a '$'-named static predicate of three clauses, a predicate whose body calls clause/2 on it, and a variable-headed
# clause/2 that seeds every static predicate; stdout cut against swipl in this run, in mode 3 and mode 4, plain and under
# SCRIP_CT_POISON=1 (a dropped compile-time block reads 0xDD, so a stale read cannot pass on layout luck).
# FAIL-ONCE, measured with the parent's driver (the two lines restored) and rebuilt: this gate read "m3 poisoned RED: got [] want
# [1,2,3]" while its plain m3 arm read green on that layout (a scratch copy of the same parent answered [] plain too, and
# core/test_arith.pl dumped core) -- the poisoned arm is the one that cannot pass on layout luck. With the cure all four arms
# agree with swipl and test_arith reads 191 passed, 29 failed, 1 skipped in mode 3, poisoned too.
# rc=0 every arm agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_clause_lowered_at_run_time_reads_a_live_program_tree
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
'$s'(1). '$s'(2). '$s'(3).
p(X) :- clause('$s'(X), true).
:- initialization(main).
main :- G = p(_), clause(G, B), write(B), nl, findall(X, p(X), L), write(L), nl.
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>&1 | sed 's/_[0-9][0-9]*/_V/g; s/_G[0-9][0-9]*/_V/g')"
[ -n "$want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got
    got="$(cd "$D" && "$@" 2>&1 | sed 's/_[0-9][0-9]*/_V/g; s/_G[0-9][0-9]*/_V/g')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: as swipl ($(printf '%s' "$got" | tail -1))"
    else echo "  $label RED: got [$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=1; fi
}
arm "m3" timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm "m3 poisoned" env SCRIP_CT_POISON=1 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm "m4" timeout -k 5 20 ./w.bin < /dev/null
arm "m4 poisoned" env SCRIP_CT_POISON=1 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
