#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_an_xsb_collection_by_xsb.sh -- util_build_package_suite.py --mine has an XSB arm (the grader 2026-11-11; COO-508,
# CIO-92, row mining-a-test-suite-from-xsb-examples: XSB's own examples are read in place): under --lang prolog --mine-dialects xsb the
# collection's .P files are the programs, the oracle is xsb through util_oracle.sh (consult the program and halt, the form the fleet's XSB
# gates use), a row's dialect cell is xsb and its language cell prolog, and a .pl file beside them is no program of this census. The
# in-place form itself is test_gate_builder_mines_a_collection_in_place.sh's.
#
# MEASURED 2026-11-11 (xsb 5.0.0): a program consulted by xsb -e does not see standard input (get_char answers -1 and read answers
# end_of_file whatever standard input holds), so under this arm no program reads NEEDS-INPUT; the gate plants none.
#
# THE ARMS (a scratch XSB collection of three .P programs and one .pl, the oracle xsb; about 9 oracle runs):
#   1  the census names each planted verdict: ENTRY (a directive that writes a line; one that reads a data file beside it), NO-OUTPUT
#      (facts alone: nothing runs at load); the .pl file has no line
#   2  the package holds ALL.source, ALL.csv, ALL.omit and the two NAME.out, each the oracle's bytes; both rows' language cell is prolog
#      and dialect cell xsb; no program file and no .xwam is in the package, and none is left in the collection
#   3  the census's header names xsb
#   4  the one grader reads the mined package in mode 3: both entries are graded and pass
#   5  without --mine-dialects the same collection is read by swipl as before: its one .pl program is the census
#   6  a package whose ALL.launch says oracle around - drive.P (and scrip around - drive.P): xsb consults each program and then the package's
#      own driver, which calls the program's demo/0: a program that defines demo and runs nothing is NO-OUTPUT without the launch and an
#      ENTRY with it, its answer the driver's lines; the package gains no file (no .xwam beside the driver), the collection is as it was,
#      and the one grader passes the entry in mode 3 (Lon 2026-11-11: "Make drivers for library ones")
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_an_xsb_collection_by_xsb
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
XB="$(xsb_bin 2>/dev/null)"; [ -n "$XB" ] && [ -x "$XB" ] || { echo "REFUSE(2) [$NAME]: no XSB oracle (xsb_bin)"; exit 2; }
SW="$(swipl_bin 2>/dev/null)"; [ -n "$SW" ] && [ -x "$SW" ] || { echo "REFUSE(2) [$NAME]: no SWI oracle (swipl_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine_xsb.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C/sub" "$P"
printf ':- writeln(plain).\n' > "$C/plain.P"
printf ':- open('"'"'beside.txt'"'"', read, S), read(S, X), close(S), writeln(X).\n' > "$C/sub/beside.P"
printf 'beside_term.\n' > "$C/sub/beside.txt"
printf 'p(1).\np(2).\n' > "$C/quiet.P"
printf ':- initialization(main).\nmain :- writeln(swi).\n' > "$C/other.pl"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
snap() { (cd "$1" && find . -type f | sort | while read -r f; do printf '%s %s\n' "$(sha256sum < "$f" | cut -c1-16)" "$f"; done); }
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
snap "$C" > "$T/coll.before"
timeout -k 5 900 python3 "$B" "$P" --lang prolog --mine "$T/census.tsv" --mine-cap 30 --mine-dialects xsb > "$T/1.log" 2>&1; r1=$?
want="plain.P ENTRY
quiet.P NO-OUTPUT
sub/beside.P ENTRY"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort)"
[ "$r1" = 0 ] && [ "$got" = "$want" ] && ck ok "(1) the census names each planted verdict and no .pl file" || ck no "(1) rc=$r1 the census read: $(printf '%s' "$got" | tr '\n' ';') :: $(tail -1 "$T/1.log" | cut -c1-160)"
files="$(cd "$P" && find . -type f | sort | tr '\n' ' ')"
col() { python3 -c 'import csv,sys; print(" ".join(r.get(sys.argv[2], "-") or "-" for r in csv.DictReader(open(sys.argv[1], newline=""))))' "$P/ALL.csv" "$1" 2>/dev/null; }
snap "$C" > "$T/coll.after"
[ "$files" = "./ALL.csv ./ALL.omit ./ALL.source ./plain.out ./sub/beside.out " ] && [ "$(cat "$P/plain.out")" = plain ] && [ "$(cat "$P/sub/beside.out")" = beside_term ] \
  && [ "$(col path)" = "plain.P sub/beside.P" ] && [ "$(col language)" = "prolog prolog" ] && [ "$(col dialect)" = "xsb xsb" ] && cmp -s "$T/coll.before" "$T/coll.after" \
  && ck ok "(2) the package holds the index and two answers, each row is prolog in the dialect xsb, no program, and the collection is as it was" \
  || ck no "(2) files=[$files] path=[$(col path)] language=[$(col language)] dialect=[$(col dialect)] collection: $(diff "$T/coll.before" "$T/coll.after" | head -2 | tr '\n' ';')"
head -1 "$T/census.tsv" 2>/dev/null | grep -q ' by xsb (' && ck ok "(3) the census's header names xsb" || ck no "(3) header=[$(head -1 "$T/census.tsv" 2>/dev/null | cut -c1-120)]"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of two programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.pl" "$P/ALL.ref" --lang prolog --modes m3 > "$T/4.log" 2>&1 < /dev/null; r4=$?
board="$(grep -E '^SUITE_BOARD ' "$T/4.log" | tail -1)"
n4="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p4="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r4" = 0 ] && [ "${n4:-0}" = 2 ] && [ "${p4:-0}" = 2 ] \
  && ck ok "(4) the grader reads the mined package in mode 3 and both entries pass" \
  || ck no "(4) rc=$r4 board=[$(printf '%s' "$board" | cut -c1-120)] :: $(tail -1 "$T/4.log" | cut -c1-160)"
P2="$T/pkg/mined_swi"; mkdir -p "$P2"; cp "$P/ALL.source" "$P2/ALL.source"
timeout -k 5 900 python3 "$B" "$P2" --lang prolog --mine "$T/census5.tsv" --mine-cap 30 > "$T/5.log" 2>&1; r5=$?
got5="$(grep -v '^#' "$T/census5.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort | tr '\n' ';')"
[ "$r5" = 0 ] && [ "$got5" = "other.pl ENTRY;" ] && [ "$(cat "$P2/other.out" 2>/dev/null)" = swi ] && head -1 "$T/census5.tsv" | grep -q ' by swipl (' \
  && ck ok "(5) without --mine-dialects the collection is read by swipl as before" || ck no "(5) rc=$r5 census=[$got5] :: $(tail -1 "$T/5.log" | cut -c1-160)"
C6="$T/coll6"; P6="$T/pkg/launched"; P7="$T/pkg/unlaunched"; mkdir -p "$C6" "$P6" "$P7"
printf 'demo :- writeln(demo_ran).\n' > "$C6/withdemo.P"
printf 'p(1).\n' > "$C6/nodemo.P"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C6" > "$P6/ALL.source"; cp "$P6/ALL.source" "$P7/ALL.source"
printf 'gx_entry(G) :- current_predicate(G/0), !, write(calls), write(0), nl, ( call(G) -> R = yes ; R = no ), write(ended), write(R), nl.\ngx_entry(_).\n:- gx_entry(demo).\n' > "$P6/drive.P"
printf 'scrip\taround\t-\tdrive.P\noracle\taround\t-\tdrive.P\n' > "$P6/ALL.launch"
snap "$C6" > "$T/coll6.before"
timeout -k 5 900 python3 "$B" "$P7" --lang prolog --mine "$T/census7.tsv" --mine-cap 30 --mine-dialects xsb > "$T/7.log" 2>&1; r7=$?
timeout -k 5 900 python3 "$B" "$P6" --lang prolog --mine "$T/census6.tsv" --mine-cap 30 --mine-dialects xsb > "$T/6.log" 2>&1; r6=$?
snap "$C6" > "$T/coll6.after"
got7="$(grep -v '^#' "$T/census7.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort | tr '\n' ';')"
got6="$(grep -v '^#' "$T/census6.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort | tr '\n' ';')"
files6="$(cd "$P6" && find . -type f | sort | tr '\n' ' ')"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and a launched package of one program, not a board" S4E_PROGRESS_DB="$T/progress6.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P6/ALL.pl" "$P6/ALL.ref" --lang prolog --modes m3 > "$T/6g.log" 2>&1 < /dev/null; r6g=$?
board6="$(grep -E '^SUITE_BOARD ' "$T/6g.log" | tail -1)"
n6="$(printf '%s' "$board6" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p6="$(printf '%s' "$board6" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r7" = 0 ] && [ "$got7" = "nodemo.P NO-OUTPUT;withdemo.P NO-OUTPUT;" ] && [ "$r6" = 0 ] && [ "$got6" = "nodemo.P NO-OUTPUT;withdemo.P ENTRY;" ] \
  && [ "$(cat "$P6/withdemo.out" 2>/dev/null)" = "$(printf 'calls0\ndemo_ran\nendedyes')" ] && [ "$files6" = "./ALL.csv ./ALL.launch ./ALL.omit ./ALL.source ./drive.P ./withdemo.out " ] \
  && cmp -s "$T/coll6.before" "$T/coll6.after" && [ "$r6g" = 0 ] && [ "${n6:-0}" = 1 ] && [ "${p6:-0}" = 1 ] \
  && ck ok "(6) with oracle around - drive.P a program that only defines demo is an entry answered through the driver, graded, and nothing is left beside the driver" \
  || ck no "(6) unlaunched rc=$r7 [$got7] launched rc=$r6 [$got6] out=[$(head -c 60 "$P6/withdemo.out" 2>/dev/null | tr '\n' '|')] files=[$files6] grader rc=$r6g n=${n6:-} pass=${p6:-} :: $(tail -1 "$T/6.log" | cut -c1-140) :: $(tail -1 "$T/6g.log" | cut -c1-140)"
echo "BUILDER_MINES_XSB_BOARD arms=6 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 6 ] && { echo "GATE OK [$NAME]: an XSB collection is mined in place by xsb: census, dialect, answers"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
