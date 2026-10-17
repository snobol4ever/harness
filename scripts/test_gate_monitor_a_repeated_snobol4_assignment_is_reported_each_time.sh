#!/usr/bin/env bash
# test_gate_monitor_a_repeated_snobol4_assignment_is_reported_each_time.sh -- under the IPC sync-step monitor, a SNOBOL4 statement that
# assigns one variable the same value twice (an immediate $ capture re-run by a later alternative) reports the assignment each time, as
# the SPITBOL fork does, while Pascal's double-tap -- ONE store of a program-level variable reported by comm_var AND by the injected
# __trace_value call -- still reaches the wire once.
#
# ⛔ THE DEFECT (the next first divergence of the bracket over parser_snocone.sno on library/counter.sc, step 2836, after fc7052c6b):
# rt_trace_value dropped any VALUE whose name and spelled value equal the previous report in the same statement (8b98ce17f, written
# for Pascal's double-tap). The parser's keyword patterns ($' ' (Id $ tx) *IDENT(tx,'break') ...) re-run Id $ tx on the same word in
# each alternative, so spl sent tx = 'struct' twice and scr once, and the bracket read DIVERGE.
# THE CURE: the collapse holds only when the two reports come from DIFFERENT hooks (the one-character source prefix kept in the
# existing last-name buffer: '0' comm_var/sno_trace_value, '1' the __trace_value call) -- the double-tap, never a repeated store.
# With it the bracket over parser_snocone.sno on counter.sc runs clean to step 243885, AGREE=232600 DIVERGE=0.
#
# THE ARMS (monitor_run.sh --oracle, AGREE with DIVERGE=0):
#   1  SNOBOL4: 'struct x' ? (id $ tx 'q' | id $ tx 'z' | id $ tx) -- tx = 'struct' three times               -- RED on base
#   2  CONTROL Pascal against fpx: a program-level variable stored twice (the double-tap still collapses)
#   3  CONTROL Pascal --trace: exactly two 'total =' reports for two stores (neither doubled nor dropped)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
NAME=monitor_a_repeated_snobol4_assignment_is_reported_each_time
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$HERE/monitor_run.sh" ] || refuse "no monitor_run.sh"
[ -x /home/resources/x64/bin/sbl ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf '%s\n' "        id = SPAN(&LCASE)" "        'struct x' ? (id \$ tx 'q' | id \$ tx 'z' | id \$ tx)" "        OUTPUT = tx" "END" > "$T/twice.sno"
printf '%s\n' 'program g;' 'var total: integer;' 'begin' '  total := 1;' '  total := total + 1;' '  writeln(total)' 'end.' > "$T/global.pas"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
mon() { ( cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" "$1" --oracle > "$1.mon" 2>&1 ); local r=$?
    [ "$r" = 2 ] && refuse "the monitor could not measure $1: $(grep -m1 -E 'REFUSE|DIVERGE' "$T/$1.mon" | cut -c1-160)"
    local v; v=$(grep -o 'AGREE=[0-9]* DIVERGE=[0-9]* UNGRADED=[0-9]*' "$T/$1.mon" | tail -1)
    [ "$r" = 0 ] && printf '%s' "$v" | grep -q 'DIVERGE=0 ' && echo ok || echo "rc=$r [$v] $(grep -m1 '^| \*\*>' "$T/$1.mon" | cut -c1-140)"; }
arm "SNOBOL4: one statement assigns tx = 'struct' three times" "$(mon twice.sno)"
arm "CONTROL Pascal against fpx: a program-level variable stored twice" "$(mon global.pas)"
c=$( (cd "$T" && timeout -k 5 60 bash "$HERE/monitor_run.sh" global.pas --trace 2>&1) | grep -c 'total = ')
arm "CONTROL Pascal --trace: two stores, two reports" "$([ "$c" = 2 ] && echo ok || echo "got $c 'total =' reports, want 2")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
