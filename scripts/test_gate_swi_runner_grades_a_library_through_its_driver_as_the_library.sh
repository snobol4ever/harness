#!/usr/bin/env bash
# test_gate_swi_runner_grades_a_library_through_its_driver_as_the_library.sh -- THE SWI RUNNER GRADES A LIBRARY BY ITS NAME_driver.pl (ceo CEO-1269; cto ARCH-PROLOG-CLPR-CHR.md section 8,
# option 1, 2026-10-29; hq_packages). A library module with no unit tests (clp/linprog.pl) was OWED a driver (UNGRADED NEEDS_DRIVER); the runner graded only files that declare begin_tests( and so
# could not grade the driver either, and deleting the owed row would have shrunk the denominator by one. Now NAME_driver.pl with a NAME_driver.ref beside it (cut from swipl) and no begin_tests( is
# a grading vehicle: mode 3 and mode 4 run it plain, its whole stdout against the ref is one case named driver, and the case is recorded under the LIBRARY's name (clp/linprog.pl:driver).
# FIXTURE: a mktemp corpus (outside corpus/, CEO-547) with sub/lib.pl (a module answering 42) and sub/lib_driver.pl; the ref is cut from live swipl 9.0.4 each run. --file grades one file, writes no row.
# ARMS: (1) the driver is the library's grade: the board line reads sub/lib.pl 1/1, identity graded 1 + ungraded 0 == declared 1, rc 0, m3 and m4
#       (2) CAN FAIL: the same with the ref changed reads 0/1, rc 0 (a disagreement is a red, not a refusal), and RED names sub/lib.pl:driver in both modes
#       (3) the real driver clp/linprog_driver.pl of corpus/packages/prolog/swi_tests grades 1/1 under clp/linprog.pl, m3 and m4
#       (4) the library is no longer owed: UNGRADED.tsv does not list clp/linprog.pl, and the package inventory's buckets sum (graded + ungraded + ungradable + deferred == shipped, read from lib_inventory.sh)
# RED BEFORE (measured 2026-10-29 with the runner reverted to the committed one): --file clp/linprog_driver.pl REFUSED rc 2, "matches no shipped test file" -- the driver was never a file of the population.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure.
set -u
GATE_NAME=test_gate_swi_runner_grades_a_library_through_its_driver_as_the_library
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${S4E_CORPUS:-$ROOT/corpus}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
[ -f "$CORPUS/packages/prolog/swi_tests/clp/linprog_driver.pl" ] && [ -f "$CORPUS/packages/prolog/swi_tests/clp/linprog_driver.ref" ] || refuse "no clp/linprog_driver.pl and its ref under $CORPUS/packages/prolog/swi_tests"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
S="$T/packages/prolog/swi_tests"; mkdir -p "$S/sub"
printf ':- module(lib, [ans/1]).\nans(42).\n' > "$S/sub/lib.pl"
printf ':- use_module(lib).\n:- initialization(( ans(X), writeln(X), halt )).\n' > "$S/sub/lib_driver.pl"
( cd "$S/sub" && timeout 60 "$SWIPL" -q -t halt lib_driver.pl </dev/null 2>/dev/null > lib_driver.ref ); [ "$(cat "$S/sub/lib_driver.ref")" = 42 ] || refuse "swipl did not cut the fixture ref (got: $(head -c 80 "$S/sub/lib_driver.ref"))"
run() { # $1 corpus root, $2 file
    S4E_CORPUS="$1" S4E_PROGRESS_OFF=1 timeout -k 5 600 bash "$HERE/test_prolog_swi_suite.sh" --file "$2" --modes m3,m4 --name-reds > "$T/out" 2>&1; echo $?; }
fails=0; ck() { if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
echo "=== gate: the SWI runner grades a library through its NAME_driver.pl (CEO-1269) ==="
rc=$(run "$T" sub/lib_driver.pl)
if [ "$rc" = 0 ] && grep -q '^  sub/lib.pl  *1/1  *agree' "$T/out" && grep -q 'identity: graded 1 + ungraded 0 == declared 1 ✓' "$T/out"; then ck ok "(1) sub/lib_driver.pl is the grade of sub/lib.pl: 1/1 in m3 and m4, identity holds, rc 0"
else ck no "(1) rc=$rc: $(grep -E 'sub/lib|identity|REFUSED' "$T/out" | head -3 | tr '\n' ' ')"; fi
printf '43\n' > "$S/sub/lib_driver.ref"
rc=$(run "$T" sub/lib_driver.pl)
if [ "$rc" = 0 ] && grep -q '^  sub/lib.pl  *0/1  *agree' "$T/out" && grep -q 'RED sub/lib.pl:driver:m3' "$T/out" && grep -q 'RED sub/lib.pl:driver:m4' "$T/out"; then ck ok "(2) CAN FAIL: a changed ref reads 0/1 and RED names sub/lib.pl:driver in m3 and m4"
else ck no "(2) rc=$rc: $(grep -E 'sub/lib|RED|REFUSED' "$T/out" | head -3 | tr '\n' ' ')"; fi
rc=$(run "$CORPUS" clp/linprog_driver.pl)
if [ "$rc" = 0 ] && grep -q '^  clp/linprog.pl  *1/1  *agree' "$T/out" && grep -q 'm3_pass=1 .*m4_pass=1' "$T/out"; then ck ok "(3) the real clp/linprog_driver.pl grades 1/1 under clp/linprog.pl in m3 and m4"
else ck no "(3) rc=$rc: $(grep -E 'linprog|REFUSED|SWI_BOARD' "$T/out" | head -3 | tr '\n' ' ')"; fi
if ! grep -q '^clp/linprog.pl	' "$CORPUS/packages/prolog/swi_tests/UNGRADED.tsv"; then
    iv="$(bash -c "cd '$ROOT/SCRIP'; . '$HERE/lib_gate.sh'; . '$HERE/lib_inventory.sh'; INV_PACKAGE=swi_tests; INV_DIR='$CORPUS/packages/prolog/swi_tests'; INV_EXT=.pl; inventory_line \$(( \$( { grep -rl --include='*.pl' 'begin_tests(' '$CORPUS/packages/prolog/swi_tests'; find '$CORPUS/packages/prolog/swi_tests' -type f -name '*_driver.pl' | while read -r d; do grep -q 'begin_tests(' \"\$d\" || echo \"\$d\"; done; } | wc -l ) )) 0" 2>&1 | tail -1)"
    sums="$(printf '%s' "$iv" | awk '/^PACKAGE_INVENTORY /{for(i=1;i<=NF;i++){split($i,k,"="); v[k[1]]=k[2]} print (v["shipped"]==v["graded"]+v["ungraded"]+v["ungradable"]+v["deferred"]) ? "yes" : "no"}')"
    if [ "$sums" = yes ]; then ck ok "(4) clp/linprog.pl is not owed and the inventory buckets sum: $iv"; else ck no "(4) inventory: $iv"; fi
else ck no "(4) UNGRADED.tsv still lists clp/linprog.pl"; fi
echo "population: a fixture library, the real clp/linprog_driver.pl, the package inventory; 4 arms, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [$GATE_NAME]: 4 of 4 arms hold"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]: $fails of 4 arms FAIL"; exit 1
