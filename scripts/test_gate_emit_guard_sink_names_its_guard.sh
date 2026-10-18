#!/usr/bin/env bash
# test_gate_emit_guard_sink_names_its_guard.sh -- the driver's two abort sinks are two DIFFERENT sentences,
# and the guard sink names the guard that fired.
#
# THE DEFECT (row emit-guard-sink-diagnostic-names-a-missing-template-when-a-live-cases-guard-fired): one
# function, drive_unowned, was both the default: case of emit_drive -- a genuinely missing template -- AND
# the guard sink inside 58 existing cases. For an op that plainly had a case it printed "has no template ...
# Implement op=N" and sent the reader to write something already there. Cured in 7d54b9354 by splitting it
# into drive_no_template (the default only) and drive_guard_refused(nd, __LINE__) (the other 58).
#
# ⛔⛔ WHY THIS GATE MANUFACTURES ITS TRIP INSTEAD OF FINDING ONE, which is the whole design and is a ceo
# ruling (CEO-554), not a convenience. The row originally asked for a gate that reaches a guard sink with a
# real program. MEASURED 2026-09-11: there is no such program. The witness the row itself cites,
# `x :=: (y := 5)`, is cured and prints 51 matching iconx; a compile-only sweep of 215 Icon package programs
# tripped the sink ZERO times; and the one live trip that did exist that day -- `create foo()` with foo
# undeclared -- was cured the same sitting (a4d95d5ff), which DESTROYED it. ⭐ THE GENERAL FORM, and the
# reason this is written on the gate rather than in a ledger nobody reads: A GATE ANCHORED ON A FOUND
# WITNESS, WHERE EVERY POSSIBLE WITNESS IS A DEFECT THE ORG IS ACTIVELY DELETING, GOES FROM GREEN TO
# REFUSING ON THE DAY SOMEONE DOES GOOD WORK. Anchoring here was not an option; the trip has to be made.
#
# ⛔⭐ THE MANUFACTURED TRIP IS RETIRED UNDER CEO-1680 (cto 2026-10-17; Lon 2026-10-11: no broken code planted so a test can trip).
# The SCRIP_TEST_PLANT_GUARD_SINK seam left emit.cpp in row emit-the-three-emitter-plants-...'s landing. Its recorded
# reading is the fail-once: with the seam set the hello aborted rc 134 printing "REFUSED AT A GUARD -- emit.cpp:<line>" and "NOT a missing
# template", never "has NO TEMPLATE"; unset, 30 programs' .s were byte-identical to a build without the seam. No program reaches a guard sink
# (measured 2026-09-11: 215 package programs, zero trips), so no oracle-graded witness exists; what this gate can still say, it says on the
# SHIPPED LIBRARY, not on the source: (1) the two sinks carry two distinct sentences; (2) the guard sink is called from at least 50 sites (58 at
# the re-cut, one per guarded case); (3) a hello runs. ⛔ A GREEN HERE SAYS THE SENTENCES AND THE WIRING EXIST, NOT THAT A GUARD FIRES.
#
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=emit_guard_sink_names_its_guard
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n   write("hello");\nend\n' > "$T/w.icn"
SO="$ROOT/out/libscrip_rt.so"; [ -f "$SO" ] || refuse "no $SO"
command -v objdump > /dev/null || refuse "objdump absent"
graded=0; fail=0
g=$(strings -n 20 "$SO" | grep -c 'REFUSED AT A GUARD'); n=$(strings -n 20 "$SO" | grep -c 'has NO TEMPLATE'); both=$(strings -n 20 "$SO" | grep 'REFUSED AT A GUARD' | grep -c 'has NO TEMPLATE')
graded=$((graded+1))
if [ "$g" -ge 1 ] && [ "$n" -ge 1 ] && [ "$both" = 0 ] && strings -n 20 "$SO" | grep 'REFUSED AT A GUARD' | grep -q 'NOT a missing template'; then echo "  PASS the library carries two distinct sink sentences (guard $g, no-template $n) and the guard one says NOT a missing template"
else echo "  FAIL the sink sentences are missing or merged (guard $g, no-template $n, both in one $both)"; fail=$((fail+1)); fi
c=$(objdump -d --no-show-raw-insn "$SO" 2>/dev/null | grep -cE 'call +[0-9a-f]+ <drive_guard_refused>')
graded=$((graded+1))
if [ "$c" -ge 50 ]; then echo "  PASS the guard sink is called from $c sites in the shipped library"; else echo "  FAIL the guard sink is called from $c sites (want 50 or more) -- guarded cases lost their sink"; fail=$((fail+1)); fi
o2="$("$SCRIP" "$T/w.icn" </dev/null 2>&1)"; rc2=$?
graded=$((graded+1))
if [ "$rc2" = 0 ] && [ "$o2" = "hello" ]; then echo "  PASS witness runs normally"; else echo "  FAIL witness did not run normally (rc=$rc2)"; fail=$((fail+1)); fi
[ "$graded" = 3 ] || refuse "expected 3 arms, graded $graded"
echo "graded=$graded FAIL=$fail (static arms on the shipped library: no program reaches a guard sink, and the trip seam is retired under CEO-1680)"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
