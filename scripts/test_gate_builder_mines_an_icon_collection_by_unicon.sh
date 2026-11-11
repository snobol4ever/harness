#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_an_icon_collection_by_unicon.sh -- util_build_package_suite.py --mine has an Icon arm whose oracle is the Unicon
# translator (the coo 2026-11-11, COO-516; Lon the same morning: "get all test suites graded and plugged into new cycle runner."; for Unicon's uni
# tree): a program is translated inside the scratch copy of its own folder (unicon_oracle_run.sh --here), so a file it links from that folder is
# found; a file with no procedure main is a LIBRARY; a program the translator refuses is ORACLE-REFUSES; a mined row's dialect cell is unicon.
# The Raku arms and the in-place form itself are test_gate_builder_mines_a_collection_in_place.sh's.
#
# THE ARMS (a scratch collection of seven files, the oracle unicon; about 15 oracle runs):
#   1  the census names each planted verdict: ENTRY (a plain program, one that links a library of its folder, shipped translated as a built
#      collection ships it), LIBRARY (no main), NEEDS-INPUT,
#      NO-OUTPUT, NEEDS-DISPLAY (the source imports gui), ORACLE-REFUSES (the translator's own message in the note)
#   2  the package holds ALL.source, ALL.csv, ALL.omit and the two NAME.out, each the oracle's bytes; every row's dialect cell is unicon and
#      the collection holds the files it held before (no translator output left in it)
#   3  the one grader reads the mined package in mode 3: both entries are graded and pass
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_an_icon_collection_by_unicon
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
UN="$(unicon_bin 2>/dev/null)"; [ -n "$UN" ] && [ -x "$UN" ] || { echo "REFUSE(2) [$NAME]: no Unicon oracle (unicon_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine_icn.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C/sub" "$P"
printf 'procedure main()\n   write("plain");\nend\n' > "$C/plain.icn"
printf 'link helper\nprocedure main()\n   write(helped());\nend\n' > "$C/sub/links.icn"
printf 'procedure helped()\n   return "helped";\nend\n' > "$C/sub/helper.icn"
( cd "$C/sub" && "$UN" -s -c helper.icn > /dev/null 2>&1 ); [ -f "$C/sub/helper.u" ] || { echo "REFUSE(2) [$NAME]: unicon -c made no helper.u (a built collection ships its ucode; the gate plants it the same way)"; exit 2; }
printf 'procedure main()\n   write("got ", read() | "nothing");\nend\n' > "$C/input.icn"
printf 'procedure main()\n   local x;\n   x := 1;\nend\n' > "$C/quiet.icn"
printf 'import gui\nprocedure main()\n   write("x");\nend\n' > "$C/display.icn"
printf 'procedure main()\n   write("x" ;;; ))\nend\n' > "$C/refused.icn"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
before="$(cd "$C" && find . -type f | sort | tr '\n' ' ')"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
timeout -k 5 900 python3 "$B" "$P" --lang icon --mine "$T/census.tsv" --mine-cap 30 > "$T/1.log" 2>&1; r1=$?
want="display.icn NEEDS-DISPLAY
input.icn NEEDS-INPUT
plain.icn ENTRY
quiet.icn NO-OUTPUT
refused.icn ORACLE-REFUSES
sub/helper.icn LIBRARY
sub/links.icn ENTRY"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort)"
[ "$r1" = 0 ] && [ "$got" = "$want" ] && grep -q "^refused.icn	ORACLE-REFUSES	unicon does not translate it: " "$T/census.tsv" \
  && ck ok "(1) the census names each planted verdict, the translator's refusal in its own words" || ck no "(1) rc=$r1 the census read: $(printf '%s' "$got" | tr '\n' ';') :: $(tail -1 "$T/1.log" | cut -c1-160)"
files="$(cd "$P" && find . -type f | sort | tr '\n' ' ')"
col() { python3 -c 'import csv,sys; print(" ".join(r.get(sys.argv[2], "-") or "-" for r in csv.DictReader(open(sys.argv[1], newline=""))))' "$P/ALL.csv" "$1" 2>/dev/null; }
[ "$files" = "./ALL.csv ./ALL.omit ./ALL.source ./plain.out ./sub/links.out " ] && [ "$(cat "$P/plain.out")" = plain ] && [ "$(cat "$P/sub/links.out")" = helped ] \
  && [ "$(col path)" = "plain.icn sub/links.icn" ] && [ "$(col dialect)" = "unicon unicon" ] && [ "$(cd "$C" && find . -type f | sort | tr '\n' ' ')" = "$before" ] \
  && ck ok "(2) the package holds the index and two answers, every dialect cell is unicon, and the collection is as it was" \
  || ck no "(2) files=[$files] path=[$(col path)] dialect=[$(col dialect)] collection=[$(cd "$C" && find . -type f | sort | tr '\n' ' ')]"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of two programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.icn" "$P/ALL.ref" --lang icon --modes m3 > "$T/3.log" 2>&1 < /dev/null; r3=$?
board="$(grep -E '^SUITE_BOARD ' "$T/3.log" | tail -1)"
n3="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p3="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r3" = 0 ] && [ "${n3:-0}" = 2 ] && [ "${p3:-0}" = 2 ] \
  && ck ok "(3) the grader reads the mined package in mode 3 and both entries pass" \
  || ck no "(3) rc=$r3 board=[$(printf '%s' "$board" | cut -c1-120)] :: $(grep -E 'FAIL|CRASH|REFUSE' "$T/3.log" | head -2 | cut -c1-200 | tr '\n' ';')"
echo "BUILDER_MINES_ICON_BOARD arms=3 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 3 ] && { echo "GATE OK [$NAME]: an Icon collection is mined in place by the Unicon translator: census, dialect, answers"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
