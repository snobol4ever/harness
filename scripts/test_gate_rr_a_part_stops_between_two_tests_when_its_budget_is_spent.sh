#!/usr/bin/env bash
# test_gate_rr_a_part_stops_between_two_tests_when_its_budget_is_spent.sh -- A ROUND-ROBIN PART IS A BOUNDED UNIT IN TIME AS WELL AS IN ENTRIES (ceo
# CEO-1802/1805/1806; Lon 2026-10-15 via the ceo: every unit small and bounded, one chunk of at most 100 entries). A part of long tests (SWI's chunk:01 is
# 100 files and about 1,900 cases, an hour and more at one worker) stops between two tests once S4E_RR_BUDGET seconds are spent, prints RR_YIELD with the
# next test, and the loop resumes it there on the member's next turn; a request is never split.
# THE FIXTURE (a scratch suite dir; nothing real is read or written): PARTITION.tsv names e1 e3 e2 in chunk:01; lib_rr.sh is sourced (it is a library).
# THE FIXTURE's partition lists chunk:01 as e1 e3 e2 (not sorted).
#   ARM 1  budget 0 under chunk:01: rr_over_budget e2 is rc 0 and prints RR_YIELD next=e2 with the resume selection chunk:01@e2.
#   ARM 2  budget 3600: rc 1, nothing printed (the part goes on).
#   ARM 3  no S4E_RR_BUDGET: rc 1 (a whole run and a runner outside the loop are never cut).
#   ARM 4  a request (S4E_REQ set) at budget 0: rc 1 (a request is graded whole).
#   ARM 5  the resume chunk:01@e3 admits e3 and e2 and not e1, and rr_entries lists them in the partition's order (e3 e2), which is not sorted order:
#          a runner grading its own list in sorted order would yield at one name and resume past the others (10-17: SWI's GC/ files sort after files/).
#   ARM 6  a table with no PARTITION.tsv (the benchmarks and the demos, CEO-1812) takes a request's entry: names, each a file of the suite dir by stem or
#          path: entry:k1,entry:sub/d1.md admits k1 and sub/d1.md; an unknown name and a core selection refuse rc 2.
# PROVEN TO FAIL on lib_rr.sh before this rule (origin 821026ee0): arms 1-5 FAIL (rr_over_budget and rr_entries are not commands, rc 127).
# Arm 6 FAILS on origin 04e51ccab's lib_rr.sh (every selection on a table with no partition refuses). RR_LIB=<path> grades another copy.
# EXIT 0 every arm holds; 1 an arm failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${RR_LIB:-$HERE/lib_rr.sh}"
[ -f "$LIB" ] || { echo "GATE REFUSE(2): $LIB is missing"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf '# PARTITION.tsv\n# params\n# shape\nentry\tpart\tcluster\tshells\ne1\tchunk:01\tdir:x\t\ne3\tchunk:01\tdir:x\t\ne2\tchunk:01\tdir:x\t\n' > "$T/PARTITION.tsv"
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
probe() { (unset S4E_REQ S4E_RR_BUDGET; export S4E_CHUNK="$1"; [ -n "$2" ] && export S4E_RR_BUDGET="$2"; [ -n "$3" ] && export S4E_REQ="$3"; . "$LIB"; rr_load "$T" > /dev/null || exit 2; rr_over_budget e2; echo "rc=$?") 2>&1; }
o1="$(probe chunk:01 0 '')"; o2="$(probe chunk:01 3600 '')"; o3="$(probe chunk:01 '' '')"; o4="$(probe entry:e2 0 hq_x)"
ck "1 budget 0: RR_YIELD next=e2, resume chunk:01@e2, rc 0" 'grep -q "^RR_YIELD next=e2 -- the part.s budget of 0 s is spent" <<<"$o1" && grep -q "S4E_CHUNK=chunk:01@e2$" <<<"$o1" && grep -qx "rc=0" <<<"$o1"'
ck "2 budget 3600: rc 1, nothing printed" '[ "$o2" = "rc=1" ]'
ck "3 no budget: rc 1, nothing printed" '[ "$o3" = "rc=1" ]'
ck "4 a request at budget 0 is never split: rc 1" '[ "$o4" = "rc=1" ]'
o5="$( (export S4E_CHUNK=chunk:01@e3; . "$LIB"; rr_load "$T" > /dev/null; for e in e1 e2 e3; do rr_admits "$e" && printf '%s ' "$e"; done; echo "| $(rr_entries | tr '\n' ' ')") 2>&1)"
ck "5 the resume chunk:01@e3 admits e2 e3 and not e1, and lists them in the partition's order e3 e2" '[ "$o5" = "e2 e3 | e3 e2 " ]'
N="$T/nopart"; mkdir -p "$N/sub"; : > "$N/k1.pl"; : > "$N/sub/d1.md"
o6="$( (export S4E_CHUNK=entry:k1,entry:sub/d1.md; . "$LIB"; rr_load "$N" > /dev/null; echo "rc=$? $(rr_admits k1 && echo k1) $(rr_admits sub/d1.md && echo d1) $(rr_admits k2 || echo no-k2)") 2>&1)"
o6b="$( (export S4E_CHUNK=entry:nosuch; . "$LIB"; rr_load "$N" > /dev/null; echo "rc=$?") 2>&1)"; o6c="$( (export S4E_CHUNK=core; . "$LIB"; rr_load "$N" > /dev/null; echo "rc=$?") 2>&1)"
ck "6 no partition: entry: names by file are admitted, an unknown name and core refuse rc 2" '[ "$o6" = "rc=0 k1 d1 no-k2" ] && [ "$o6b" = "rc=2" ] && [ "$o6c" = "rc=2" ]'
[ "$fails" = 0 ] || printf '      arm6: %s | %s | %s\n' "$o6" "$o6b" "$o6c"
[ "$fails" = 0 ] || printf '      arm1: %s\n      arm2: %s\n      arm3: %s\n      arm4: %s\n      arm5: %s\n' "$o1" "$o2" "$o3" "$o4" "$o5"
if [ "$fails" = 0 ]; then echo "✅ GATE PASS [rr_a_part_stops_between_two_tests_when_its_budget_is_spent]: $n of $n arms hold (population: 3 entries, 5 probes; 2 files, 3 selections)"; exit 0; fi
echo "⛔ GATE FAIL [rr_a_part_stops_between_two_tests_when_its_budget_is_spent]: $fails of $n arm(s) failed"; exit 1
