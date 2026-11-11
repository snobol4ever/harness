#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_a_snobol4_collection_by_spitbol.sh -- util_build_package_suite.py --mine has a SNOBOL4 arm (the grader 2026-11-11;
# COO-508, CIO-92, CIO-101: Vanilla SNOBOL4 is read in place for good): the oracle is sbl -bf through util_oracle.sh, a program whose
# extension is not .sno carries its language, and a program SPITBOL ends with its fatal error (a line holding ERROR nnn and the footer
# in statement N, the builder's own sbl_died) reads ORACLE-REFUSES with SPITBOL's own words, never an entry. The in-place form itself is
# test_gate_builder_mines_a_collection_in_place.sh's.
#
# THE ARMS (a scratch SNOBOL4 collection of five programs, the oracle sbl; about 12 oracle runs):
#   1  the census names each planted verdict: ENTRY (a plain program, one named .spt), NEEDS-INPUT (it prints a line of standard input),
#      NO-OUTPUT, ORACLE-REFUSES (a call of an undefined function at run time: ERROR 022 and the footer, whose statistics lines move run to run)
#   2  the package holds ALL.source, ALL.csv, ALL.omit and the two NAME.out, each the oracle's bytes; the .spt row's language cell is
#      snobol4, and no program file is in the package
#   3  the refused program's line of the census holds SPITBOL's own error line
#   4  the one grader reads the mined package in mode 3: every entry is graded and passes
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_a_snobol4_collection_by_spitbol
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
SB="$(sbl_correctness_bin 2>/dev/null)"; [ -n "$SB" ] && [ -x "$SB" ] || { echo "REFUSE(2) [$NAME]: no SNOBOL4 oracle (sbl_correctness_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine_sno.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C" "$P"
printf " OUTPUT = 'plain'\nEND\n" > "$C/plain.sno"
printf " OUTPUT = 'spt'\nEND\n" > "$C/other.spt"
printf " OUTPUT = INPUT\nEND\n" > "$C/input.sno"
printf " X = 1\nEND\n" > "$C/quiet.sno"
printf " OUTPUT = 'before'\n OUTPUT = NOSUCHFUNCTION(1)\nEND\n" > "$C/refused.sno"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
timeout -k 5 900 python3 "$B" "$P" --lang snobol4 --mine "$T/census.tsv" --mine-cap 30 > "$T/1.log" 2>&1; r1=$?
want="input.sno NEEDS-INPUT
other.spt ENTRY
plain.sno ENTRY
quiet.sno NO-OUTPUT
refused.sno ORACLE-REFUSES"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort)"
[ "$r1" = 0 ] && [ "$got" = "$want" ] && ck ok "(1) the census names each planted verdict" || ck no "(1) rc=$r1 the census read: $(printf '%s' "$got" | tr '\n' ';') :: $(tail -1 "$T/1.log" | cut -c1-160)"
files="$(cd "$P" && find . -type f | sort | tr '\n' ' ')"
col() { python3 -c 'import csv,sys; print(" ".join(r.get(sys.argv[2], "-") or "-" for r in csv.DictReader(open(sys.argv[1], newline=""))))' "$P/ALL.csv" "$1" 2>/dev/null; }
[ "$files" = "./ALL.csv ./ALL.omit ./ALL.source ./other.out ./plain.out " ] && [ "$(cat "$P/plain.out")" = plain ] && [ "$(cat "$P/other.out")" = spt ] \
  && [ "$(col path)" = "other.spt plain.sno" ] && [ "$(col language)" = "snobol4 -" ] \
  && ck ok "(2) the package holds the index and two answers, the .spt row names its language, and no program" \
  || ck no "(2) files=[$files] path=[$(col path)] language=[$(col language)]"
grep -qE "^refused.sno	ORACLE-REFUSES	SPITBOL ends it with an error: refused.sno\([0-9]+\) : ERROR [0-9]+ -- " "$T/census.tsv" 2>/dev/null \
  && ck ok "(3) the refused program's census line holds SPITBOL's own error line" || ck no "(3) census=[$(grep '^refused' "$T/census.tsv" 2>/dev/null | cut -c1-160)]"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of two programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.sno" "$P/ALL.ref" --lang snobol4 --modes m3 > "$T/4.log" 2>&1 < /dev/null; r4=$?
board="$(grep -E '^SUITE_BOARD ' "$T/4.log" | tail -1)"
n4="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p4="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r4" = 0 ] && [ "${n4:-0}" = 2 ] && [ "${p4:-0}" = 2 ] \
  && ck ok "(4) the grader reads the mined package in mode 3 and both entries pass" \
  || ck no "(4) rc=$r4 board=[$(printf '%s' "$board" | cut -c1-120)] :: $(tail -1 "$T/4.log" | cut -c1-160)"
echo "BUILDER_MINES_SNOBOL4_BOARD arms=4 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 4 ] && { echo "GATE OK [$NAME]: a SNOBOL4 collection is mined in place by SPITBOL: census, language, answers"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
