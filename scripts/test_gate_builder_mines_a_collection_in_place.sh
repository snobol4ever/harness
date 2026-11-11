#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_a_collection_in_place.sh -- util_build_package_suite.py --mine builds a package whose programs are READ IN PLACE from
# the collection its ALL.source names (CIO-92, CIO-96, COO-508; Lon 2026-11-10: "we do not really need to host these sources, we just want to
# test and benchmark with them."; 2026-11-11: "Its time to get ALL new test suites graded and plugged into the new test grade runner."): the
# census gives every program of the collection one verdict by the oracle, the package gets the index and NAME.out of the ENTRY programs only,
# no program is copied into it, and the collection is never written to.
#
# THE ARMS (a scratch Raku collection of nine programs, the oracle rakudo; about 35 oracle runs):
#   0  (inside arm 1 and 2) a program that prints its environment reads READS-THE-ENVIRONMENT and no file of the package holds the canary or
#      the seat's HOME: every program runs under a scrubbed environment (COO-513 (4): an answer once held a credential)
#   1  the census names each planted verdict: ENTRY (a plain program, one that reads a data file beside it, one that writes a file in its
#      folder), NEEDS-INPUT, ORACLE-REFUSES, NO-OUTPUT, DIFFERS-BETWEEN-RUNS, LIBRARY
#   2  the package holds ALL.source, ALL.csv, the three NAME.out, each the oracle's bytes, and ALL.omit naming the six programs that are no
#      entry by their path with their verdict (the cio 2026-11-11: so nobody reads them as lost; by path, because a name without its extension
#      may be an entry's: fasta.p5.raku beside fasta.raku); the path cells are paths from the root, and no program
#      file is in the package
#   3  the collection is byte for byte what it was (the program that writes a file wrote it in a scratch copy)
#   4  the layout census reads the package with no loose file
#   5  the one grader reads the mined package in mode 3: every entry is graded and passes
#   6  a second package whose ALL.source says copy root and cwd root (CTO-591) is mined from the top of the collection: the program that reads
#      a file by its path from the top is an ENTRY there and has no output in the first package, and the one reading beside itself the reverse
#   7  with the root gone the build refuses rc 2 and leaves the package as it stood
#   8  a third package whose ALL.stdin names a file of the collection as the standard input of the program that reads it (COO-514 (3): a
#      collection that may not be copied feeds its own file by path): the program is an ENTRY there, its answer is the oracle's on that
#      file, the package holds no copy of the input, the layout census reads no loose file, the one grader passes all four entries; and an
#      ALL.stdin that feeds a program the oracle refuses makes the build refuse rc 2 with the package as it stood
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_a_collection_in_place
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
RK="$(rakudo_bin 2>/dev/null)"; [ -n "$RK" ] && [ -x "$RK" ] || { echo "REFUSE(2) [$NAME]: no Raku oracle (rakudo_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C/sub" "$P"
printf 'say "plain";\n' > "$C/plain.raku"
printf 'say "beside.txt".IO.slurp.chomp;\n' > "$C/sub/beside.raku"
printf 'a line beside\n' > "$C/sub/beside.txt"
printf 'spurt "made.txt", "x"; say "wrote";\n' > "$C/sub/writer.raku"
printf 'say $*IN.lines.elems;\n' > "$C/input.raku"
printf 'say "unclosed;\n' > "$C/refused.raku"
printf 'my $x = 1;\n' > "$C/quiet.raku"
printf 'say now.Rat;\n' > "$C/differs.raku"
printf 'unit module Lib;\nsub f is export { 1 }\n' > "$C/lib.raku"
printf 'say %%*ENV<S4E_MINE_CANARY> // %%*ENV<HOME>;\n' > "$C/envdump.raku"
printf 'say "top.txt".IO.slurp.chomp;\n' > "$C/sub/fromtop.raku"
printf 'a line at the top\n' > "$C/top.txt"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
snap() { (cd "$1" && find . -type f | sort | while read -r f; do printf '%s %s\n' "$(sha256sum < "$f" | cut -c1-16)" "$f"; done); }
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
snap "$C" > "$T/coll.before"
timeout -k 5 900 python3 "$B" "$P" --lang raku --mine "$T/census.tsv" --mine-cap 30 > "$T/1.log" 2>&1; r1=$?
want="differs.raku DIFFERS-BETWEEN-RUNS
envdump.raku READS-THE-ENVIRONMENT
input.raku NEEDS-INPUT
lib.raku LIBRARY
plain.raku ENTRY
quiet.raku NO-OUTPUT
refused.raku ORACLE-REFUSES
sub/beside.raku ENTRY
sub/fromtop.raku NO-OUTPUT
sub/writer.raku ENTRY"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort)"
[ "$got" = "$want" ] && ck ok "(1) the census names each planted verdict" || ck no "(1) the census read: $(printf '%s' "$got" | tr '\n' ';')"
files="$(cd "$P" && find . -type f | sort | tr '\n' ' ')"
[ "$files" = "./ALL.csv ./ALL.omit ./ALL.source ./plain.out ./sub/beside.out ./sub/writer.out " ] && [ "$(grep -c . "$P/ALL.omit")" = 7 ] && ! grep -r -q -e "$HOME" -e 's4e-mine-canary' "$P" && grep -q '^quiet.raku: NO-OUTPUT: ' "$P/ALL.omit" && [ "$(cat "$P/plain.out")" = plain ] \
  && [ "$(cat "$P/sub/beside.out")" = "a line beside" ] && [ "$(cut -d, -f3 "$P/ALL.csv" | tr '\n' ' ')" = "path plain.raku sub/beside.raku sub/writer.raku " ] \
  && ck ok "(2) the package holds the index and three answers, the path cells are paths from the root, and no program" \
  || ck no "(2) files=[$files] paths=[$(cut -d, -f3 "$P/ALL.csv" 2>/dev/null | tr '\n' ' ')]"
snap "$C" > "$T/coll.after"
cmp -s "$T/coll.before" "$T/coll.after" && ck ok "(3) the collection is byte for byte what it was" || ck no "(3) the collection changed: $(diff "$T/coll.before" "$T/coll.after" | head -3 | tr '\n' ';')"
lay="$(python3 "$HERE/util_package_layout_census.py" --package "$P" --check 2>&1 | tail -1)"
case "$lay" in *" loose=0"*) ck ok "(4) the layout census reads no loose file" ;; *) ck no "(4) the layout census read: $(printf '%s' "$lay" | cut -c1-160)" ;; esac
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of three programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.raku" "$P/ALL.ref" --lang raku --modes m3 > "$T/5.log" 2>&1 < /dev/null; r5=$?
board="$(grep -E '^SUITE_BOARD ' "$T/5.log" | tail -1)"
n5="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p5="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r5" = 0 ] && [ "${n5:-0}" = 3 ] && [ "${p5:-0}" = 3 ] \
  && ck ok "(5) the grader reads the mined package in mode 3 and all three entries pass" \
  || ck no "(5) rc=$r5 board=[$(printf '%s' "$board" | cut -c1-120)] :: $(tail -1 "$T/5.log" | cut -c1-160)"
P2="$T/pkg/mined_top"; mkdir -p "$P2"
{ cat "$P/ALL.source"; printf 'copy\troot\ncwd\troot\n'; } > "$P2/ALL.source"
timeout -k 5 900 python3 "$B" "$P2" --lang raku --mine "$T/census2.tsv" --mine-cap 30 --mine-under sub > "$T/6.log" 2>&1; r6=$?
got2="$(grep -v '^#' "$T/census2.tsv" 2>/dev/null | cut -f1,2 | tr '\t' ' ' | sort | tr '\n' ';')"
[ "$r6" = 0 ] && [ "$got2" = "sub/beside.raku NO-OUTPUT;sub/fromtop.raku ENTRY;sub/writer.raku ENTRY;" ] && [ "$(cat "$P2/sub/fromtop.out" 2>/dev/null)" = "a line at the top" ] \
  && ck ok "(6) under copy root and cwd root a program runs from the top of the collection" || ck no "(6) rc=$r6 census=[$got2] :: $(tail -1 "$T/6.log" | cut -c1-160)"
P3="$T/pkg/mined_fed"; mkdir -p "$P3"
cp "$P/ALL.source" "$P3/ALL.source"; printf '# the standard input of an entry: a file of the collection, by its path from the root\ninput\tsub/beside.txt\n' > "$P3/ALL.stdin"
timeout -k 5 900 python3 "$B" "$P3" --lang raku --mine "$T/census8.tsv" --mine-cap 30 > "$T/8.log" 2>&1; r8=$?
v8="$(grep -P '^input\.raku\t' "$T/census8.tsv" 2>/dev/null | cut -f2)"
lay8="$(python3 "$HERE/util_package_layout_census.py" --package "$P3" --check 2>&1 | tail -1)"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of four programs, not a board" S4E_PROGRESS_DB="$T/progress8.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P3/ALL.raku" "$P3/ALL.ref" --lang raku --modes m3 > "$T/8g.log" 2>&1 < /dev/null; r8g=$?
board8="$(grep -E '^SUITE_BOARD ' "$T/8g.log" | tail -1)"
n8="$(printf '%s' "$board8" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p8="$(printf '%s' "$board8" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
snap "$P3" > "$T/pkg3.before"; printf 'input\tsub/beside.txt\nrefused\ttop.txt\n' > "$P3/ALL.stdin"; snap "$P3" > "$T/pkg3.before"
timeout -k 5 900 python3 "$B" "$P3" --lang raku --mine "$T/census8b.tsv" --mine-cap 30 > "$T/8b.log" 2>&1; r8b=$?
snap "$P3" > "$T/pkg3.after"
[ "$r8" = 0 ] && [ "$v8" = ENTRY ] && [ "$(cat "$P3/input.out" 2>/dev/null)" = 1 ] && [ -z "$(find "$P3" -name '*.in' -o -name 'beside.txt' | head -1)" ] \
  && case "$lay8" in *" loose=0"*) true ;; *) false ;; esac && [ "$r8g" = 0 ] && [ "${n8:-0}" = 4 ] && [ "${p8:-0}" = 4 ] && [ "$r8b" = 2 ] && cmp -s "$T/pkg3.before" "$T/pkg3.after" \
  && ck ok "(8) ALL.stdin feeds a program a file of the collection by its path: an entry, graded, no copy; a fed program the oracle refuses refuses the build" \
  || ck no "(8) rc=$r8 verdict=[$v8] out=[$(head -c 40 "$P3/input.out" 2>/dev/null)] lay=[$(printf '%s' "$lay8" | cut -c1-80)] grader rc=$r8g n=${n8:-} pass=${p8:-} refusal rc=$r8b :: $(tail -1 "$T/8.log" | cut -c1-160) :: $(tail -1 "$T/8g.log" | cut -c1-160)"
snap "$P" > "$T/pkg.before"; mv "$C" "$T/coll_gone"
timeout -k 5 300 python3 "$B" "$P" --lang raku --mine "$T/census7.tsv" > "$T/7.log" 2>&1; r7=$?
snap "$P" > "$T/pkg.after"
[ "$r7" = 2 ] && cmp -s "$T/pkg.before" "$T/pkg.after" && ck ok "(7) with the root gone the build refuses and leaves the package as it stood" || ck no "(7) rc=$r7 :: $(tail -1 "$T/7.log" | cut -c1-160)"
echo "BUILDER_MINES_IN_PLACE_BOARD arms=8 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 8 ] && { echo "GATE OK [$NAME]: a collection is mined in place: census, index and answers, no program hosted"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
