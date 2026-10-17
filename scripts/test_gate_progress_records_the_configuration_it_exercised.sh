#!/usr/bin/env bash
# test_gate_progress_records_the_configuration_it_exercised.sh -- THE PROGRESS DATABASE RECORDS WHAT THE BOARD
# EXERCISED, AND ITS HEADER NAMES EVERY COLUMN IT WRITES (coo 2026-09-21; ceo rank 0 at CEO-1047 and CEO-1050:
# "every clause of the batch I just landed requires a board to say what it EXERCISED, and the database is where
# that is supposed to survive the sitting ... the DB has no column for ARENA or STRESS, so three runs of one
# suite on one tree are distinguishable only by timestamp").
#
# ⛔⭐ THE MEASUREMENT THAT MINTED THIS GATE, live table, 2026-09-21: 2934 duplicate (tree, corpus, suite,
# program, mode) keys in one day; SEVEN byte-identical rows for snocone break_any_pos_replace_1 m3 inside five
# minutes, appended by a gate arm whose own name ends "under_forced_collection"; and 139 keys since 09-20 where
# ONE tree and ONE corpus carry CONTRADICTORY outcomes -- raku-rungs token_say_4 m3 reads both PASS and FAIL at
# the CLEAN tree 5418432bb. Under a byte-for-byte oracle diff that is impossible unless something unrecorded
# changed, and the unrecorded thing is the configuration. util_progress_flips.py keys on (suite, program, mode)
# and so resolves every one of those collisions BY ARRIVAL ORDER: the divergence the whole fleet is hunting is
# invisible to the measure by construction.
#
# ⛔⭐ AND THE HALF THAT EXPLAINS WHY NOBODY SAW IT, WHICH IS A DEFECT IN A SIBLING GATE'S SHAPE RATHER THAN IN
# ITS ARMS: test_gate_progress_append_writes_a_row.sh asserts the writer emits 13 fields and is GREEN -- against
# a table it creates fresh under mktemp, where the header is written complete on first touch. The LIVE table has
# existed since 2026-09-06 and its header is the ORIGINAL TWELVE. So `fingerprint`, added as column 13, has been
# written into every row since and is UNREACHABLE BY NAME to every csv.DictReader in the fleet -- it lands in
# csv's unnamed restkey and is silently dropped. A hermetic gate that constructs its subject fresh cannot see a
# defect that exists only in the long-lived artefact. EVERY ARM BELOW THEREFORE RUNS AGAINST A PRE-EXISTING
# TABLE CARRYING AN OLDER HEADER, which is the shape the live table actually has.
#
#   1  a column the writer writes is NAMED by the header of a table that already existed (no unnamed restkey)
#   2  the writer REFUSES rc=2 to record a row that declares no configuration while a GC axis is set in its env
#   3  a declared configuration reaches the column and reads back BY NAME through csv.DictReader
#   4  the reader keys on the configuration: two configurations of one program do not overwrite one another
#   5  the reader NAMES a same-tree same-configuration contradiction instead of resolving it by arrival order
#   7  THE RUNNER DECLARES: corpus_suite_harness.py states the axis it ran under, at BOTH ends of the axis
#   6  SEAM/CONTROL: with no axis set and nothing declared the append is ACCEPTED and reads `undeclared` --
#      the writer guesses `shipped` for nobody (CEO-812's principle applied to the record instead of the heap)
#
# Hermetic: S4E_PROGRESS_DB points every arm at a scratch table under mktemp and the live table is never touched.
# No binary is run and no corpus is read, so this gate is cheap; it is wired BLOCKING in `make test` and NOT in
# `make preflight` (CEO-1046: a hermetic gate that reads a live external tree is not hermetic).
# Cost: ~4 s (arm 7 runs a real one-entry suite, so this gate needs the built binary and refuses rc=2 without it).
#
# PROVEN RED BEFORE THE CURE (CEO-1049), on 27630286a, 2026-09-21: arms 1,2,3,4,5 RED, arm 6 red on the value
# (`` rather than `undeclared`). Receipt in the row's baton and in GOAL-COO.md COO-130.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
PY="$HERE/util_progress_append.py"; Q="$S4E/.github/scripts/util_progress_flips.py"
[ -f "$PY" ] || { echo "GATE UNPROVEN(2) [progress_records_the_configuration]: writer missing at $PY"; exit 2; }
[ -f "$Q" ] || { echo "GATE UNPROVEN(2) [progress_records_the_configuration]: query tool missing at $Q (pull .github)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_progress_config.XXXXXX")" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
export S4E_PROGRESS_DB="$W/db.tsv"
unset S4E_PROGRESS_OFF
# ⛔ THE AXIS MUST NOT ARRIVE FROM THE CALLER'S SHELL. A stale knob inherited here would make arm 6's control
# refuse and arm 2 pass for the wrong reason -- the same hazard util_gc_differential.py strips before every run.
for k in $(env | sed -n 's/^\(SCRIP_GC[A-Z_]*\)=.*/\1/p'); do unset "$k"; done
unset SCRIP_HEAP_MB
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

# THE PRE-EXISTING TABLE: the ORIGINAL TWELVE-COLUMN HEADER, exactly as the live table has carried it since
# 2026-09-06, plus one row in the old shape. Every arm appends onto THIS, never onto a fresh file.
OLD_HDR='ts_utc	scrip	corpus	measurer	class	suite	lang	program	mode	outcome	secs	note'
seed_old_table() {
  printf '%s\n' "$OLD_HDR" > "$S4E_PROGRESS_DB"
  printf '2026-09-06T00:00:00\tdeadbeef1\tcafebabe2\tcoo\trungs\tsnobol4-rungs\tsnobol4\tgate_seed\tm3\tPASS\t0\t\n' >> "$S4E_PROGRESS_DB"
}

echo "=== gate: the progress database records the configuration it exercised, and its header names every column ==="

echo "--- ARM 1: a column the writer writes is NAMED by the header of a table that ALREADY EXISTED ---"
seed_old_table
python3 "$PY" append --class rungs --suite snobol4-rungs --lang snobol4 --program gate_a1 --mode m3 --outcome FAIL >/dev/null 2>&1
unnamed=$(python3 - "$S4E_PROGRESS_DB" <<'PY'
import csv, sys
with open(sys.argv[1], encoding="utf-8", newline="") as f:
    rd = csv.DictReader(f, delimiter="\t")
    hdr = list(rd.fieldnames or [])
    extra = 0
    for r in rd:
        if r.get(None):
            extra = max(extra, len(r[None]))
print(f"{len(hdr)} {extra}")
PY
)
set -- $unnamed; nhdr="$1"; nextra="$2"
[ "$nextra" = 0 ] && ck ok "every written column is named by the header (header names $nhdr, unnamed restkey 0)" \
  || ck no "$nextra column(s) written but NOT NAMED by the header -- a written-but-unreadable column: csv.DictReader drops them into the unnamed restkey and every fleet reader loses them silently (header names $nhdr)"

echo "--- ARM 2: the writer REFUSES an undeclared row while a GC axis is set in its environment ---"
seed_old_table
out=$(SCRIP_GC_STRESS=3 python3 "$PY" append --class rungs --suite snobol4-rungs --lang snobol4 --program gate_a2 --mode m3 --outcome PASS 2>&1); rc=$?
if [ "$rc" = 2 ]; then
  printf '%s' "$out" | grep -qi 'SCRIP_GC_STRESS' && ck ok "refused rc=2 and NAMED the axis it saw" \
    || ck no "refused rc=2 but did not NAME the axis -- a refusal a caller cannot act on"
else
  ck no "rc=$rc: recorded a row as configuration-unknown while SCRIP_GC_STRESS=3 was set in its own environment -- the row claims nothing and the run was not shipped-configuration"
fi
n=$(awk -F'\t' '$8=="gate_a2"' "$S4E_PROGRESS_DB" 2>/dev/null | wc -l)
[ "$n" = 0 ] && ck ok "the refused row was NOT written" || ck no "refused rc=2 yet wrote $n row(s) -- a refusal that still records is not a refusal"

echo "--- ARM 3: a declared configuration reaches the column and reads back BY NAME ---"
seed_old_table
env -u SCRIP_HEAP_MB SCRIP_GC_STRESS=3 SCRIP_HEAP_KB=128 python3 "$PY" append --class rungs --suite snobol4-rungs --lang snobol4 \
  --program gate_a3 --mode m3 --outcome PASS --config 'arena=1,stress=3' >/dev/null 2>&1
got=$(python3 - "$S4E_PROGRESS_DB" <<'PY'
import csv, sys
with open(sys.argv[1], encoding="utf-8", newline="") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        if r.get("program") == "gate_a3":
            print(r.get("config") or "<ABSENT>")
            break
    else:
        print("<NO ROW>")
PY
)
[ "$got" = 'arena=1,stress=3' ] && ck ok "config reads back by name: $got" \
  || ck no "config reads back as '$got', not 'arena=1,stress=3' -- a configuration the row does not carry is a configuration no reader can key on"

echo "--- ARM 4: two configurations of one program do not overwrite one another in the reader ---"
seed_old_table
for cfg_out in 'shipped:PASS' 'arena=1,stress=3:FAIL'; do
  cfg="${cfg_out%%:*}"; oc="${cfg_out##*:}"
  python3 "$PY" append --class rungs --suite snobol4-rungs --lang snobol4 --program gate_a4 --mode m3 \
    --outcome "$oc" --config "$cfg" >/dev/null 2>&1
done
qout=$(S4E_PROGRESS_DB="$S4E_PROGRESS_DB" python3 "$Q" --register --program gate_a4 2>&1)
printf '%s' "$qout" | grep -q 'arena=1,stress=3' && printf '%s' "$qout" | grep -q 'shipped' \
  && ck ok "the reader keeps both configurations of gate_a4 apart" \
  || ck no "the reader collapsed gate_a4's two configurations into one cell -- PASS at shipped and FAIL at arena=1,stress=3 are the SAME key, resolved by arrival order"

echo "--- ARM 5: a same-tree same-configuration contradiction is NAMED, never resolved by arrival order ---"
seed_old_table
python3 "$PY" append --class rungs --suite raku-rungs --lang raku --program gate_a5 --mode m3 --outcome PASS --config shipped >/dev/null 2>&1
python3 "$PY" append --class rungs --suite raku-rungs --lang raku --program gate_a5 --mode m3 --outcome FAIL --config shipped >/dev/null 2>&1
qout=$(S4E_PROGRESS_DB="$S4E_PROGRESS_DB" python3 "$Q" --contradictions 2>&1); qrc=$?
if printf '%s' "$qout" | grep -q 'gate_a5'; then
  ck ok "the contradiction is NAMED (rc=$qrc)"
else
  ck no "gate_a5 reads PASS and FAIL on ONE tree at ONE configuration and the reader named neither -- 139 such keys stand in the live table today"
fi

echo "--- ARM 6: SEAM/CONTROL -- nothing set, nothing declared, the row is ACCEPTED and says 'undeclared' ---"
seed_old_table
python3 "$PY" append --class rungs --suite snobol4-rungs --lang snobol4 --program gate_a6 --mode m3 --outcome PASS >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && ck ok "accepted rc=0 with no axis set -- the gate does not simply refuse everything" || ck no "rc=$rc: refused a row no axis contradicts"
got=$(python3 - "$S4E_PROGRESS_DB" <<'PY'
import csv, sys
with open(sys.argv[1], encoding="utf-8", newline="") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        if r.get("program") == "gate_a6":
            print(r.get("config") if r.get("config") is not None else "<ABSENT>")
            break
    else:
        print("<NO ROW>")
PY
)
[ "$got" = "undeclared" ] && ck ok "reads 'undeclared' -- the writer guesses 'shipped' for nobody" \
  || ck no "reads '$got', not 'undeclared' -- recording an unknown configuration as a known one is the clean-bill-of-health shape"

echo "--- ARM 7: THE RUNNER DECLARES -- the harness states the axis it ran under, so no board meets arm 2's refusal ---"
# ⛔ THE ARM THAT KEEPS ARM 2 FROM STOPPING THE FLEET. Arm 2 refuses a row that declares nothing while an axis
# is set; that refusal is only safe because the site which actually runs the programs declares for itself. The
# harness is the ONLY party that can say `shipped` as a POSITIVE STATEMENT -- the writer sees only its own
# environment, and a runner may set the axis per-child. Verified at BOTH ends of the axis, because a declaration
# that is right for the shipped case and silent for the set case would pass a one-sided check.
if ! "$HERE/util_require_fresh.sh" --gate test_gate_progress_records_the_configuration_it_exercised >/dev/null 2>&1; then
  echo "  ARM 7 UNPROVEN(2): this tree's binary is stale or unbuilt -- this arm runs a real one-entry suite. Run 'make'."
  echo "GATE UNPROVEN(2) [progress_records_the_configuration_it_exercised]: arms 1-6 measured, arm 7 could not"
  exit 2
fi
C="$W/corpus/tests/snobol4"; mkdir -p "$C"
printf " OUTPUT = 'alive';END;* gate_alive\n" > "$C/ALL.sno"; printf 'alive\n' > "$C/ALL.ref"
seed_old_table
python3 "$HERE/corpus_suite_harness.py" run "$C/ALL.sno" "$C/ALL.ref" --modes m3 >/dev/null 2>&1
got=$(awk -F'\t' '$8=="gate_alive"{print $14}' "$S4E_PROGRESS_DB" | tail -1)
[ "$got" = "shipped" ] && ck ok "no axis set: the harness declares 'shipped' -- a positive statement the writer cannot make for it" \
  || ck no "no axis set: the harness declared '$got', not 'shipped'"
seed_old_table
env -u SCRIP_HEAP_MB SCRIP_GC_STRESS=3 SCRIP_HEAP_KB=128 python3 "$HERE/corpus_suite_harness.py" run "$C/ALL.sno" "$C/ALL.ref" --modes m3 >/dev/null 2>&1
got=$(awk -F'\t' '$8=="gate_alive"{print $14}' "$S4E_PROGRESS_DB" | tail -1)
[ "$got" = "SCRIP_GC_STRESS=3,SCRIP_HEAP_KB=128" ] && ck ok "axis set: the harness declares it verbatim ($got) -- AND THIS ARM NOW HOLDS THE ARENA HALF OF THE AXIS: SCRIP_HEAP_KB was in NEITHER GC_AXIS_EXACT nor the SCRIP_GC prefix until the CEO-1146 sweep put it there, so a KB-pinned run declared NO ARENA AT ALL while the sweep was moving 18 gates onto exactly that spelling" \
  || ck no "axis set: the harness declared '$got' -- a board under a forced collection recording itself as anything else is the whole defect"

echo
if [ "$fails" = 0 ]; then
  echo "GATE PASS [progress_records_the_configuration_it_exercised]: $checks checks, 0 red -- the header names every written column, the writer refuses to record a run whose configuration it cannot state, and the reader keys on the configuration instead of resolving collisions by arrival order"
  exit 0
fi
echo "GATE FAIL [progress_records_the_configuration_it_exercised]: $fails of $checks checks red -- the progress database cannot say what its boards exercised"
exit 1
