#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: test_demos_suite.sh invoked on a scratch demo tree as an instrument fixture, not a board (CEO-1312)"
# test_gate_demos_suite_grades_each_demo_in_both_modes.sh -- THE DEMO SUITE ROW'S RUNNER AND THE WORKHORSE READER (Lon 2026-09-27: "all
# demos are also benchmarks. They are work-horse benchmarks." and "So demos are test suites in that they have a small input ... and a ref
# file."; ceo CEO-1312/1313; coo COO-206).
# ONE SCRATCH DEMO TREE (outside every corpus checkout), graded by test_demos_suite.sh snobol4:
#   a/hello.sno   PASS both modes, a .workhorse sidecar            b/echo.sno   reads its SAMPLE stdin from echo.in (a copy of a shared
#   c/bad.sno     a wrong ref: FAIL, named                                        file, the shape shared demo inputs take), PASS both modes
#   d/noref.sno   no .ref: FAIL, counted and named, never skipped  lib/util.sno declared in CONTAINERS.tsv: out of the population
#   e/linked.icn  a link manifest into the mirrored packages root (its statements end in ';', as SCRIP Icon requires since c299b8a03)  f/chained.sno  a .chain sidecar: concatenated after library/gate_unit.sno
# ARMS: (1) the board line reads total=6 all_pass=4 m3_pass=4 m4_pass=4 containers=1 workhorse_declared=1 chained=1; (2) the reds are named,
# the no-ref one as no-ref; (3) the progress rows land in a scratch table as class benchmark, suite snobol4-demos, keyed demos/snobol4/<r>,
# one per program and mode (12 rows, the container none); (4) the fixture tree is never written as a suite row; (5)-(8) the workhorse
# reader: a valid sidecar echoes stdin/scale/argv, and an unknown key, a missing stdin file and a zero scale each REFUSE rc 2;
# (9)-(12) the chain reader: a present unit echoes its path, and a missing unit, a blank line and an absolute path each REFUSE rc 2.
# FAILED ONCE: arms (1)-(4) need the runner, which did not exist before this landing; (5)-(8) the reader likewise; (1) and (3) with the
# runner's concatenation line replaced by a no-op (the chained demo reads m3=FAIL,m4=FAIL, 12 rows with two FAIL), 2026-09-27.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (the fixture could not be built).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
G=demos_suite_grades_each_demo_in_both_modes
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2) [$G]: no scrip binary -- make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?   # the runner it drives carries the same guard; the gate names it too (test_gate_runners_refuse_on_a_stale_binary)
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || { echo "⛔ REFUSED(2) [$G]: cannot create $SCRATCH"; exit 2; }
T="$(mktemp -d "$SCRATCH/gate_demos_XXXXXX")" || { echo "⛔ REFUSED(2) [$G]: mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
F="$T/demos/snobol4"; mkdir -p "$F/a" "$F/b" "$F/c" "$F/d" "$F/lib"
printf "\tOUTPUT = 'hi'\nEND\n" > "$F/a/hello.sno"; printf 'hi\n' > "$F/a/hello.ref"; printf 'stdin\t-\nwhy\tgate fixture\n' > "$F/a/hello.workhorse"
printf "LOOP\tOUTPUT = INPUT\t:S(LOOP)\nEND\n" > "$F/b/echo.sno"; printf 'one\ntwo\n' > "$F/b/shared.input"; cp -p "$F/b/shared.input" "$F/b/echo.in"; printf 'one\ntwo\n' > "$F/b/echo.ref"
printf "\tOUTPUT = 'two'\nEND\n" > "$F/c/bad.sno"; printf 'one\n' > "$F/c/bad.ref"
printf "\tOUTPUT = 'x'\nEND\n" > "$F/d/noref.sno"
printf "\tDEFINE('U()')\t:(U_END)\nU\t:(RETURN)\nU_END\n" > "$F/lib/util.sno"
# (e) a link manifest naming a module OUTSIDE the demo tree by a source-relative path, as the JCON demos do
#     (link "../../../packages/icon/jcon-compiler/dump"): the scratch copy must keep the program's depth or this reads
#     "link: cannot open" in both modes (coo COO-209)
mkdir -p "$F/e" "$T/packages/gate"; printf 'procedure greet();\n   write("linked");\nend\n' > "$T/packages/gate/mod.icn"
printf 'link "../../../packages/gate/mod"\nprocedure main();\n   greet();\nend\n' > "$F/e/linked.icn"; printf 'linked\n' > "$F/e/linked.ref"
# (f) a CHAINED demo: f/chained.chain names a unit under the root's library/ that the program is concatenated after (the beauty.sc
#     shape, hq_snocone + coo 2026-09-27); the unit defines the function the program calls, so the program alone would not run
mkdir -p "$F/f" "$T/library"; printf "\tDEFINE('CH()')\t:(CH_END)\nCH\tCH = 'chained'\t:(RETURN)\nCH_END\n" > "$T/library/gate_unit.sno"
printf "\tOUTPUT = CH()\nEND\n" > "$F/f/chained.sno"; printf 'library/gate_unit.sno\n' > "$F/f/chained.chain"; printf 'chained\n' > "$F/f/chained.ref"
printf '# fixture\nlib/util.sno\tLIBRARY\tincluded by nothing here (gate fixture)\n' > "$F/CONTAINERS.tsv"
out="$(DEMOS_DIR="$F" S4E_PROGRESS_DB="$T/db.tsv" timeout -k 5 600 bash "$HERE/test_demos_suite.sh" snobol4 2>&1)"; rc=$?
[ "$rc" = 2 ] && { echo "⛔ REFUSED(2) [$G]: the runner did not measure the fixture:"; printf '%s\n' "$out" | grep -m3 -E 'REFUS|UNPROVEN' | sed 's/^/    /'; exit 2; }
_b="$(printf '%s\n' "$out" | grep -m1 '^DEMOS_SUITE_BOARD ')"; _ok=1
for kv in lang=snobol4 total=6 shipped=7 all_pass=4 all_n=6 m3_pass=4 m4_pass=4 containers=1 workhorse_declared=1 chained=1; do grep -qE "(^| )$kv( |\$)" <<<"$_b" || _ok=0; done
[ "$_ok" = 1 ] && ck ok "(1) the board: a DEMOS_SUITE_BOARD line, total=6 shipped=7 all_pass=4 all_n=6 m3/m4 4 containers=1 workhorse_declared=1 chained=1 (the chained demo PASS both modes on units-then-program; the shared stdin read through echo.in; the link manifest resolved through the depth-keeping copy)" || ck no "(1) the board line: $_b"
# (1b) the writer READS the fraction off that line by name and would archive it verbatim (CEO-827): a receipt that is prose is the CEO-1325 fault
# (the write path itself gates on a clean committed tree and the lane seat, neither of which a gate may assume, so the
#  READER is called directly: the same two functions `write` runs on --text)
_w="$(python3 - "$HERE" "$_b" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import util_score_row as u
line = sys.argv[2]; m = u.BOARD_LINE_RX.search(line)
p, t, why = u.fraction_from_text(line, None, None)
print("archivable=%s pass=%s total=%s why=%s" % ("yes" if m else "no", p, t, why))
PY
)"
grep -qx 'archivable=yes pass=4 total=6 why=None' <<<"$_w" && ck ok "(1b) util_score_row reads all_pass=4 all_n=6 off the DEMOS_SUITE_BOARD line by name and its archiver matches it (CEO-827)" || ck no "(1b) the writer's reader on the board line: $_w"
{ grep -q 'c/bad.sno(m3=FAIL,m4=FAIL)' <<<"$out" && grep -q 'd/noref.sno(no-ref)' <<<"$out"; } && ck ok "(2) the reds are named, the ref-less demo as no-ref" || ck no "(2) the named reds: $(grep 'NOT BOTH' <<<"$out")"
_rows="$(awk -F'\t' 'NR>1 && $5=="benchmark" && $6=="snobol4-demos" {print $8" "$9" "$10}' "$T/db.tsv" 2>/dev/null | sort)"
{ [ "$(printf '%s\n' "$_rows" | grep -c .)" = 12 ] && grep -qx 'demos/snobol4/e/linked.icn m4 PASS' <<<"$_rows" && grep -qx 'demos/snobol4/f/chained.sno m4 PASS' <<<"$_rows" && grep -qx 'demos/snobol4/a/hello.sno m3 PASS' <<<"$_rows" && grep -qx 'demos/snobol4/d/noref.sno m4 FAIL' <<<"$_rows" && ! grep -q util <<<"$_rows"; } \
  && ck ok "(3) 12 progress rows (the linked Icon manifest and the chained demo PASS in both modes), class benchmark, suite snobol4-demos, keyed demos/snobol4/<r>, the container none" || ck no "(3) progress rows: $(tr '\n' ';' <<<"$_rows")"
grep -q 'not the canonical demo tree -- a fixture, never written' <<<"$out" && ck ok "(4) the scratch tree is never written as a suite row" || ck no "(4) the fixture was not declared unwritten"
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED(2) [$G]: lib_declared_arena.sh unloadable"; exit 2; }
W="$T/wh"; mkdir -p "$W"; printf "\tOUTPUT = 1\nEND\n" > "$W/p.sno"; printf 'full\n' > "$W/full.dat"
printf 'stdin\tfull.dat\nscale\t16\nargv\t-x 1\n' > "$W/p.workhorse"; v="$(declared_workhorse_beside "$W/p.sno" 2>/dev/null)"; r=$?
[ "$r" = 0 ] && [ "$v" = "stdin=full.dat scale=16 argv=-x 1" ] && ck ok "(5) a valid workhorse sidecar echoes stdin=full.dat scale=16 argv=-x 1" || ck no "(5) the valid sidecar: rc=$r [$v]"
printf 'stdin\tfull.dat\nloops\t3\n' > "$W/p.workhorse"; declared_workhorse_beside "$W/p.sno" >/dev/null 2>&1; r=$?
[ "$r" = 2 ] && ck ok "(6) an unknown key (loops) REFUSES rc 2 -- a demo is never run in a loop" || ck no "(6) unknown key rc=$r"
printf 'stdin\tnot_there.dat\n' > "$W/p.workhorse"; declared_workhorse_beside "$W/p.sno" >/dev/null 2>&1; r=$?
[ "$r" = 2 ] && ck ok "(7) a stdin file that is not beside the program REFUSES rc 2" || ck no "(7) missing stdin file rc=$r"
printf 'stdin\tfull.dat\nscale\t0\n' > "$W/p.workhorse"; declared_workhorse_beside "$W/p.sno" >/dev/null 2>&1; r=$?
[ "$r" = 2 ] && ck ok "(8) a zero scale REFUSES rc 2" || ck no "(8) zero scale rc=$r"
# (9)-(11) the chain reader, standalone: a missing unit, a blank line and an absolute path each REFUSE rc 2 with nothing echoed; the
#          RED PROOF is (9)'s twin: the same sidecar with the unit present echoes the unit's absolute path and rc 0
C="$T/ch"; mkdir -p "$C"; printf "\tOUTPUT = 1\nEND\n" > "$C/q.sno"
printf 'library/gate_unit.sno\n' > "$C/q.chain"; v="$(declared_chain_beside "$C/q.sno" "$T" 2>/dev/null)"; r=$?
[ "$r" = 0 ] && [ "$v" = "$T/library/gate_unit.sno" ] && ck ok "(9) a chain naming a present unit echoes its absolute path, rc 0" || ck no "(9) present unit: rc=$r [$v]"
printf 'library/absent_unit.sno\n' > "$C/q.chain"; v="$(declared_chain_beside "$C/q.sno" "$T" 2>/dev/null)"; r=$?
[ "$r" = 2 ] && [ -z "$v" ] && ck ok "(10) a chain naming a missing unit REFUSES rc 2 and echoes nothing -- never a skip" || ck no "(10) missing unit: rc=$r [$v]"
printf 'library/gate_unit.sno\n\n' > "$C/q.chain"; v="$(declared_chain_beside "$C/q.sno" "$T" 2>/dev/null)"; r=$?
[ "$r" = 2 ] && ck ok "(11) a blank line REFUSES rc 2 -- one unit per line, nothing else" || ck no "(11) blank line: rc=$r"
printf '%s\n' "$T/library/gate_unit.sno" > "$C/q.chain"; v="$(declared_chain_beside "$C/q.sno" "$T" 2>/dev/null)"; r=$?
[ "$r" = 2 ] && ck ok "(12) an absolute path REFUSES rc 2 -- paths are relative to corpus/" || ck no "(12) absolute path: rc=$r"
echo "population: $checks arm(s) over one scratch demo tree of 8 files (6 programs, 1 container, one an Icon link manifest into a mirrored packages root, one chained after a library unit) and 4 workhorse sidecars and 4 chain sidecars"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [$G]: $fails of $checks arms red"; exit 1
