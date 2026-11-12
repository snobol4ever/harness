#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_builder_mines_a_pascal_collection_by_fpc.sh -- util_build_package_suite.py --mine reads a Pascal collection in place by fpc (the coo
# 2026-11-11, COO-508; Lon: "Its time to get ALL new test suites graded and plugged into the new test grade runner."): fpc only compiles, so each
# program is compiled to a private folder and run (fpc_oracle_run.sh); the dialect is FOUND, the first mode of the ladder (iso, fpc, objfpc,
# delphi, tp, or the one --mine-dialects names) in which fpc compiles the program, and is the row's dialect cell. The in-place form itself and
# the Raku and Prolog arms are test_gate_builder_mines_a_collection_in_place.sh and test_gate_builder_mines_a_prolog_collection_by_swipl.sh.
#
# THE ARMS (a scratch collection of seven Pascal programs, about 25 compiles):
#   1  the census names each planted verdict: ENTRY (an ISO program, one only fpc's own mode compiles, one that writes a file in its folder),
#      LIBRARY (a unit), ORACLE-REFUSES (no mode compiles it), NO-OUTPUT, NEEDS-INPUT (its answer changes with standard input)
#   2  the dialect cells are the modes found: iso for the ISO program, fpc for the one -Miso refuses; the answers are fpc's bytes
#   3  the collection is byte for byte what it was, no compiler output beside a source, and no scratch copy is left behind
#   4  --mine-dialects fpc gives every entry the dialect fpc; a name outside the ladder refuses rc 2
#   5  the one grader reads the mined package in mode 3 (the dialect cells iso and fpc are admitted): every entry is graded and passes
#   6  --mine-under FOLDER --mine-add cuts one folder more: the index gains its entry, and every other folder's rows, answers, ALL.omit lines and
#      census lines stand byte for byte; --mine-add without a folder refuses rc 2
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=builder_mines_a_pascal_collection_by_fpc
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
FP="$(fpc_bin 2>/dev/null)"; [ -n "$FP" ] && [ -x "$FP" ] || { echo "REFUSE(2) [$NAME]: no Pascal oracle (fpc_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_mine_pas.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
B="$HERE/util_build_package_suite.py"
C="$T/coll"; P="$T/pkg/mined"
mkdir -p "$C/sub" "$P"
printf 'program plain(output);\nbegin\n  writeln(1 + 1)\nend.\n' > "$C/plain.pas"
printf "program modern;\nvar s: string;\nbegin\n  s := 'hi'; writeln(s)\nend.\n" > "$C/modern.pas"
printf "program writer(output);\nvar f: text;\nbegin\n  assign(f, 'made.txt'); rewrite(f); writeln(f, 'x'); close(f); writeln('wrote')\nend.\n" > "$C/sub/writer.pas"
printf 'unit lib;\ninterface\nimplementation\nend.\n' > "$C/lib.pas"
printf 'program refused;\nbegin\n  writeln(\nend.\n' > "$C/refused.pas"
printf 'program quiet;\nbegin\nend.\n' > "$C/quiet.pas"
printf 'program clock;\nbegin\n  randomize;\n  writeln(random(1000))\nend.\n' > "$C/clock.pas"
printf 'program input1(input, output);\nvar n: integer;\nbegin\n  n := 0; if not eof then read(n); writeln(n)\nend.\n' > "$C/sub/input1.pas"
printf 'root\t%s\norigin\ta scratch collection of the gate\nversion\tgate\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
snap() { (cd "$1" && find . -type f | sort | while read -r f; do printf '%s %s\n' "$(sha256sum < "$f" | cut -c1-16)" "$f"; done); }
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
snap "$C" > "$T/coll.before"
timeout -k 5 900 python3 "$B" "$P" --lang pascal --mine "$T/census.tsv" --mine-cap 30 > "$T/1.log" 2>&1; r1=$?
want="clock.pas CLOCK-SEEDED;input1.pas NEEDS-INPUT;lib.pas LIBRARY;modern.pas ENTRY;plain.pas ENTRY;quiet.pas NO-OUTPUT;refused.pas ORACLE-REFUSES;writer.pas ENTRY;"
got="$(grep -v '^#' "$T/census.tsv" 2>/dev/null | cut -f1,2 | sed 's|^sub/||' | tr '\t' ' ' | sort | tr '\n' ';')"
[ "$r1" = 0 ] && [ "$got" = "$want" ] && ck ok "(1) the census names each planted verdict" || ck no "(1) rc=$r1 census=[$got] :: $(tail -1 "$T/1.log" | cut -c1-160)"
cells="$(awk -F, 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == "dialect") d = i; next} {printf "%s=%s;", $2, $d}' "$P/ALL.csv" 2>/dev/null)"
[ "$cells" = "modern=fpc;plain=iso;sub/writer=iso;" ] && [ "$(tr -d ' ' < "$P/plain.out" 2>/dev/null)" = 2 ] && [ "$(cat "$P/modern.out" 2>/dev/null)" = hi ] \
  && ck ok "(2) the dialect cells are the modes found and the answers are fpc's" || ck no "(2) cells=[$cells] plain.out=[$(cat "$P/plain.out" 2>/dev/null)]"
snap "$C" > "$T/coll.after"
cmp -s "$T/coll.before" "$T/coll.after" && [ -z "$(ls "$TMPDIR" | grep '^mine_')" ] && ! find "$P" -name '*.pas' | grep -q . \
  && ck ok "(3) the collection is what it was, no program is in the package and no scratch copy is left" \
  || ck no "(3) collection diff: $(diff "$T/coll.before" "$T/coll.after" | head -2 | tr '\n' ';') scratch left: $(ls "$TMPDIR" | grep -c '^mine_')"
P2="$T/pkg/mined_fpc"; mkdir -p "$P2"; cp "$P/ALL.source" "$P2/"
timeout -k 5 900 python3 "$B" "$P2" --lang pascal --mine "$T/census2.tsv" --mine-cap 30 --mine-dialects fpc > "$T/4.log" 2>&1; r4=$?
cells2="$(awk -F, 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == "dialect") d = i; next} {printf "%s=%s;", $2, $d}' "$P2/ALL.csv" 2>/dev/null)"
timeout -k 5 60 python3 "$B" "$P2" --lang pascal --mine "$T/census3.tsv" --mine-dialects cobol > "$T/4b.log" 2>&1; r4b=$?
[ "$r4" = 0 ] && [ "$cells2" = "modern=fpc;plain=fpc;sub/writer=fpc;" ] && [ "$r4b" = 2 ] && ck ok "(4) --mine-dialects fpc cuts every answer in fpc's own mode; a name outside the ladder refuses" \
  || ck no "(4) rc=$r4 cells=[$cells2] refusal rc=$r4b"
S4E_ONE_RUNNER_FIXTURE="$NAME: a planted collection and package of three programs, not a board" S4E_PROGRESS_DB="$T/progress.tsv" \
  timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.pas" "$P/ALL.ref" --lang pascal --modes m3 > "$T/5.log" 2>&1 < /dev/null; r5=$?
board="$(grep -E '^SUITE_BOARD ' "$T/5.log" | tail -1)"
n5="$(printf '%s' "$board" | grep -oE 'm3_n=[0-9]+' | cut -d= -f2)"; p5="$(printf '%s' "$board" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
[ "$r5" = 0 ] && [ "${n5:-0}" = 3 ] && [ "${p5:-0}" = 3 ] \
  && ck ok "(5) the grader reads the mined package in mode 3 and all three entries pass" \
  || ck no "(5) rc=$r5 board=[$(printf '%s' "$board" | cut -c1-110)] :: $(grep -E '^ +(PASS|FAIL|CRASH)' "$T/5.log" | head -3 | cut -c1-200 | tr '\n' ';')"
mkdir -p "$C/two"; printf "program w(output);\nbegin\n  writeln('two')\nend.\n" > "$C/two/w.pas"; printf 'program q;\nbegin\nend.\n' > "$C/two/q.pas"
cp "$P/ALL.omit" "$T/omit.before"; grep -v '^#' "$T/census.tsv" | sort > "$T/census.before"; cp "$P/plain.out" "$T/plain.out.before"
timeout -k 5 900 python3 "$B" "$P" --lang pascal --mine "$T/census.tsv" --mine-cap 30 --mine-under two --mine-add > "$T/6.log" 2>&1; r6=$?
ents="$(awk -F, 'NR > 1 {printf "%s;", $2}' "$P/ALL.csv" 2>/dev/null)"
timeout -k 5 60 python3 "$B" "$P" --lang pascal --mine "$T/census9.tsv" --mine-add > "$T/6b.log" 2>&1; r6b=$?
[ "$r6" = 0 ] && [ "$ents" = "modern;plain;sub/writer;two/w;" ] && [ "$(cat "$P/two/w.out" 2>/dev/null)" = two ] && cmp -s "$P/plain.out" "$T/plain.out.before" \
  && [ "$(grep -v '^two/' "$P/ALL.omit")" = "$(cat "$T/omit.before")" ] && grep -q '^two/q.pas: NO-OUTPUT: ' "$P/ALL.omit" \
  && [ "$(grep -v '^#' "$T/census.tsv" | grep -v '^two/' | sort)" = "$(cat "$T/census.before")" ] && [ "$(grep -c '^two/' "$T/census.tsv")" = 2 ] && [ "$r6b" = 2 ] \
  && ck ok "(6) --mine-add cuts one folder more and keeps every other folder's rows, answers, omit lines and census lines" \
  || ck no "(6) rc=$r6 entries=[$ents] add without a folder rc=$r6b :: $(tail -1 "$T/6.log" | cut -c1-140)"
echo "BUILDER_MINES_PASCAL_BOARD arms=6 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 6 ] && { echo "GATE OK [$NAME]: a Pascal collection is mined in place by fpc, the dialect found"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
