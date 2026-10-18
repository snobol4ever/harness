#!/usr/bin/env bash
# test_gate_monitor_a_snobol4_name_starting_with_at_is_sent_as_its_value.sh -- under the IPC sync-step monitor, a SNOBOL4 variable whose
# name starts with @ or % (reachable only as $'@S', $'%T') goes on the wire with the type of the value it holds, as the SPITBOL fork sends
# it, while Raku's sigil rule -- a string-spelled @array or %hash is sent as ARRAY or TABLE -- stays on Raku's own trace call.
#
# ⛔ THE DEFECT (found on the bracket over parser_snocone.sno, whose stack library keeps its top in $'@S'; hq_snocone met it on
# parser_prolog.sno too, AGREE=2638 DIVERGE=1): rt_trace_value, the ONE shared value hook, rewrote the wire type of ANY string value
# whose variable name began with @ or % to ARRAY or TABLE -- Raku's sigil convention (3fd46dd77) applied to every language. So
# InitStack's $'@S' = '' read spl VALUE @S = STRING(0)='' against scr VALUE @S = ARRAY, and every bracket over a bootstrap parser
# stopped there. The program itself was right (DATATYPE($'@S') is STRING in both engines).
# THE CURE: the rule moves onto the call that carries it -- rt_trace_value_sigil(name, val, sigil); the __trace_value builtin (the
# trace call the Raku, Icon and Pascal lowerers emit, and only Raku names carry a sigil) passes 1, SNOBOL4's comm_var and
# sno_trace_value paths (rt_trace_value) pass 0.
#
# THE ARMS (monitor_run.sh --oracle, AGREE with DIVERGE=0):
#   1  SNOBOL4: $'@S' = '' inside a function, the parsers' InitStack                                              -- RED on base
#   2  SNOBOL4: $'@S' = '' then 'abc' at top level                                                                -- RED on base
#   3  CONTROL SNOBOL4: $'#N' the same way (never touched by the sigil rule)
#   4  CONTROL Raku against rkx: my @a assigned twice -- the sigil rule still sends the string-spelled @a as ARRAY
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=monitor_a_snobol4_name_starting_with_at_is_sent_as_its_value
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$HERE/monitor_run.sh" ] || refuse "no monitor_run.sh"
[ -x /home/resources/x64/bin/sbl ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf '%s\n' "        DEFINE('InitStack()')           :(InitStack_end)" "InitStack \$'@S' = ''                    :(RETURN)" "InitStack_end" \
    "        InitStack()" "        OUTPUT = DATATYPE(\$'@S')" "END" > "$T/infn.sno"
printf '%s\n' "        \$'@S' = ''" "        \$'@S' = 'abc'" "        OUTPUT = DATATYPE(\$'@S')" "END" > "$T/top.sno"
printf '%s\n' "        \$'#N' = ''" "        \$'#N' = 'abc'" "        OUTPUT = DATATYPE(\$'#N')" "END" > "$T/hash.sno"
printf '%s\n' 'my @a = 1, 2, 3;' 'my $s = "q";' '@a = 4, 5;' 'say @a.elems;' > "$T/sigil.raku"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
mon() { ( cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" "$1" --oracle > "$1.mon" 2>&1 ); local r=$?
    [ "$r" = 2 ] && refuse "the monitor could not measure $1: $(grep -m1 -E 'REFUSE|DIVERGE' "$T/$1.mon" | cut -c1-160)"
    local v; v=$(grep -o 'AGREE=[0-9]* DIVERGE=[0-9]* UNGRADED=[0-9]*' "$T/$1.mon" | tail -1)
    [ "$r" = 0 ] && printf '%s' "$v" | grep -q 'DIVERGE=0 ' && echo ok || echo "rc=$r [$v] $(grep -m1 '^| \*\*>' "$T/$1.mon" | cut -c1-140)"; }
arm "SNOBOL4 \$'@S' = '' inside a function (the parsers' InitStack)" "$(mon infn.sno)"
arm "SNOBOL4 \$'@S' assigned twice at top level" "$(mon top.sno)"
arm "CONTROL SNOBOL4 \$'#N' assigned twice at top level" "$(mon hash.sno)"
arm "CONTROL Raku against rkx: a string-spelled @a still goes on the wire as ARRAY" "$(mon sigil.raku)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
