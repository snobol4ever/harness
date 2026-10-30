#!/usr/bin/env bash
# test_gate_pl_ir_delete_all_invalidates_every_bb_idx_and_a_colliding_static_call_answers_as_the_oracle.sh -- ARCH-PROLOG-ACTIVATION-LIFETIME 9.14 (a),
# the cto 2026-10-29 19:0x: ir_delete_all INVALIDATES every ProcEntry's bb_idx (to -1) in the same call that frees the graphs, and a reader that indexes
# the graph table with -1 refuses rc 2 by name instead of reading whatever run-time graph now holds that slot.
#
# THE HAZARD (the cfo's, after SCRIP 8a31d7c2f): mode 3 frees every static graph before main runs and the run-time graph table restarts at 0, while
# every ProcEntry kept its old index; a static proc whose index is below the run-time count would read an unrelated run-time graph as its callee.
#
# WHAT A COLLISION CAN AND CANNOT SHOW, measured 2026-10-29 21:3x CDT on SCRIP 8ed8fe200 with a lookup log in bb_proc_find (not landed): a Prolog
# program's graphs 0..2 belong to the internal $db_seedS* procs, which no clause calls, and the run-time table peaks at 2 graphs, even through a
# run-time consult of 40 predicates; SNOBOL4's CODE() and EVAL() leave it at 0. So no reachable call collides, and the witness below (a clause asserted
# after load calling static predicates, clause/2 and retract/1 on it) reads green before the cure as after. THE RED BEFORE is the table's own state,
# read by gdb at the return of ir_delete_all in a mode-3 run: on the parent every proc with a graph still holds its index (live_index > 0).
#
# THE READERS THE -1 CHANGES: the three by-name method dispatch tests of Raku (by_name_dispatch.c: invoke_method_proc_rq, rk_method_open_at,
# rk_redispatch_open) read "bb_idx >= 0" as "this proc has compiled code" at run time, which held only because the index was stale; measured with the
# invalidation alone, the Raku smoke's class_method fails in mode 3. They ask the registry (rt_proc_has_native_fn) instead. The indexers that took
# s2->bbp.table[pe->bb_idx] with no check (driver_proc_props, driver_install_proc, planner_road_proc, planner_proc_road, emit_proc_prepare) go
# through stage2_proc_graph, which refuses rc 2 naming the reader and the proc. Every other reader already guards (bi >= 0 && bi < count).
#
# ARMS: (1) STATE: gdb at the return of ir_delete_all in mode 3 counts ProcEntry rows with bb_idx >= 0 -- 0 of a non-empty table; (2) REFUSAL: in the
# same session, stage2_proc_graph on proc 0 prints its named line and the program exits with code 2; (3) the witness equal to swipl's answer in mode 3
# and mode 4; (4) the Raku smoke, both modes (class_method is the dispatch reader).
#
# Usage: bash ../harness/scripts/test_gate_pl_ir_delete_all_invalidates_every_bb_idx_and_a_colliding_static_call_answers_as_the_oracle.sh
#        (rc 0 green, 1 red, 2 could not measure)
set -uo pipefail
GATE_NAME=test_gate_pl_ir_delete_all_invalidates_every_bb_idx_and_a_colliding_static_call_answers_as_the_oracle
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gdb >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gdb -- the state arm reads the proc table at the return of ir_delete_all"; exit 2; }
command -v swipl >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no swipl -- the witness's answer is cut from the oracle"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'EOF'
:- dynamic t/1.
p(1). p(2). p(3).
q(X, Y) :- p(X), Y is X * 10.
r(X) :- member(X, [a, b]).
s(X) :- t(X), X \== a.
:- assertz((t(Z) :- q(X, Z), X > 1)), findall(Z, t(Z), L), write(L), nl.
:- assertz((t(Z) :- r(Z))), findall(Z, s(Z), L), write(L), nl.
:- clause(q(_, _), B), numbervars(B, 0, _), print(B), nl.
:- retract((t(Z) :- q(_, Z), _)), findall(Z, t(Z), L), write(L), nl.
:- assertz(t(9)), findall(Z, s(Z), L), write(L), nl.
EOF
( cd "$T" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null > w.ref 2> /dev/null ) && [ -s "$T/w.ref" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: swipl gave no answer for the witness"; exit 2; }
cat > "$T/state.gdb" <<'EOF'
set pagination off
set confirm off
set breakpoint pending on
break ir_delete_all
run
finish
python
import gdb
s2 = gdb.parse_and_eval("g_stage2")
n = int(s2["proc_count"])
live = sum(1 for i in range(n) if int(s2["proc_table"][i]["bb_idx"]) >= 0)
print("GATE-STATE procs=%d live_index=%d" % (n, live))
end
call (void *) stage2_proc_graph(&g_stage2, 0, "gate_probe")
EOF
fail=0
( cd "$T" && timeout -k 5 120 gdb -q -batch -x state.gdb --args "$SCRIP" w.pl < /dev/null > gdb.out 2>&1 )
st=$(grep -o 'GATE-STATE procs=[0-9]* live_index=[0-9]*' "$T/gdb.out" | tail -1)
np=$(sed -n 's/.*procs=\([0-9]*\).*/\1/p' <<< "$st"); nl=$(sed -n 's/.*live_index=\([0-9]*\).*/\1/p' <<< "$st")
if [ -z "$st" ]; then echo "⛔ REFUSED(2) [$GATE_NAME]: gdb printed no GATE-STATE line (the break at ir_delete_all never returned); tail:"; tail -5 "$T/gdb.out" | sed 's/^/         /'; exit 2
elif [ "$np" -gt 0 ] && [ "$nl" = 0 ]; then echo "  ok   (state) after ir_delete_all, 0 of $np procs still hold a graph index"
else echo "  FAIL (state) after ir_delete_all, $nl of $np procs still hold a graph index the freed table no longer backs"; fail=1; fi
if grep -q 'scrip: gate_probe: proc .* has no graph (bb_idx -1, ' "$T/gdb.out" && grep -q 'exited with code 02' "$T/gdb.out"; then echo "  ok   (refusal) stage2_proc_graph on an invalidated index names the reader and the proc and exits 2"
else echo "  FAIL (refusal) stage2_proc_graph did not refuse an invalidated index by name with exit code 2; gdb said:"; grep -E 'gate_probe|exited|No symbol' "$T/gdb.out" | head -3 | sed 's/^/         /'; fail=1; fi
( cd "$T" && timeout -k 5 60 "$SCRIP" w.pl < /dev/null > w.m3 2> /dev/null ); rc3=$?
if [ "$rc3" = 0 ] && cmp -s "$T/w.m3" "$T/w.ref"; then echo "  ok   (m3) a clause asserted after load calls static predicates and answers as swipl"
else echo "  FAIL (m3) rc=$rc3, first difference:"; diff "$T/w.ref" "$T/w.m3" | head -4 | sed 's/^/         /'; fail=1; fi
if ( cd "$T" && "$SCRIP" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -o w.bin w.s -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" 2> /dev/null ); then
    ( cd "$T" && timeout -k 5 60 ./w.bin < /dev/null > w.m4 2> /dev/null ); rc4=$?
    if [ "$rc4" = 0 ] && cmp -s "$T/w.m4" "$T/w.ref"; then echo "  ok   (m4) the same, from the standalone build"
    else echo "  FAIL (m4) rc=$rc4, first difference:"; diff "$T/w.ref" "$T/w.m4" | head -4 | sed 's/^/         /'; fail=1; fi
else echo "  FAIL (m4) the witness did not compile or link in mode 4"; fail=1; fi
if bash "$HERE/test_smoke_raku.sh" > "$T/smoke_raku.log" 2>&1; then echo "  ok   (raku smoke) green -- the by-name method dispatch asks the registry, not the index"
else echo "  FAIL (raku smoke) rc=$?:"; grep -E 'FAIL\]|^mode-' "$T/smoke_raku.log" | head -4 | sed 's/^/         /'; fail=1; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: ir_delete_all leaves no static graph index behind, a read of one refuses by name, and the witness answers as swipl"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
