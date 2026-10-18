#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_an_assignment_to_a_value_raises_111_at_run_time_instead_of_aborting.sh -- AN ASSIGNMENT WHOSE TARGET
# IS A VALUE IS RUN-TIME ERROR 111 IN ICON, NEVER A COMPILE-TIME ABORT AND NEVER A RUNTIME BOMB.
# Row icon-an-augmented-assignment-to-a-comparison-aborts-at-the-binop-guard-instead-of-raising-111-at-run-time
# (cto, 2026-09-12), from the coo's IPL compile-tier report: gprogs/fev.icn aborted rc=134 under the runner's ICONPATH
#   FATAL emit_drive: IR op=3 HAS a template and its own case REFUSED AT A GUARD -- emit.cpp:1572
# on main's `(1 < focuswidth) -:= 1`. A comparison yields a VALUE (iconx: 111 "variable expected, offending value: 5"),
# and TT_AUGOP's fallback for such a target built an IR_BINOP and never pushed its operands. The cure routes the
# target through IR_ASSIGN_VAR exactly as plain assignment does, and the variable-assign sink raises 111 through
# core_icn_error instead of the "[IDX] BOMB rt_assign_var" abort -- which is why `f() := 3` (plain, call target) is
# an arm here too: the sink half is its own defect and the same class.
#
# Every expectation is PINNED from Arizona icont/iconx 9.5 (/home/resources/icon-master), measured 2026-09-12; the
# gate is hermetic and never consults the oracle at run time. stderr is filtered to the three lines iconx and scrip
# both print (error number, message, offending value); the traceback frame text is not graded here.
#
# ⛔ g02/g07/g08 ARE THE LOAD-BEARING CONTROLS: g02 is the same comparison target when the comparison FAILS (the whole
# expression fails silently, x stays 0 -- a cure that raised 111 eagerly would move it); g07 is a plain variable
# target and g08 a subscript target, the two lvalue paths the fallback must never capture.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
GATE_NAME="an_assignment_to_a_value_raises_111_at_run_time_instead_of_aborting"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: scrip not built at $SCRIP"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: $RT/libscrip_rt.so missing -- mode 4 cannot link"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not on PATH -- mode 4 cannot link"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_asg111.XXXXXX")" || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
gate_bin_watch "$SCRIP" "$RT/libscrip_rt.so"

E111='Run-time error 111|variable expected|offending value: '
probe() { printf '%s\n' "$3" > "$W/$1.icn"; printf '%s' "$2" > "$W/$1.want"; }
probe g01_cmp_target      "${E111}5"   'procedure main(); local x; x := 5; (1 < x) -:= 1; write(x); end'
probe g02_cmp_fails_ctl   '0'          'procedure main(); local x; x := 0; (1 < x) -:= 1; write(x); end'
probe g03_arith_target    "${E111}6"   'procedure main(); local x; x := 5; (x + 1) +:= 2; write(x); end'
probe g04_literal_target  "${E111}5"   'procedure main(); 5 +:= 1; write("after"); end'
probe g05_call_target_aug "${E111}5"   'procedure f(); return 5; end
procedure main(); f() +:= 3; write("after"); end'
probe g06_call_target_asg "${E111}5"   'procedure f(); return 5; end
procedure main(); f() := 3; write("after"); end'
probe g07_var_target_ctl  '4'          'procedure main(); local x; x := 5; x -:= 1; write(x); end'
probe g08_idx_target_ctl  '2'          'procedure main(); local L; L := [1]; L[1] +:= 1; write(L[1]); end'

filt() { python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon | grep -a 'Run-time error 111\|variable expected\|offending value\|^[^ ]' | grep -a -v '^Traceback\|^main()\|^File \|from line' | tr '\n' '|' | sed 's/|$//'; }
red=0; n=0
for src in "$W"/g*.icn; do
    b="$(basename "$src" .icn)"; want="$(cat "$W/$b.want")"; n=$((n+1))
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$b.icn" </dev/null 2>&1 | filt)"
    m4="(compile/link failed)"
    if (cd "$W" && "$SCRIP" --compile "$b.icn" </dev/null > "$b.s" 2>/dev/null && gcc -c "$b.s" -o "$b.o" 2>/dev/null \
        && gcc "$b.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$b.m4" 2>/dev/null); then
        m4="$(cd "$W" && timeout -k 5 20 "./$b.m4" </dev/null 2>&1 | filt)"
    fi
    v=GREEN; { [ "$m3" = "$want" ] && [ "$m4" = "$want" ]; } || { v=RED; red=$((red+1)); }
    printf '  %-20s want=%-52s m3=%-52s m4=%-52s %s\n' "$b" "[$want]" "[$m3]" "[$m4]" "$v"
done

# THE SINK ARMS: an output comparison cannot tell a folded error from an abort that happened to print the same
# words first, so each probe is also asserted never to reach the emit guard sink at compile time nor the
# rt_assign_var BOMB at run time.
for src in "$W"/g*.icn; do
    b="$(basename "$src" .icn)"; n=$((n+1)); bad=0
    err="$(cd "$W" && "$SCRIP" --compile "$b.icn" </dev/null 2>&1 >/dev/null)"; rc=$?
    if [ $rc -eq 134 ] || printf '%s' "$err" | grep -q "REFUSED AT A GUARD"; then printf '  %-20s m4 compile TRIPPED THE GUARD SINK (rc=%s) RED\n' "$b" "$rc"; bad=1; fi
    run="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$b.icn" </dev/null 2>&1)"
    if printf '%s' "$run" | grep -q "BOMB rt_assign_var\|REFUSED AT A GUARD"; then printf '  %-20s m3 run TRIPPED A SINK RED\n' "$b"; bad=1; fi
    red=$((red+bad))
done
gate_bin_unmoved
GATE_EXAMINED="$n arms ($((n/2)) probes x m3+m4 output, $((n/2)) x guard/BOMB sink absence)"
gate_floor "$n" 16 "arms run"
gate_verdict "$red" "arm(s) disagree with the pinned iconx 9.5 output or tripped a sink"
