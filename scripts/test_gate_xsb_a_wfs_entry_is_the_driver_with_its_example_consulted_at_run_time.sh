#!/usr/bin/env bash
# test_gate_xsb_a_wfs_entry_is_the_driver_with_its_example_consulted_at_run_time.sh -- A wfs_tests ENTRY IS THE PROGRAM XSB RUNS (hq_packages 2026-10-28, ceo CEO-2005, DESIGN-PLAN xsb-tabling-wfs step 2,
# ARCH-PROLOG-WFS-TABLING.md section 8 R2). XSB's wfs_tests/test.sh runs ./gentest.sh wfs_test pNN "test(pNN)." = [wfs_test]. test(pNN). told.: the driver is the program and test/1 consults pNN.P itself.
# The vendoring (CEO-700) compiled the example's clauses into the entry as well, so test/1's consult asserted them a second time (permission_error(modify, static_procedure, query/5)) and the
# driver printed nothing: 72 entries read FAIL. The entry is now the driver's text and `:- initialization((test(pNN), told)).`, the example staged beside (STAGED.tsv).
# ARMS: (1) every ALL.pl entry whose ORACLE_RUNS.tsv kind is wfs is in the driver form (util_xsb_wfs_entry_is_the_driver.py --check, rc 0, the population printed: 72 of 72)
#       (2) the tool can see its plant: a mktemp copy of the package's tables with one wfs entry put back in the old form (the example's clauses, then the consult trailer) reads rc 1 and names it;
#           --apply on that copy cures exactly that entry (rc 0 after) and leaves every other entry's text byte for byte
#       (3) a real entry runs: wfs_tests_p06 is graded PASS in mode 3 through the harness smoke (the stage column stages p06.P beside the driver), as XSB's temp answers it
# RED BEFORE (measured 2026-10-28 on corpus d3444735e..7a027e8d5, the entries as vendored): --check named 72 entries; wfs_tests_p06 printed nothing after four permission_error warnings and read FAIL;
# test_design_xsb_tabling_wfs_steps.sh --step 2 read entries=0/4 (p06, p33, p52, p77) with its witness already green.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure.
set -u
GATE_NAME=test_gate_xsb_a_wfs_entry_is_the_driver_with_its_example_consulted_at_run_time
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PKG="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/xsb_tests"
TOOL="$HERE/util_xsb_wfs_entry_is_the_driver.py"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -f "$PKG/ALL.pl" ] && [ -f "$PKG/ORACLE_RUNS.tsv" ] && [ -f "$PKG/wfs_tests_wfs_test.pl" ] || refuse "no xsb_tests tables at $PKG"
[ -f "$TOOL" ] || refuse "no $TOOL"
red=0; total=0
ok() { total=$((total+1)); echo "  ok  $*"; }
bad() { total=$((total+1)); red=$((red+1)); echo "  RED $*"; }
# (1)
out="$(python3 "$TOOL" --check "$PKG" 2>&1)"; rc=$?
pop="$(printf '%s\n' "$out" | head -1)"
if [ "$rc" = 0 ]; then ok "(1) every wfs entry of ALL.pl is the driver form: $pop"; else bad "(1) rc=$rc: $(printf '%s\n' "$out" | head -3 | tr '\n' ' ')"; fi
# (2)
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in ALL.pl ALL.csv ORACLE_RUNS.tsv wfs_tests_wfs_test.pl PARTITION.tsv; do cp "$PKG/$f" "$T/$f" || refuse "cannot copy $f"; done
python3 - "$T" "$PKG/wfs_tests_p06.pl" <<'PY' || refuse "could not plant the old form"
import re, sys
from pathlib import Path
t, src = Path(sys.argv[1]), Path(sys.argv[2])
text = (t / "ALL.pl").read_text(encoding="utf-8", errors="surrogateescape")
m = re.search(r"(?m)^(%-+ \d+ wfs_tests_p06\n)", text)
n = re.search(r"(?m)^%-+ \d+ wfs_tests_p07\n", text)
old = src.read_text(encoding="utf-8", errors="surrogateescape")
(t / "ALL.pl").write_text(text[:m.end()] + old + text[n.start():], encoding="utf-8", errors="surrogateescape")
PY
cp "$T/ALL.pl" "$T/ALL.planted"
python3 "$TOOL" --check "$T" > "$T/check.out" 2>&1; rc=$?
if [ "$rc" = 1 ] && grep -q '^  wfs_tests_p06$' "$T/check.out" && [ "$(grep -c '^  wfs_tests_' "$T/check.out")" = 1 ]; then ok "(2a) the planted old-form entry reads rc 1 and is the one name listed"; else bad "(2a) check rc=$rc: $(head -3 "$T/check.out" | tr '\n' ' ')"; fi
python3 "$TOOL" --apply "$T" > "$T/apply.out" 2>&1; arc=$?
python3 "$TOOL" --check "$T" > /dev/null 2>&1; crc=$?
if [ "$arc" = 0 ] && [ "$crc" = 0 ] && cmp -s "$T/ALL.pl" "$PKG/ALL.pl"; then ok "(2b) --apply cured exactly the planted entry: ALL.pl is byte for byte the package's"; else bad "(2b) apply rc=$arc, check rc=$crc, ALL.pl $(cmp -s "$T/ALL.pl" "$PKG/ALL.pl" && echo equal || echo differs)"; fi
# (3)
SC="$ROOT/SCRIP/scrip"; [ -x "$SC" ] || refuse "no scrip binary at $SC -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SC" "$ROOT/SCRIP/out/libscrip_rt.so" || exit 2
sm="$(cd "$ROOT" && S4E_HOME="$ROOT" timeout -k 10 900 python3 "$HERE/corpus_suite_harness.py" smoke nl write --tables packages/prolog/xsb_tests --entries wfs_tests_p06 --modes m3 2>&1)"
if printf '%s\n' "$sm" | grep -qE '^AREA_SMOKE_ENTRY .*entry=wfs_tests_p06 .*m3=PASS'; then ok "(3) wfs_tests_p06 is PASS in mode 3 through the harness smoke"; else bad "(3) wfs_tests_p06: $(printf '%s\n' "$sm" | grep -m1 'AREA_SMOKE_ENTRY' | cut -c1-160)"; fi
echo "$GATE_NAME: arms=$total red=$red"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
