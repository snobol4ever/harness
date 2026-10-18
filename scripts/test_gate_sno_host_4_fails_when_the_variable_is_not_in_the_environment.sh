#!/usr/bin/env bash
# test_gate_sno_host_4_fails_when_the_variable_is_not_in_the_environment.sh -- HOST(4, s) (v3.7 Appendix E, "Search environment for
# shell variable": "HOST(4, s) returns the value of environment variable s. ... The function fails if the string is not found.")
# answers as sbl -bf does in both modes: a variable that is set answers its value, one set to the empty string answers the null
# string, one that is not in the environment FAILS, and an empty name is ERROR 254 (erroneous argument for host).
#
# ⛔ THE DEFECT: HOST(4) of an unset variable SUCCEEDED with the null string, and of an empty name too -- found by hq_snocone
# 2026-10-09 as the first divergence of the monitor bracket on the parser_prolog.sc chain (pf_list = HOST(4,'PARSER_FILES'):
# spl failed the statement, scr assigned ''), which stopped every lock-step run of a bootstrap parser before its real defect.
# NO MONITOR BRACKET NEEDED: one builtin call; the monitor is what found it.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: unset, set-empty and set-value, stdout byte for byte against the oracle                  -- RED on base
#   3-4  m3 / m4: an empty name stops the program at that statement with ERROR 254, as the oracle does    -- RED on base
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_host_4_fails_when_the_variable_is_not_in_the_environment
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
unset S4E_HOST4_UNSET
export S4E_HOST4_EMPTY= S4E_HOST4_FULL=abc
printf '%s\n' "        X = HOST(4,'S4E_HOST4_UNSET')     :S(A)" "        OUTPUT = 'unset fails'      :(B)" "A       OUTPUT = 'unset succeeds [' X ']'" \
    "B       X = HOST(4,'S4E_HOST4_EMPTY')     :S(C)" "        OUTPUT = 'empty fails'      :(D)" "C       OUTPUT = 'empty succeeds [' X ']' DATATYPE(X)" \
    "D       X = HOST(4,'S4E_HOST4_FULL')      :S(E)" "        OUTPUT = 'full fails'       :(END)" "E       OUTPUT = 'full succeeds [' X ']' DATATYPE(X)" END > "$T/v.sno"
printf '%s\n' "        OUTPUT = 'before'" "        X = HOST(4,'')" "        OUTPUT = 'after'" END > "$T/e.sno"
( cd "$T" && timeout -k 5 20 "$SBL" -bf v.sno < /dev/null > v.oracle 2>&1 )
( cd "$T" && timeout -k 5 20 "$SBL" -bf e.sno < /dev/null > e.oracle 2>&1 )
grep -qx 'unset fails' "$T/v.oracle" && grep -qx 'full succeeds \[abc\]STRING' "$T/v.oracle" || refuse "the oracle's HOST(4) answers moved: [$(tr '\n' '|' < "$T/v.oracle")]"
grep -q 'ERROR 254' "$T/e.oracle" && ! grep -qx 'after' "$T/e.oracle" || refuse "the oracle's empty-name answer moved: [$(head -3 "$T/e.oracle" | tr '\n' '|')]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$T" && if [ "$2" = m3 ]; then timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null; else timeout -k 5 30 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null; fi ); }
values() { run v "$1" > "$T/v.$1" 2> /dev/null; cmp -s "$T/v.$1" "$T/v.oracle" && echo ok || echo "got [$(tr '\n' '|' < "$T/v.$1")] want [$(tr '\n' '|' < "$T/v.oracle")]"; }
empty() { run e "$1" > "$T/e.$1" 2> "$T/e.$1.err"; grep -qx before "$T/e.$1" && ! grep -qx after "$T/e.$1" && grep -q 'error 254' "$T/e.$1.err" && echo ok \
    || echo "got stdout [$(tr '\n' '|' < "$T/e.$1")] stderr [$(head -2 "$T/e.$1.err" | tr '\n' '|')] want before, no after, error 254"; }
arm "m3: HOST(4) answers a set variable, the null string for an empty one, and FAILS for an unset one" "$(values m3)"
arm "m4: HOST(4) answers a set variable, the null string for an empty one, and FAILS for an unset one" "$(values m4)"
arm "m3: HOST(4,'') is ERROR 254 and the program stops there" "$(empty m3)"
arm "m4: HOST(4,'') is ERROR 254 and the program stops there" "$(empty m4)"
[ "$fail" = 0 ] && { echo "GATE PASS [$NAME]: $n/$n arms"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
