#!/usr/bin/env bash
# test_gate_test_request_read_prints_the_filers_verdicts.sh -- THE GATE OF s4e_test_request.sh --read (DESIGN-PLAN box-scheduler step 24, CTO-496; the president
# 2026-11-05, row box-scheduler-step-24-verdicts-readable-by-the-filer-and-a-blast-radius-query-names-the-eight-cto-496). The step's probe is
#   s4e_test_request.sh --read --probe | grep -q '^VERDICTS '
# and a pipe through grep -q reads only the LAST command's code, so the gate proves what the pipe cannot: a probe that is red prints NO VERDICTS line.
# WHAT IT PROVES, on a planted queue directory (S4E_TEST_REQUEST_DIR) and on mutated COPIES of the script; the live postoffice is never read:
#   1  --read --probe: rc 0, a VERDICTS header counting six planted requests of one seat, and PROBE ok
#   2  FAIL-ONCE, mutant A (the seat filter removed from a copy): the probe is rc 1, prints PROBE RED, and prints NO line starting VERDICTS
#   3  FAIL-ONCE, mutant B (a red verdict read as green): the same three properties
#   4  --read on a planted queue of the shapes the loop really writes (a served line with and without the port tree, a served line "by hand", RED naming the entries
#      whose rc was not 0, returned ungraded, DROPPED by the coo, no served line in done/, a pending request, and a decoy of another seat) counts each state and
#      prints one line per request, newest first
#   5  --last 2 prints two request lines and still counts all of them
#   6  --read writes nothing: the queue directory is byte-identical before and after
#   7  no seat (a copy outside any seat root, no S4E_SEAT) refuses rc 2 naming S4E_SEAT; an unknown switch and --last x refuse rc 2
#   8  the filing paths still stand: -h lists --read, --suites lists sno-rungs, an unknown suite key refuses rc 2 and files nothing
# EXIT: 0 every arm holds; 1 an arm failed; 2 could not measure (a mutant that changed nothing proves nothing). Population printed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=test_request_read_prints_the_filers_verdicts
gate_parse_args "$@"
SCRIPT="$HERE/s4e_test_request.sh"
gate_require "$SCRIPT" "s4e_test_request.sh" || exit 2
SCR="${S4E_SCRATCH:-/tmp/s4e/${S4E_SEAT:-gate}}"; mkdir -p "$SCR" || exit 2
WORK=$(mktemp -d "$SCR/gate_testreq_read_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
unproven() { echo "GATE UNPROVEN(2) [$GATE_NAME]: $1"; gate_stamp; exit 2; }
Q="$WORK/queue"; mkdir -p "$Q/done"
req() {  # req <dir> <id> <seat> <suite> <entries> [extra lines...]
  local d="$1" id="$2" seat="$3" suite="$4" ents="$5"; shift 5
  { printf 'seat=%s\nsuite=%s\ntable=t\nfiled=2026-11-05 10:00:00 CST\nentries=%s\n' "$seat" "$suite" "$ents"; for l in "$@"; do printf '%b\n' "$l"; done; } > "$d/$id.req"
}
req "$Q" 20261105T110009-filer-sno-rungs-9 filer sno-rungs "a b c"
req "$Q/done" 20261105T110008-filer-icn-rungs-8 filer icn-rungs "a b" 'graded=a' rc=0 'graded=b' rc=0 'served=2026-11-05 11:00:08 CST tree=aaa1111 rc=0 rows=2'
req "$Q/done" 20261105T110007-filer-pl-rungs-7 filer pl-rungs "a b" 'graded=a' rc=0 'graded=b' rc=3 'served=2026-11-05 11:00:07 CST tree=bbb2222 rc=3 rows=2'
req "$Q/done" 20261105T110006-filer-snc-rungs-6 filer snc-rungs "a" 'engine=jvm' 'served=returned 2026-11-05 11:00:06 CST ungraded (CEO-1912: the port engines run their own tests)'
req "$Q/done" 20261105T110005-filer-gnu-5 filer gnu "a" 'served=2026-11-05 11:00:05 CDT DROPPED by the coo: graded elsewhere'
req "$Q/done" 20261105T110004-filer-swi-4 filer swi "a"
req "$Q/done" 20261105T110003-filer-dotnet-3 filer dotnet "a" 'graded=a' rc=0 'served=2026-11-05 11:00:03 CST tree=jvm 6b601d4 rc=0 rows=1'
req "$Q/done" 20261105T110002-filer-gnu-2 filer gnu "a" 'graded=a' rc=0 'served=2026-11-05 11:00:02 CST tree=ccc3333 rc=0 (by hand, coo)'
req "$Q/done" 20261105T110001-other-filer-sno-rungs-1 other sno-rungs "z" 'graded=z' rc=1 'served=2026-11-05 11:00:01 CST tree=zzz9999 rc=1 rows=1'
mut() {  # mut <name> <sed expression>: a copy of the script with one line broken; a copy that equals the original proves nothing
  sed "$2" "$SCRIPT" > "$WORK/$1.sh"; cmp -s "$SCRIPT" "$WORK/$1.sh" && unproven "mutant $1 changed nothing: its sed expression no longer matches the script"; return 0
}

echo "--- ARM 1: the probe proves the reader ---"
o1=$(bash "$SCRIPT" --read --probe 2>&1); r1=$?
ck "1 rc 0, a VERDICTS header over total=6, PROBE ok" '[ "$r1" = 0 ] && grep -q "^VERDICTS seat=probe pending=1 green=1 red=1 returned=1 dropped=1 unserved=1 total=6 shown=6$" <<<"$o1" && grep -q "^PROBE ok" <<<"$o1"'
echo "--- ARM 2: FAIL-ONCE, mutant A: the seat filter removed ---"
mut seatless 's/\[ "\$sseat" = "\$me" \] || continue//'
o2=$(bash "$WORK/seatless.sh" --read --probe 2>&1); r2=$?
ck "2 rc 1, PROBE RED naming the leaked decoy, and NO line starting VERDICTS" '[ "$r2" = 1 ] && grep -q "^PROBE RED" <<<"$o2" && grep -q "decoy" <<<"$o2" && ! grep -q "^VERDICTS " <<<"$o2"'
echo "--- ARM 3: FAIL-ONCE, mutant B: a red verdict read as green ---"
mut allgreen 's/? "GREEN" : "RED"/? "GREEN" : "GREEN"/'
o3=$(bash "$WORK/allgreen.sh" --read --probe 2>&1); r3=$?
ck "3 rc 1, PROBE RED, and NO line starting VERDICTS" '[ "$r3" = 1 ] && grep -q "^PROBE RED" <<<"$o3" && ! grep -q "^VERDICTS " <<<"$o3"'
echo "--- ARM 4: a planted queue of the shapes the loop writes ---"
before=$(cd "$Q" && find . -type f | sort | xargs md5sum | md5sum)
o4=$(S4E_TEST_REQUEST_DIR="$Q" S4E_SEAT=filer bash "$SCRIPT" --read 2>&1); r4=$?
ck "4a rc 0, header pending=1 green=3 red=1 returned=1 dropped=1 unserved=1 total=8 shown=8" '[ "$r4" = 0 ] && sed -n 1p <<<"$o4" | grep -qx "VERDICTS seat=filer pending=1 green=3 red=1 returned=1 dropped=1 unserved=1 total=8 shown=8"'
ck "4b newest first: PENDING then GREEN, RED, RETURNED, DROPPED, UNSERVED, GREEN, GREEN" '[ "$(sed -n "2,9p" <<<"$o4" | awk "{print \$1}" | tr "\n" " ")" = "PENDING GREEN RED RETURNED DROPPED UNSERVED GREEN GREEN " ]'
ck "4c RED names the entry whose rc was not 0 and the served tree" 'grep -qx "RED 20261105T110007-filer-pl-rungs-7 suite=pl-rungs tree=bbb2222 rows=2 red=b" <<<"$o4"'
ck "4d a port tree with a space (jvm 6b601d4) and a by-hand verdict read as green" 'grep -qx "GREEN 20261105T110003-filer-dotnet-3 suite=dotnet tree=jvm 6b601d4 rows=1" <<<"$o4" && grep -q "^GREEN 20261105T110002-filer-gnu-2 suite=gnu tree=ccc3333 " <<<"$o4"'
ck "4e the decoy of another seat (its id names filer) is not counted or shown" '! grep -q "other-filer\|zzz9999" <<<"$o4"'
echo "--- ARM 5: --last limits the lines, not the counts ---"
o5=$(S4E_TEST_REQUEST_DIR="$Q" S4E_SEAT=filer bash "$SCRIPT" --read --last 2 2>&1)
ck "5 two request lines under a header counting all eight (total=8 shown=2)" '[ "$(wc -l <<<"$o5")" = 3 ] && sed -n 1p <<<"$o5" | grep -q " total=8 shown=2$"'
echo "--- ARM 6: reading writes nothing ---"
after=$(cd "$Q" && find . -type f | sort | xargs md5sum | md5sum)
ck "6 the queue directory is byte-identical after three reads" '[ "$before" = "$after" ]'
echo "--- ARM 7: refusals ---"
mkdir -p "$WORK/anywhere/harness/scripts"; cp "$SCRIPT" "$WORK/anywhere/harness/scripts/s4e_test_request.sh"
o7a=$(env -u S4E_SEAT S4E_TEST_REQUEST_DIR="$Q" bash "$WORK/anywhere/harness/scripts/s4e_test_request.sh" --read 2>&1); r7a=$?
o7b=$(S4E_TEST_REQUEST_DIR="$Q" S4E_SEAT=filer bash "$SCRIPT" --read --frobnicate 2>&1); r7b=$?
o7c=$(S4E_TEST_REQUEST_DIR="$Q" S4E_SEAT=filer bash "$SCRIPT" --read --last x 2>&1); r7c=$?
ck "7a no seat refuses rc 2 naming S4E_SEAT" '[ "$r7a" = 2 ] && grep -q "S4E_SEAT" <<<"$o7a"'
ck "7b an unknown switch refuses rc 2, and 7c --last x refuses rc 2" '[ "$r7b" = 2 ] && [ "$r7c" = 2 ]'
echo "--- ARM 8: the filing paths still stand ---"
nreq=$(ls "$Q"/*.req | wc -l)
o8c=$(S4E_TEST_REQUEST_DIR="$Q" S4E_SEAT=filer bash "$SCRIPT" no-such-suite a 2>&1); r8c=$?
ck "8a -h lists --read, 8b --suites lists sno-rungs" 'bash "$SCRIPT" -h | grep -q -- "--read" && bash "$SCRIPT" --suites | grep -q "^sno-rungs "'
ck "8c an unknown suite key refuses rc 2 and files nothing ($nreq pending before and after)" '[ "$r8c" = 2 ] && [ "$(ls "$Q"/*.req | wc -l)" = "$nreq" ]'
echo "------------------------------------------------------------"
echo "population: $n check(s) over a planted queue of 9 requests (8 of one seat in 8 states and a decoy), the probe's own 6, and 2 mutated copies"
if [ "$fails" -eq 0 ]; then echo "GATE OK [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
