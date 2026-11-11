#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_modules_that_import_each_other_load_once_as_swipl.sh -- three module files that each import the other two by a bare name load
# once each, as swipl loads them (the grader 2026-11-11, found on CHAT-80's first reading through the grade runner: its seven modules world0,
# aggreg, border, cities, contai, countr and rivers import each other, SCRIP loaded them again at every use_module and the entry
# prolog/chat80/chat of the suite chat80 read HANG at its limit and at twice its limit, the grader's memory scope at 4878 MB; row
# prolog-modules-that-import-each-other-are-loaded-again-at-every-use-module).
#
# THE WITNESS (four files in scratch; the answer is cut from swipl -q through util_oracle.sh at every run, never stored):
#   a.pl  :- module(a, [a_says/0]).  :- use_module(b, [b_says/0]).  :- use_module(c, [c_says/0]).
#         :- initialization((write(loaded_a), nl)).  a_says :- write(a_says), nl.          b.pl and c.pl the same, each importing the other two
#   main.pl  :- use_module(a).  :- initialization(main, main).  main :- a_says, b:b_says, c:c_says.
# (main ends the run, so the oracle's top level adds no line of its own; a chain with no cycle, a importing b, is byte for byte swipl's on
# SCRIP c92240c7d: the green sibling.) swipl prints loaded_c, loaded_b, loaded_a, a_says, b_says, c_says and exits 0, nothing on standard error. MEASURED at SCRIP c92240c7d:
# scrip prints nothing, exits 1, and standard error holds 65,538 lines of the form [a.pl:2: include: cannot read 'b'], each of the six
# use_module lines about 10,922 times. MODE 3 (scrip --run --dialect=swi), the mode the test suite grade system reads today.
# EXIT: 0 SCRIP's stdout and exit status are swipl's, 1 they differ, 2 REFUSED (no binary, no oracle, the oracle gave no answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=pl_modules_that_import_each_other_load_once_as_swipl
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)/scrip"
[ -x "$SCRIP" ] || { echo "REFUSE(2) [$NAME]: no scrip binary at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
SW="$(swipl_bin 2>/dev/null)"; [ -n "$SW" ] && [ -x "$SW" ] || { echo "REFUSE(2) [$NAME]: no Prolog oracle (swipl_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_pl_cycle.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/w"
for m in a b c; do
    {
        printf ':- module(%s, [%s_says/0]).\n' "$m" "$m"
        for x in a b c; do [ "$x" = "$m" ] || printf ':- use_module(%s, [%s_says/0]).\n' "$x" "$x"; done
        printf ':- initialization((write(loaded_%s), nl)).\n%s_says :- write(%s_says), nl.\n' "$m" "$m" "$m"
    } > "$T/w/$m.pl"
done
printf ':- use_module(a).\n:- initialization(main, main).\nmain :- a_says, b:b_says, c:c_says.\n' > "$T/w/main.pl"
cd "$T/w" || { echo "REFUSE(2) [$NAME]: cannot enter the scratch directory"; exit 2; }
bash "$HERE/util_oracle.sh" swipl --timeout 60 --no-cache -- -q main.pl > "$T/want.out" 2> "$T/want.err" < /dev/null; wrc=$?
[ "$wrc" = 0 ] && [ "$(grep -c '^loaded_[abc]$' "$T/want.out")" = 3 ] && [ "$(grep -c '^[abc]_says$' "$T/want.out")" = 3 ] \
    || { echo "REFUSE(2) [$NAME]: the oracle did not answer the witness (rc $wrc): $(head -c 200 "$T/want.err" | tr '\n' ' ')"; exit 2; }
timeout -k 5 120 bash "$HERE/util_run_slot.sh" "$SCRIP" --run --dialect=swi main.pl > "$T/got.out" 2> "$T/got.err" < /dev/null; grc=$?
same=no; cmp -s "$T/want.out" "$T/got.out" && [ "$grc" = "$wrc" ] && same=yes
echo "PL_MODULE_CYCLE_BOARD mode=m3 oracle_rc=$wrc scrip_rc=$grc stdout_same=$(cmp -s "$T/want.out" "$T/got.out" && echo 1 || echo 0) scrip_stderr_lines=$(wc -l < "$T/got.err") (tree $(git -C "$(dirname "$SCRIP")" rev-parse --short HEAD 2>/dev/null))"
[ "$same" = yes ] && { echo "GATE OK [$NAME]: three modules that import each other load once each, as swipl"; exit 0; }
echo "GATE FAIL [$NAME]: swipl prints three loaded_ lines and three _says lines, exit 0; scrip exit $grc, stdout [$(head -c 120 "$T/got.out" | tr '\n' '|')], stderr [$(head -c 160 "$T/got.err" | tr '\n' '|')]"; exit 1
