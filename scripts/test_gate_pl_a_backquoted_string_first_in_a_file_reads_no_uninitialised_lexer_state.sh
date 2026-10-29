#!/bin/bash
# test_gate_pl_a_backquoted_string_first_in_a_file_reads_no_uninitialised_lexer_state.sh
# -- THE PROLOG LEXER'S STRING-PIECE STATE IS INITIALISED (ceo CEO-1959, hq_packages; SWI core/test_unicode.pl died on signal 11 and lost all ten of its cases). prolog_lex.c scanned a single- or double-quoted
# token with lx->slen, lx->run0 and lx->pc reset, but a BACKQUOTED token reset only slen, and lexer_init set none of run0 or pc: the first backquoted string of a file read the Parser's uninitialised stack
# (pc_flush handed pc_piece a length of 327,768,084 and ct_strndup walked off the end), so the crash followed the stack's contents -- core/test_unicode.pl died under the declared arena -d131072k -s4096k and passed
# without it, a prefix of its numbers unit died while longer ones lived, and the same program passed from another directory. A fault that follows stack garbage cannot be witnessed by waiting for a crash, so THE WITNESS IS
# VALGRIND: a one-clause file whose first quoted token is a backquoted string, compiled (the parser and lowerer run in this process) under valgrind -q --error-exitcode=99; memcheck reports an uninitialised
# conditional jump at pc_flush (prolog_lex.c:93) whatever the stack holds, deterministically. Measured: 238 reports, rc 99, on the parent of the cure; none, rc 0, with it.
# rc 0 clean; rc 1 valgrind reported (the first report is printed); rc 2 cannot measure (no ./scrip or no valgrind).
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
[ -x ./scrip ] || { echo "REFUSE(2): no ./scrip -- run make -j8 in SCRIP"; exit 2; }
command -v valgrind > /dev/null 2>&1 || { echo "REFUSE(2): valgrind is not installed"; exit 2; }
T="$HERE/../../.scratch/lxi-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
printf 'p(`abc`).\n' > "$T/bq.pl"
timeout -k 5 300 valgrind -q --error-exitcode=99 ./scrip --compile --out="$T/bq.s" "$T/bq.pl" < /dev/null > "$T/o.txt" 2> "$T/vg.txt"; rc=$?
if [ $rc -eq 0 ]; then echo "GATE OK -- a file whose first quoted token is a backquoted string compiles clean under valgrind (rc 0)"; exit 0; fi
echo "GATE FAIL -- valgrind rc=$rc reading a file whose first quoted token is a backquoted string; the first report:"
grep -m3 -E '==[0-9]+== +(Conditional|Use of|Invalid|at 0x|by 0x)' "$T/vg.txt" | cut -c1-160
exit 1
