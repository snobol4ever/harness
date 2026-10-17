#!/usr/bin/env bash
# test_gate_icon_package_container_keys_equal_board_keys.sh -- EVERY ICON PACKAGE CONTAINER KEY IS A KEY ITS BOARD WRITES, AND THE
# PROGRESS TABLE HOLDS NO GHOST OF THE THREE SUITES (ceo CEO-1366 (b); row icon-package-containers-regenerated-from-the-shipped-files-
# and-every-container-key-equals-its-boards-progress-key-ceo-1366; the coo 2026-10-09).
# One program had two keys in the progress table: the container keyed arizona_tests general/args, its board the bare stem args
# (until SCRIP b4f66ce42), IPL's board once wrote bare stems where it now writes progs/when, and a 09-05 replay wrote
# icon/arizona_tests/general/args.icn. A reader of the table counted one program as two and a stale reading as live.
# The measurement is util_progress_prune_ghosts.py's (the ONE reader): per suite, K the table's keys, B the board's latest run's keys
# (refused when the run is partial), C the container's ALL.csv entries, X the package's EXCLUDED.tsv and CONTAINERS.tsv keys.
#   ARM 1  SELF-PROOF on a fixture (outside corpus, under mktemp): a planted ghost and a planted container key the board does not
#          write each RED; the same fixture after --apply reads GREEN and kept every live row
#   ARM 1h the harness writes a driver-graded entry under its library, the key its board writes (one rule: lib_package_keys.py)
#   ARM 2  arizona, jcon and ipl: container keys the board does not write (C - B - X) = 0
#   ARM 3  arizona, jcon and ipl: ghosts (K - B - C - X) = 0
# EXIT: 0 all arms pass · 1 an arm failed · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR="$HERE/util_progress_prune_ghosts.py"
SIB="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PKG="$SIB/corpus/packages/icon"; ST="$(. "$HERE/lib_suites_tsv.sh"; suites_tsv "$SIB")"; DB="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
for f in "$PR" "$ST" "$DB" "$PKG/arizona_tests/ALL.csv" "$PKG/jcon_tests/ALL.csv" "$PKG/ipl/ALL.csv"; do
  [ -e "$f" ] || { echo "GATE UNPROVEN(2): missing $f"; exit 2; }
done
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p" | head -1; }

echo "=== gate: every Icon package container key is a key its board writes, and no ghost of the three suites remains ==="
echo "--- ARM 1: self-proof on a fixture ---"
mkdir -p "$W/pkg"
H=$'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome'
{ printf '%s\n' "$H"
  printf '2026-10-01T00:00:00\told0000000\tc0\tcoo\tpackage\tfx\ticon\tx\tm3\tPASS\n'
  printf '2026-10-09T00:00:00\tnew0000000\tc1\tcoo\tpackage\tfx\ticon\tg/x\tm3\tPASS\n'
  printf '2026-10-09T00:00:01\tnew0000000\tc1\tcoo\tpackage\tfx\ticon\tg/y\tm3\tPASS\n'; } > "$W/db.tsv"
printf 'rank,entry\n1,g/x\n2,g/y\n' > "$W/pkg/ALL.csv"
printf 'fx\tFx\t-\ticon\t-\t-\t-\t-\t2\t2\t-\n' > "$W/suites.tsv"
o="$(python3 "$PR" --db "$W/db.tsv" --suites-tsv "$W/suites.tsv" fx="$W/pkg" 2>&1)"
[ "$(num "$o" ghosts)" = 1 ] && ck ok "a bare key no reader writes reads as ONE ghost" || ck no "planted ghost not read: $(printf '%s' "$o" | head -1)"
printf 'rank,entry\n1,g/x\n2,g/y\n3,g/z\n' > "$W/pkg/ALL.csv"
o="$(python3 "$PR" --db "$W/db.tsv" --suites-tsv "$W/suites.tsv" fx="$W/pkg" 2>&1)"
[ "$(num "$o" container_keys_the_board_does_not_write)" = 1 ] && ck ok "a container key the board does not write reads as ONE mismatch" || ck no "planted mismatch not read: $(printf '%s' "$o" | head -1)"
printf 'rank,entry\n1,g/x\n2,g/y\n' > "$W/pkg/ALL.csv"
python3 "$PR" --apply --db "$W/db.tsv" --suites-tsv "$W/suites.tsv" fx="$W/pkg" > "$W/apply.out" 2>&1
o="$(python3 "$PR" --db "$W/db.tsv" --suites-tsv "$W/suites.tsv" fx="$W/pkg" 2>&1)"
if [ "$(num "$o" ghosts)" = 0 ] && [ "$(grep -c $'\tfx\t' "$W/db.tsv")" = 2 ]; then ck ok "--apply removed the ghost row and kept both live rows"
else ck no "after --apply: $(printf '%s' "$o" | head -1); rows left $(grep -c $'\tfx\t' "$W/db.tsv")"; fi
printf 'fx\tFx\t-\ticon\t-\t-\t-\t-\t5\t5\t-\n' > "$W/suites.tsv"
o="$(python3 "$PR" --db "$W/db.tsv" --suites-tsv "$W/suites.tsv" fx="$W/pkg" 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q 'partial run' && ck ok "a latest run holding fewer keys than the published total REFUSES rc 2 (never prunes live keys)" || ck no "a partial run was not refused (rc=$rc)"

echo "--- ARM 1h: the harness records a driver-graded entry under its LIBRARY, the board's key (lib_package_keys.board_key) ---"
FP="$W/root/packages/icon/fxpkg"; mkdir -p "$FP/g"; printf 'procedure libp()\n  return 1\nend\n' > "$FP/g/lib.icn"
python3 - "$FP" <<'PY'
import sys
d = sys.argv[1]; b = lambda n: "#" + "-" * (80 - 1 - len(" 1 " + n)) + " 1 " + n
open(d + "/ALL.icn", "w").write(b("g/lib_driver") + "\nprocedure main()\n  write(\"x\")\nend\n")
open(d + "/ALL.ref", "w").write(b("g/lib_driver") + "\nx\n")
open(d + "/ALL.csv", "w").write("rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,g/lib_driver,fxpkg__g/lib_driver,fxpkg,3,0,0,131072,4096,,\n")
PY
S4E_PROGRESS_DB="$W/hp.tsv" timeout -k 5 120 python3 "$HERE/corpus_suite_harness.py" run "$FP/ALL.icn" "$FP/ALL.ref" --lang icon --modes m3 < /dev/null > "$W/h.out" 2>&1
hk="$(awk -F'\t' 'NR>1 {print $8}' "$W/hp.tsv" 2>/dev/null | sort -u | tr '\n' ' ')"
[ "$hk" = "g/lib " ] && ck ok "the harness wrote the entry g/lib_driver under the library key g/lib" || ck no "the harness wrote key(s) [$hk], want [g/lib] -- $(tail -2 "$W/h.out" | tr '\n' ' ' | cut -c1-120)"

echo "--- ARMS 2 and 3: the three Icon package suites ---"
o="$(python3 "$PR" --db "$DB" --suites-tsv "$ST" arizona="$PKG/arizona_tests" jcon="$PKG/jcon_tests" ipl="$PKG/ipl" 2>&1)"; rc=$?
printf '%s\n' "$o" | grep -E '^(GHOSTS|REFUSE)' | sed 's/^/    /'
[ "$rc" = 2 ] && { echo "GATE UNPROVEN(2): the measurement refused (above)"; exit 2; }
for s in arizona jcon ipl; do
  ln="$(printf '%s\n' "$o" | grep "^GHOSTS $s:")"
  m="$(num "$ln" container_keys_the_board_does_not_write)"; g="$(num "$ln" ghosts)"
  [ "$m" = 0 ] && ck ok "$s: every container key is a key the board writes or the package excludes" || ck no "$s: $m container key(s) the board does not write"
  [ "$g" = 0 ] && ck ok "$s: no ghost key in the progress table" || ck no "$s: $g ghost key(s) -- util_progress_prune_ghosts.py --apply removes them"
done
echo "population: $checks arm(s), $fails failed (a fixture table under mktemp; the live progress table, read under its writers' lock)"
[ "$fails" = 0 ] && { echo "GATE PASS(0) [icon_package_container_keys_equal_board_keys]: $checks of $checks arms hold"; exit 0; }
echo "GATE FAIL(1) [icon_package_container_keys_equal_board_keys]: $fails of $checks arms red"; exit 1
