#!/usr/bin/env bash
# test_gate_xsb_an_oracle_switch_is_the_entrys_compile_args.sh -- XSB's -S REACHES SCRIP AS THE ENTRY'S compile_args (the cto, R-2110,
# 2026-11-01 16:3x CST, on the cao's ask in prolog-xsb-wfs-step-10): "An oracle switch is an ENTRY FACT, never a SCRIP switch: ORACLE_RUNS.tsv's
# -S is the entry's oracle_args ... and the XSB runner hands the same fact to SCRIP's side as the entry's compile_args, so the two sides are
# graded on the same program." XSB's sub_tests/test.sh runs 39 programs under -S (call-subsumption the tabling default); before this gate
# only the oracle side read ORACLE_RUNS.tsv and SCRIP graded all 39 under variant tabling. scrip's driver maps -S to the program fact
# ':- use_subsumptive_tabling.' prepended to line one (src/driver/scrip.c), so no language flag passes the driver (R-1838).
# THE POPULATION: corpus/packages/prolog/xsb_tests/ORACLE_RUNS.tsv (name, dir, kind, file, cmd, options, script) and the package's ALL.csv.
# THE INVARIANT: an entry's compile_args carry -S exactly when its ORACLE_RUNS options carry -S; a graded entry whose oracle ran with -S and
# whose compile_args lack it is RED by name, and so is an entry that carries -S its oracle never ran with.
# rc 0 green, rc 1 red (names each entry), rc 2 cannot measure (no table, no -S run at all, a -S run with no ALL.csv row).
# FAIL-ONCE: red on corpus afd1fed9d and every commit before the cao's landing (39 of 39 entries lack -S), measured 2026-11-01.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
PKG="$ROOT/corpus/packages/prolog/xsb_tests"
[ -f "$PKG/ORACLE_RUNS.tsv" ] && [ -f "$PKG/ALL.csv" ] || { echo "REFUSE(2): no ORACLE_RUNS.tsv or ALL.csv under $PKG"; exit 2; }
python3 - "$PKG/ORACLE_RUNS.tsv" "$PKG/ALL.csv" <<'PYEOF'
import csv, sys
runs, table = sys.argv[1], sys.argv[2]
want = set()
for line in open(runs, encoding="utf-8", errors="replace"):
    if line.startswith("#") or not line.strip():
        continue
    f = line.rstrip("\n").split("\t")
    if len(f) >= 6 and "-S" in f[5].split():
        want.add(f[0])
if not want:
    print("REFUSE(2): ORACLE_RUNS.tsv names no run with -S -- the population is empty"); sys.exit(2)
have, rows = set(), set()
with open(table, newline="", encoding="utf-8", errors="replace") as fh:
    for r in csv.DictReader(fh):
        rows.add(r["entry"])
        if "-S" in (r.get("compile_args") or "").split():
            have.add(r["entry"])
orphan = sorted(want - rows)
if orphan:
    print("REFUSE(2): %d -S run(s) have no ALL.csv row: %s" % (len(orphan), " ".join(orphan[:5]))); sys.exit(2)
lack, extra = sorted(want - have), sorted(have - want)
print("XSB_ORACLE_SWITCH_BOARD runs_with_S=%d entries_carrying_S=%d lacking=%d extra=%d" % (len(want), len(have & want), len(lack), len(extra)))
for e in lack:
    print("  LACKS -S  %s" % e)
for e in extra:
    print("  EXTRA -S  %s" % e)
if lack or extra:
    print("GATE FAIL [xsb_an_oracle_switch_is_the_entrys_compile_args]: %d entr(y/ies) graded on a program their oracle did not run (R-2110)" % (len(lack) + len(extra))); sys.exit(1)
print("GATE OK [xsb_an_oracle_switch_is_the_entrys_compile_args]: every one of the %d runs XSB makes with -S carries -S as its compile_args" % len(want))
PYEOF
