#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_use_module_of_a_slash_term_file_loads_the_module_as_swipl.sh -- :- use_module(sub/m, [hello/0]). loads the file sub/m.pl beside
# the loading file, as swipl does (the grader 2026-11-11, found on CHAT-80's first reading through the grade runner: its loader prolog/chat80.pl
# names its six modules use_module(chat80/chattop, [...]), SCRIP loaded none of them, and the entry prolog/chat80 of the suite chat80 read FAIL
# with existence_error(procedure, chattop:ed/3); row prolog-use-module-of-a-slash-term-file-loads-nothing).
#
# THE WITNESS (two files in scratch; the answer is cut from swipl -q through util_oracle.sh at every run, never stored):
#   sub/m.pl   :- module(m, [hello/0]).   hello :- write(hello_from_m), nl.
#   main.pl    :- use_module(sub/m, [hello/0]).   :- initialization(main, main).   main :- hello, m:hello.
# swipl prints hello_from_m twice and exits 0 (main ends the run, so the oracle's top level adds no line of its own; the same witness with
# use_module(m, [hello/0]) and m.pl beside main.pl is byte for byte swipl's on SCRIP c92240c7d: the green sibling). MODE 3 (scrip --run --dialect=swi), the mode the test suite grade system reads today.
# EXIT: 0 SCRIP's stdout and exit status are swipl's, 1 they differ, 2 REFUSED (no binary, no oracle, the oracle gave no answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=pl_use_module_of_a_slash_term_file_loads_the_module_as_swipl
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)/scrip"
[ -x "$SCRIP" ] || { echo "REFUSE(2) [$NAME]: no scrip binary at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
SW="$(swipl_bin 2>/dev/null)"; [ -n "$SW" ] && [ -x "$SW" ] || { echo "REFUSE(2) [$NAME]: no Prolog oracle (swipl_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_pl_slash.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/w/sub"
printf ':- module(m, [hello/0]).\nhello :- write(hello_from_m), nl.\n' > "$T/w/sub/m.pl"
printf ':- use_module(sub/m, [hello/0]).\n:- initialization(main, main).\nmain :- hello, m:hello.\n' > "$T/w/main.pl"
cd "$T/w" || { echo "REFUSE(2) [$NAME]: cannot enter the scratch directory"; exit 2; }
bash "$HERE/util_oracle.sh" swipl --timeout 60 --no-cache -- -q main.pl > "$T/want.out" 2> "$T/want.err" < /dev/null; wrc=$?
[ "$wrc" = 0 ] && [ "$(grep -c '^hello_from_m$' "$T/want.out")" = 2 ] || { echo "REFUSE(2) [$NAME]: the oracle did not answer the witness (rc $wrc): $(head -c 200 "$T/want.err" | tr '\n' ' ')"; exit 2; }
timeout -k 5 120 bash "$HERE/util_run_slot.sh" "$SCRIP" --run --dialect=swi main.pl > "$T/got.out" 2> "$T/got.err" < /dev/null; grc=$?
same=no; cmp -s "$T/want.out" "$T/got.out" && [ "$grc" = "$wrc" ] && same=yes
echo "PL_USE_MODULE_SLASH_TERM_BOARD mode=m3 oracle_rc=$wrc scrip_rc=$grc stdout_same=$(cmp -s "$T/want.out" "$T/got.out" && echo 1 || echo 0) (tree $(git -C "$(dirname "$SCRIP")" rev-parse --short HEAD 2>/dev/null))"
[ "$same" = yes ] && { echo "GATE OK [$NAME]: use_module of a slash-term file loads the module, as swipl"; exit 0; }
echo "GATE FAIL [$NAME]: swipl prints hello_from_m twice, exit 0; scrip exit $grc, stdout [$(head -c 120 "$T/got.out" | tr '\n' '|')], stderr [$(head -c 200 "$T/got.err" | tr '\n' '|')]"; exit 1
