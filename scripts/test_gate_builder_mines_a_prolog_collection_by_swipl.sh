#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_a_prolog_collection_by_swipl.sh -- util_build_package_suite.py --mine has a Prolog arm (the grader 2026-11-11; COO-508,
# CIO-92, CIO-122; Lon 2026-11-11: "Its time to get ALL new test suites graded and plugged into the new test grade runner."): the oracle is
# swipl -q through util_oracle.sh, a mined row's dialect cell is swi (the oracle that cut its answer, so SCRIP reads the program as SWI), a
# program whose extension is not .pl carries its language, and --mine-skip names the programs another package grades already: each reads
# HELD-ELSEWHERE in the census, is not run, is no entry and is not in ALL.omit. The Raku arms and the in-place form itself are
# test_gate_builder_mines_a_collection_in_place.sh's.
#
# THE ARMS (a scratch Prolog collection of eight programs, the oracle swipl; about 20 oracle runs):
#   1  the census names each planted verdict: ENTRY (a plain program, one named .pro, one that reads a file beside it), NEEDS-INPUT,
#      NO-OUTPUT, DIFFERS-BETWEEN-RUNS, NEEDS-DISPLAY (the source names library(pce)), HELD-ELSEWHERE (named by the skip list)
#   2  the package holds ALL.source, ALL.csv, ALL.omit and the three NAME.out, each the oracle's bytes; every row's dialect cell is swi, the
#      .pro row's language cell is prolog, and no program file is in the package
#   3  the held program is in the census with the skip list's own words, and is neither an entry nor a line of ALL.omit
#   4  the one grader reads the mined package in mode 3: every entry is graded and passes
#   5  a skip list naming a path the collection does not hold refuses rc 2
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_a_prolog_collection_by_swipl
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
SW="$(swipl_bin 2>/dev/null)"; [ -n "$SW" ] && [ -x "$SW" ] || { echo "REFUSE(2) [$NAME]: no Prolog oracle (swipl_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine_pl.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C/sub" "$P"
printf ':- initialization(main).\nmain :- write(plain), nl.\n' > "$C/plain.pl"
printf ':- initialization(main, main).\nmain :- write(pro), nl.\n' > "$C/other.pro"
printf ":- initialization(main, main).\nmain :- open('beside.txt', read, S), read_term(S, X, []), close(S), write(X), nl.\n" > "$C/sub/beside.pl"
printf 'a_term_beside.\n' > "$C/sub/beside.txt"
printf ':- initialization(main, main).\nmain :- read(X), write(got(X)), nl.\n' > "$C/input.pl"
printf 'p(1).\n' > "$C/quiet.pl"
printf ':- initialization(main, main).\nmain :- get_time(T), write(T), nl.\n' > "$C/differs.pl"
printf ':- use_module(library(pce)).\n:- initialization(main, main).\nmain :- write(x), nl.\n' > "$C/display.pl"
printf ':- initialization(main, main).\nmain :- write(held), nl.\n' > "$C/held.pl"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
printf 'held.pl\tgraded by another package of the gate\n' > "$T/skip"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
timeout -k 5 900 python3 "$B" "$P" --lang prolog --mine "$T/census.tsv" --mine-cap 30 --mine-skip "$T/skip" > "$T/1.log" 2>&1; r1=$?
want="differs.pl DIFFERS-BETWEEN-RUNS
display.pl NEEDS-DISPLAY
held.pl HELD-ELSEWHERE
input.pl NEEDS-INPUT
other.pro ENTRY
plain.pl ENTRY
quiet.pl NO-OUTPUT
sub/beside.pl ENTRY"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort)"
[ "$r1" = 0 ] && [ "$got" = "$want" ] && ck ok "(1) the census names each planted verdict" || ck no "(1) rc=$r1 the census read: $(printf '%s' "$got" | tr '\n' ';') :: $(tail -1 "$T/1.log" | cut -c1-160)"
files="$(cd "$P" && find . -type f | sort | tr '\n' ' ')"
col() { python3 -c 'import csv,sys; print(" ".join(r.get(sys.argv[2], "-") or "-" for r in csv.DictReader(open(sys.argv[1], newline=""))))' "$P/ALL.csv" "$1" 2>/dev/null; }
[ "$files" = "./ALL.csv ./ALL.omit ./ALL.source ./other.out ./plain.out ./sub/beside.out " ] && [ "$(cat "$P/plain.out")" = plain ] && [ "$(cat "$P/sub/beside.out")" = a_term_beside ] \
  && [ "$(col path)" = "other.pro plain.pl sub/beside.pl" ] && [ "$(col dialect)" = "swi swi swi" ] && [ "$(col language)" = "prolog - -" ] \
  && ck ok "(2) the package holds the index and three answers, every dialect cell is swi, the .pro row names its language, and no program" \
  || ck no "(2) files=[$files] path=[$(col path)] dialect=[$(col dialect)] language=[$(col language)]"
grep -q "^held.pl	HELD-ELSEWHERE	graded by another package of the gate$" "$T/census.tsv" 2>/dev/null && ! grep -q '^held' "$P/ALL.omit" 2>/dev/null && [ "$(grep -c . "$P/ALL.omit" 2>/dev/null)" = 4 ] \
  && ! grep -q 'held' "$P/ALL.csv" 2>/dev/null && [ -s "$P/ALL.csv" ] && grep -q '^MINE_HELD .* held_elsewhere=1 ' "$T/1.log" \
  && ck ok "(3) the held program is in the census in the skip list's words, no entry and no line of ALL.omit" \
  || ck no "(3) census=[$(grep '^held' "$T/census.tsv" 2>/dev/null | cut -c1-80)] omit=[$(tr '\n' ';' < "$P/ALL.omit" 2>/dev/null | cut -c1-200)]"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of three programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.pl" "$P/ALL.ref" --lang prolog --modes m3 > "$T/4.log" 2>&1 < /dev/null; r4=$?
board="$(grep -E '^SUITE_BOARD ' "$T/4.log" | tail -1)"
n4="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p4="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r4" = 0 ] && [ "${n4:-0}" = 3 ] && [ "${p4:-0}" = 3 ] \
  && ck ok "(4) the grader reads the mined package in mode 3 and all three entries pass" \
  || ck no "(4) rc=$r4 board=[$(printf '%s' "$board" | cut -c1-120)] :: $(tail -1 "$T/4.log" | cut -c1-160)"
printf 'no_such_program.pl\tgraded nowhere\n' > "$T/skip_bad"
timeout -k 5 300 python3 "$B" "$P" --lang prolog --mine "$T/census5.tsv" --mine-cap 30 --mine-skip "$T/skip_bad" > "$T/5.log" 2>&1; r5=$?
[ "$r5" = 2 ] && [ ! -e "$T/census5.tsv" ] && ck ok "(5) a skip list naming a path the collection does not hold refuses rc 2" || ck no "(5) rc=$r5 :: $(tail -1 "$T/5.log" | cut -c1-160)"
echo "BUILDER_MINES_PROLOG_BOARD arms=5 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 5 ] && { echo "GATE OK [$NAME]: a Prolog collection is mined in place by swipl: census, dialect, skip list, answers"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
