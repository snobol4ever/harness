#!/usr/bin/env bash
# test_gate_xsb_a_vendored_driver_stands_before_its_programs_end_of_file.sh -- THE DRIVER THE VENDORING APPENDS IS READ (hq_icon 2026-10-28, row
# prolog-xsbtests-to-100-the-58-failing-programs-ceo-1926).
#
# 80 of the xsb_tests package's vendored programs end their own text with a clause `end_of_file.`; XSB's consult stops reading there and so does SCRIP's.
# The vendoring (CEO-700) appended each program's driver AFTER that clause, so SCRIP never read it: the program ran no goal, printed nothing, and read FAIL
# against XSB's answer (17 of the 71 graded ones read PASS in both modes once the driver stood where end_of_file stood, nothing else changed).
# util_xsb_driver_before_end_of_file.py --check names every vendored file and every ALL.pl entry whose driver follows such a clause; --apply moves it.
#
# ARMS (a mktemp package outside corpus/, CEO-547, two programs e1 and e2 and their ALL.pl and ALL.csv; the real SCRIP, mode 3 and mode 4):
#   1 e1 carries its driver AFTER end_of_file.: --check names e1 (file and ALL.pl entry), not e2, and exits 1
#   2 THE DEFECT, as measured: SCRIP prints nothing for e1 in mode 3 -- the driver is never read (the premise of the cure)
#   3 --apply moves e1's driver (file and ALL.pl entry) and touches nothing else: e2.pl is byte-identical, e1's text before the clause is, the line count is
#   4 --check then exits 0, and --apply a second time changes nothing (idempotent)
#   5 THE CURE: SCRIP prints driver_ran for e1 in mode 3 and in mode 4
#   6 the real package: --check exits 0 (no vendored program or ALL.pl entry carries its driver after an end_of_file. clause)
# FAIL-ONCE: arm 2 reads the defect on the unmoved fixture and arms 3-5 read red before the tool existed; the real package read 80 files and 71 entries
# red at corpus 2bd8e5850 (arm 6).
set -uo pipefail
GATE_NAME=test_gate_xsb_a_vendored_driver_stands_before_its_programs_end_of_file
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
TOOL="$HERE/util_xsb_driver_before_end_of_file.py"
REAL="$HERE/../../corpus/packages/prolog/xsb_tests"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
[ -f "$REAL/ALL.pl" ] && [ -f "$REAL/ALL.csv" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: $REAL holds no ALL.pl / ALL.csv -- the real-package arm cannot see its population"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P="$T/pkg"; mkdir -p "$P"
fail=0
ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fail=1; }
DRV=$'% DRIVER (appended by the vendoring, CEO-700): fixture\n:- initialization((write(driver_ran), nl)).\n'
printf 'p(1).\nend_of_file.\nq(2).\n\n%s' "$DRV" > "$P/e1.pl"
printf 'p(1).\n\n%s' "$DRV" > "$P/e2.pl"
printf 'rank,entry\n1,e1\n2,e2\n' > "$P/ALL.csv"
{ printf '%%------------------ 1 e1\n'; cat "$P/e1.pl"; printf '%%---------------------------- 2 e2\n'; cat "$P/e2.pl"; } > "$P/ALL.pl"
cp "$P/e2.pl" "$T/e2.before"; head -1 "$P/e1.pl" > "$T/e1.head"; wc -l < "$P/e1.pl" > "$T/e1.lines"
out="$(python3 "$TOOL" --check "$P" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && echo "$out" | grep -q 'follows end_of_file: e1.pl' && echo "$out" | grep -q 'ALL.pl entry e1' && ! echo "$out" | grep -q 'e2'; then ok "(1) --check exits 1 and names e1, file and ALL.pl entry, not e2"; else bad "(1) --check rc=$rc: $out"; fi
m3=$( cd "$T" && timeout -k 5 20 "$SCRIP" "$P/e1.pl" < /dev/null 2>&1 )
if [ -z "$m3" ]; then ok "(2) the defect: SCRIP prints nothing for e1 -- its driver follows end_of_file. and is never read"; else bad "(2) SCRIP printed '$m3' for the unmoved e1 -- the premise of the cure does not hold"; fi
python3 "$TOOL" --apply "$P" > /dev/null 2>&1
if cmp -s "$P/e2.pl" "$T/e2.before" && head -1 "$P/e1.pl" | cmp -s - "$T/e1.head" && [ "$(wc -l < "$P/e1.pl")" = "$(cat "$T/e1.lines")" ] \
   && awk '/^% DRIVER/{d=NR} /^end_of_file\./{e=NR} END{exit !(d && e && d<e)}' "$P/e1.pl"; then ok "(3) --apply moved e1's driver before its end_of_file.; e2, the text before the clause and the line count are untouched"; else bad "(3) --apply did not produce the expected e1.pl:"; sed 's/^/         /' "$P/e1.pl"; fi
before="$(cat "$P/e1.pl" "$P/ALL.pl")"; out="$(python3 "$TOOL" --check "$P" 2>&1)"; rc=$?; python3 "$TOOL" --apply "$P" > /dev/null 2>&1
if [ "$rc" = 0 ] && [ "$before" = "$(cat "$P/e1.pl" "$P/ALL.pl")" ]; then ok "(4) --check exits 0 after the move and a second --apply changes nothing"; else bad "(4) --check rc=$rc after the move, or --apply is not idempotent"; fi
m3=$( cd "$T" && timeout -k 5 20 "$SCRIP" "$P/e1.pl" < /dev/null 2>&1 )
if ( cd "$T" && "$SCRIP" --compile -o e1.s "$P/e1.pl" < /dev/null > /dev/null 2>&1 && gcc -o e1.bin e1.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then m4=$( cd "$T" && timeout -k 5 20 ./e1.bin < /dev/null 2>&1 ); else m4="(did not compile or link)"; fi
if [ "$m3" = driver_ran ] && [ "$m4" = driver_ran ]; then ok "(5) the cure: SCRIP prints driver_ran for e1 in mode 3 and in mode 4"; else bad "(5) mode 3 printed '$m3', mode 4 printed '$m4'"; fi
out="$(python3 "$TOOL" --check "$REAL" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "(6) the real package: no vendored program or ALL.pl entry carries its driver after an end_of_file. clause"; else bad "(6) the real package, --check rc=$rc: $(echo "$out" | tail -3)"; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: a vendored driver stands before its program's end_of_file., so SCRIP reads it as XSB's [FILE]. test. runs the goal"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
