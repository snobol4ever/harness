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
# ⛔ THE SEAM IS TEST-ONLY AND ARM 3 PROVES IT INERT. emit.cpp carries drive_plant_guard_sink(), a cached
# getenv on SCRIP_TEST_PLANT_GUARD_SINK in the same form as the sanctioned SCRIP_VARARG_TAIL and
# SCRIP_PROC_OPEN_P. Unset, it must change NOTHING -- arm 3 compiles a witness with the variable unset and
# requires byte-identical output to the same compile, and at landing 30 programs' .s were byte-identical to
# a build WITHOUT the seam at all. A test hook that alters the default path is a new global in disguise.
#
# ⭐ AND THE GREP VERSION IS REFUSED, by this seat and by the ceo: a gate that greps emit.cpp for two
# distinct message strings asserts that we still PRINT something, never that the guard still FIRES, and it
# would have read green through the entire window in which this sink was untrippable.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
NAME=emit_guard_sink_names_its_guard
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n   write("hello");\nend\n' > "$T/w.icn"
graded=0; fail=0
out="$(SCRIP_TEST_PLANT_GUARD_SINK=1 "$SCRIP" "$T/w.icn" </dev/null 2>&1)"; rc=$?
[ "$rc" = 134 ] || refuse "the planted guard sink did not abort (rc=$rc) -- the seam is gone or renamed, so this gate CANNOT MAKE THE ABORT HAPPEN and must never report the sink as fixed"
printf '%s\n' "$out" | grep -q 'REFUSED AT A GUARD' || refuse "the sink aborted but printed no guard-sink sentence -- cannot measure what it said"
graded=$((graded+1))
if printf '%s\n' "$out" | grep -qE 'emit\.cpp:[0-9]+'; then echo "  PASS guard sink names its site: $(printf '%s\n' "$out" | grep -oE 'emit\.cpp:[0-9]+' | head -1)"; else echo "  FAIL guard sink printed no emit.cpp:LINE -- the reader is sent nowhere"; fail=$((fail+1)); fi
graded=$((graded+1))
if printf '%s\n' "$out" | grep -q 'NOT a missing template'; then echo "  PASS guard sink says it is NOT a missing template"; else echo "  FAIL guard sink does not distinguish itself from the no-template case -- two defects, one sentence, which is the defect this gate exists for"; fail=$((fail+1)); fi
graded=$((graded+1))
if printf '%s\n' "$out" | grep -q 'has NO TEMPLATE'; then echo "  FAIL guard sink printed the NO-TEMPLATE sentence -- the two sinks are confused again"; fail=$((fail+1)); else echo "  PASS guard sink does not print the no-template sentence"; fi
graded=$((graded+1))
a="$("$SCRIP" --compile -o "$T/a.s" "$T/w.icn" </dev/null 2>&1; echo "rc=$?")"
b="$(SCRIP_TEST_PLANT_GUARD_SINK=0 "$SCRIP" --compile -o "$T/b.s" "$T/w.icn" </dev/null 2>&1; echo "rc=$?")"
if [ -s "$T/a.s" ] && cmp -s "$T/a.s" "$T/b.s" && [ "$a" = "$b" ]; then echo "  PASS seam is INERT when unset (emitted .s byte-identical)"; else echo "  FAIL the seam changed the default path -- a test hook that alters real output is a new global in disguise"; fail=$((fail+1)); fi
graded=$((graded+1))
o2="$("$SCRIP" "$T/w.icn" </dev/null 2>&1)"; rc2=$?
if [ "$rc2" = 0 ] && [ "$o2" = "hello" ]; then echo "  PASS witness runs normally with the seam unset"; else echo "  FAIL witness did not run normally with the seam unset (rc=$rc2)"; fail=$((fail+1)); fi
[ "$graded" = 5 ] || refuse "expected 5 arms, graded $graded"
echo "graded=$graded FAIL=$fail (the trip is MANUFACTURED through a test-only seam because no program reaches this sink -- measured 2026-09-11: 215 package programs tripped it zero times and the one live witness was cured the same day. Arms 1-3 grade what the sink SAYS, arm 4 proves the seam inert, arm 5 proves the witness still runs. The gate REFUSES rc=2 rather than passing if it cannot make the abort happen at all.)"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
