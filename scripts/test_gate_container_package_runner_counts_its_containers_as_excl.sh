#!/usr/bin/env bash
# test_gate_container_package_runner_counts_its_containers_as_excl.sh -- A CONTAINER PACKAGE'S Excl COUNTS ITS CONTAINERS.tsv FRAGMENTS
# (CEO-1288: Excl is every shipped unit a package row's denominator leaves out, a CONTAINERS.tsv include fragment among them, so
# shipped = denominator + Excl reads off the row). Found by the coo 2026-10-10: lib_container_package_runner.sh published rosetta-prolog
# 220/786 with Excl 0 over its 9 containers, where jcon, arizona, gnu and ipl count theirs; the runner now asks container_package_excl.
# Hermetic, no build, no corpus: a mktemp package of six shipped .pl files and its ALL.pl, through container_package_excl, the function
# the runner calls, with lib_inventory.sh's readers:
#   arm 1  EXCLUDED.tsv alone, one row                                              -> "1 0"
#   arm 2  + CONTAINERS.tsv: two shipped fragments and one naming no shipped file    -> "3 2"
#   arm 3  + a fragment EXCLUDED.tsv already names                                   -> "3 2" (one unit, counted once)
#   arm 4  a CONTAINERS.tsv row with no measurement                                  -> rc 2 (no row over an unread exclusion)
# FAIL_ONCE=1 plants a third shipped fragment in arm 2's CONTAINERS.tsv and must read red.
# EXIT: 0 every arm holds; 1 an arm red, named; 2 a library unloadable.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_container_package_runner_counts_its_containers_as_excl
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(2) [$G]: lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_container_package_runner.sh" 2>/dev/null || { echo "⛔ REFUSE(2) [$G]: lib_container_package_runner.sh unloadable"; exit 2; }
declare -F container_package_excl > /dev/null || { echo "⛔ REFUSE(2) [$G]: lib_container_package_runner.sh defines no container_package_excl"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P="$T/pkg"; mkdir -p "$P"
for n in a b c d e f; do printf 'main :- write(%s), nl.\n:- initialization(main).\n' "$n" > "$P/$n.pl"; done
: > "$P/ALL.pl"
EVID="loads library(clpfd) at line 1 -- a CLP(FD) model the oracle answers, outside the FD baseline (fixture)"
printf '# fixture\nb.pl\tOUTSIDE_CLPFD\t%s\n' "$EVID" > "$P/EXCLUDED.tsv"
RED=0; ARMS=0
arm() {  # name, expected "<excl> <containers>" or rc2
    local name="$1" want="$2" got rc
    ARMS=$((ARMS + 1))
    got="$(container_package_excl "$P" pl 2>/dev/null)"; rc=$?
    if [ "$want" = rc2 ]; then
        if [ "$rc" = 2 ]; then echo "  ok   $name: refused rc 2"; else echo "  RED  $name: want rc 2, got rc $rc [$got]"; RED=1; fi
    elif [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok   $name: [$got]"
    else echo "  RED  $name: want [$want], got rc $rc [$got]"; RED=1; fi
}
arm "arm 1 EXCLUDED.tsv alone" "1 0"
{ printf '# fixture\n'
  printf 'c.pl\tINCLUDED_BY\ta.pl -- its include directive splices this block (fixture)\n'
  printf 'd.pl\tNO_DEFINITION\tno clause and no load directive\n'
  printf 'ghost.pl\tNO_DEFINITION\tno clause and no load directive\n'
  [ -n "${FAIL_ONCE:-}" ] && printf 'e.pl\tNO_DEFINITION\tno clause and no load directive\n'
} > "$P/CONTAINERS.tsv"
arm "arm 2 two shipped fragments and a ghost" "3 2"
printf 'b.pl\tNO_DEFINITION\tno clause and no load directive\n' >> "$P/CONTAINERS.tsv"
arm "arm 3 a fragment EXCLUDED.tsv already names" "3 2"
printf 'e.pl\tINCLUDED_BY\t \n' >> "$P/CONTAINERS.tsv"
arm "arm 4 a row with no measurement" rc2
echo "population: $ARMS arms over a mktemp package of 6 shipped .pl files (container_package_excl, lib_container_package_runner.sh)"
if [ "$RED" = 0 ]; then echo "GATE PASS [$G]: Excl = EXCLUDED.tsv rows + shipped CONTAINERS.tsv fragments, each unit once; a refused sidecar is rc 2"; exit 0; fi
echo "GATE FAIL [$G]: the container runner's Excl does not count its containers as CEO-1288 rules"; exit 1
