#!/usr/bin/env bash
# test_gate_rungs_suite_deferral_and_scope.sh -- the executable DONE-WHEN for row
# `master-suite-builder-honours-deferral-contract-and-scopes-absorption` (hq_P mint 2026-09-02,
# CEO-137 addendum, ladder I rank 1).
#
# WHAT IT PROVES, one arm per requirement named in the task file (all four watched FAIL before this row,
# on hq_P's own measured witnesses -- see the task file for the receipts this gate turns into assertions):
#   A/B. NEVER ABSORBS A KEEPER OR A DEFERRED FILE (requirement 1) -- a family declared in a KEEP.md, and
#        a family listed under a PENDING.md's `## DEFERRED` heading, both stay loose and both are recorded
#        with a named reason in ALL.excluded.txt; neither's origin appears in ALL.csv.
#   C.   ...AND DOES NOT OVER-EXCLUDE -- an ordinary undeclared family in the SAME tree absorbs normally.
#   D/E. --absorb-only <families> SCOPES ABSORPTION ITSELF (requirement 2) -- naming one family among
#        several absorbable ones absorbs exactly that one; naming a family this run cannot absorb (here,
#        one under active KEEP declaration) REFUSES rc=2 and writes nothing.
#   F.   --help AND AN UNKNOWN FLAG TOUCH NOTHING (requirement 4) -- neither reaches the build logic;
#        --help exits 0, an unrecognized argument exits rc=2, both leave the scratch tree byte-identical.
#        (Same control-arm shape as the separate, still-FREE row master-builder-argparse-loud-refuse,
#        whose entire scope this requirement subsumes -- see this gate's own LEDGER note on that overlap.)
#   G.   VALIDATES BEFORE IT WRITES (requirement 3) -- a forced post-write round-trip failure (monkeypatched
#        into the SAME process, since the real defect only ever reproduces once in a great while and this
#        reproduces it on demand) must leave a PRE-EXISTING committed rungs byte-identical and no stray
#        `.tmp-*` files behind. Before this row: the rungs was written directly, so this exact failure mode
#        left a corrupted rungs requiring `git checkout` to undo.
#
# ⛔ EVERY ARM RUNS ON A SCRATCH COPY, never the live rungs. Reads corpus/tests/snobol4 for its own
# fixtures not at all -- every fixture here is FULLY SYNTHETIC, built via the harness's own Entry/write_suite
# (never a second suite-grammar writer), because copying the real ~1700-entry rungs alongside a couple of
# fresh synthetic pairs trips the (correct, unrelated) collapse-refusal guard.
#
# Usage: bash ../harness/scripts/test_gate_rungs_suite_deferral_and_scope.sh [--informational]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
GATE_NAME="master-suite-deferral-and-scope"
GATE_STRICT=1
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

BUILDER="$ROOT/../harness/scripts/util_build_rungs_suite.py"
gate_require "$BUILDER" "the rungs builder"

FAILS=0
ASSERTIONS=0
good() { ASSERTIONS=$((ASSERTIONS + 1)); echo "  ✓ $*"; }
bad()  { ASSERTIONS=$((ASSERTIONS + 1)); echo "  ✗ $*"; FAILS=$((FAILS + 1)); }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# mkscratch <dir>: a fully synthetic scratch snobol4 tree -- two undeclared absorbable families
# (openfam_probe, openfam2_probe), one KEEP.md-declared keeper (keepfam_probe), one PENDING.md-deferred
# family (pendfam_probe). Built as BLOCK-kind entries via the harness's own Entry/write_suite.
# ⭐ ALSO a synthetic postoffice at <dir>/postoffice, so the PENDING.md's row resolves LIVE deterministically
# via S4E_POST -- never the real fleet queue at /home/resources/postoffice. A deferral only blocks absorption
# while its row is LIVE (requirement 1, row-state resolution mirrors test_gate_suite_conversion_complete.sh's
# own pending_row_state()); pointing at a REAL row would make this gate's verdict depend on that row's
# CURRENT fleet state, which drifts (exactly the row this task itself fixed, coexpr-stack-*, could land and
# flip this gate red for a reason having nothing to do with the builder).
mkscratch() {
    rm -rf "$1"; mkdir -p "$1/corpus/tests/snobol4" "$1/postoffice"
    python3 - "$1/corpus/tests/snobol4" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]
def mk(name, out):
    e = h.Entry("block", 1, name, ["OUTPUT = '%s'" % name, "END"], [name])
    h.write_suite([e], os.path.join(T, out + ".sno"), os.path.join(T, out + ".ref"))
mk("keep-x", "keepfam_probe")
mk("pend-x", "pendfam_probe")
mk("open-x", "openfam_probe")
mk("open2-x", "openfam2_probe")
PY
    printf 'Keepers declared in this directory.\n\n`keepfam_probe.sno` stays loose on purpose -- test fixture.\n' > "$1/corpus/tests/snobol4/KEEP.md"
    printf 'ROW: some-fake-row-for-this-gate\n\n## DEFERRED\n- pendfam_probe.sno\n' > "$1/corpus/tests/snobol4/PENDING.md"
    printf '1\tsome-fake-row-for-this-gate\tunassigned\tCLAIMED:seat_test\n' > "$1/postoffice/QUEUE.tsv"
}

echo "== A/B/C. KEEP.md and PENDING.md respected; an undeclared family absorbs normally =="
mkscratch "$W/abc"
out="$(S4E_HOME="$W/abc" S4E_POST="$W/abc/postoffice" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
csv="$W/abc/corpus/tests/snobol4/ALL.csv"
excl="$W/abc/corpus/tests/snobol4/ALL.excluded.txt"
if [ "$rc" -eq 0 ]; then good "exit 0"; else bad "expected rc=0, got rc=$rc: $out"; fi
if ! grep -q '^[0-9]*,[^,]*,keepfam_probe__' "$csv" 2>/dev/null; then good "keepfam_probe NOT in ALL.csv (never absorbed)"
else bad "⛔ keepfam_probe origin appears in ALL.csv -- the KEEP.md declaration was not honoured"; fi
if ! grep -q '^[0-9]*,[^,]*,pendfam_probe__' "$csv" 2>/dev/null; then good "pendfam_probe NOT in ALL.csv (never absorbed)"
else bad "⛔ pendfam_probe origin appears in ALL.csv -- the PENDING.md deferral was not honoured"; fi
if grep -Pq '^keepfam_probe\tKEEPER' "$excl" 2>/dev/null; then good "keepfam_probe recorded in ALL.excluded.txt as a KEEPER, with reason"
else bad "keepfam_probe missing (or unreasoned) in ALL.excluded.txt"; fi
if grep -Pq '^pendfam_probe\tDEFERRED' "$excl" 2>/dev/null; then good "pendfam_probe recorded in ALL.excluded.txt as DEFERRED, with reason"
else bad "pendfam_probe missing (or unreasoned) in ALL.excluded.txt"; fi
if [ -f "$W/abc/corpus/tests/snobol4/keepfam_probe.sno" ] && [ -f "$W/abc/corpus/tests/snobol4/pendfam_probe.sno" ]; then
    good "both declared files survive on disk, untouched"
else bad "⛔ a declared file was deleted despite never being absorbed"; fi
if grep -q '^[0-9]*,[^,]*,openfam_probe__' "$csv" 2>/dev/null && grep -q '^[0-9]*,[^,]*,openfam2_probe__' "$csv" 2>/dev/null; then
    good "both UNDECLARED families absorbed normally (the filter does not over-exclude)"
else bad "⛔ an undeclared family failed to absorb -- the KEEP/PENDING filter is too broad"; fi

echo "== D. --absorb-only <family> scopes ABSORPTION itself, not just deletion =="
mkscratch "$W/d"
out="$(S4E_HOME="$W/d" S4E_POST="$W/d/postoffice" python3 "$BUILDER" --lang snobol4 --absorb-only openfam_probe 2>&1)"; rc=$?
csv="$W/d/corpus/tests/snobol4/ALL.csv"
if [ "$rc" -eq 0 ]; then good "exit 0"; else bad "expected rc=0, got rc=$rc: $out"; fi
if grep -q '^[0-9]*,[^,]*,openfam_probe__' "$csv" 2>/dev/null; then good "openfam_probe (named) absorbed"
else bad "⛔ openfam_probe was named by --absorb-only but not absorbed"; fi
if ! grep -q '^[0-9]*,[^,]*,openfam2_probe__' "$csv" 2>/dev/null; then good "openfam2_probe (NOT named) stayed loose, not absorbed"
else bad "⛔ openfam2_probe was absorbed despite not being named -- this is the exact bug measured on tests/icon (asked for X, got X and Y)"; fi
if [ -f "$W/d/corpus/tests/snobol4/openfam2_probe.sno" ]; then good "openfam2_probe.sno still on disk (untouched)"
else bad "⛔ openfam2_probe.sno is gone despite never being absorbed"; fi

echo "== E. --absorb-only naming an unabsorbable family (KEEP-declared) REFUSES rc=2, writes nothing =="
mkscratch "$W/e"
before="$(find "$W/e/corpus/tests/snobol4" -type f | sort | xargs md5sum 2>/dev/null | md5sum)"
out="$(S4E_HOME="$W/e" S4E_POST="$W/e/postoffice" python3 "$BUILDER" --lang snobol4 --absorb-only keepfam_probe 2>&1)"; rc=$?
after="$(find "$W/e/corpus/tests/snobol4" -type f | sort | xargs md5sum 2>/dev/null | md5sum)"
if [ "$rc" -eq 2 ]; then good "refused rc=2"; else bad "expected rc=2, got rc=$rc: $out"; fi
if printf '%s' "$out" | grep -q 'KEEPER'; then good "refusal names the KEEPER reason (not a generic no-op)"
else bad "refusal did not explain WHY the named family cannot be absorbed"; fi
if [ "$before" = "$after" ]; then good "scratch tree byte-identical before/after the refusal (nothing written)"
else bad "⛔ tree changed despite the rc=2 refusal"; fi

echo "== F. --help and an unknown flag reach the build logic NEVER, and touch NOTHING =="
mkscratch "$W/f"
S4E_HOME="$W/f" S4E_POST="$W/f/postoffice" python3 "$BUILDER" --lang snobol4 >/dev/null 2>&1   # seed a real rungs first
snap_f() { md5sum "$W"/f/corpus/tests/snobol4/ALL.* 2>/dev/null | sort; }
before="$(snap_f)"
S4E_HOME="$W/f" S4E_POST="$W/f/postoffice" python3 "$BUILDER" --help >/dev/null 2>"$W/f.help.err"; rc_help=$?
S4E_HOME="$W/f" S4E_POST="$W/f/postoffice" python3 "$BUILDER" --lang snobol4 --this-flag-does-not-exist >/dev/null 2>"$W/f.bogus.err"; rc_bogus=$?
after="$(snap_f)"
if [ "$rc_help" -eq 0 ]; then good "--help exits 0"; else bad "--help expected rc=0, got rc=$rc_help"; fi
if [ "$rc_bogus" -ge 2 ]; then good "unknown flag refuses rc=$rc_bogus (>=2)"; else bad "unknown flag expected rc>=2, got rc=$rc_bogus"; fi
if [ "$before" = "$after" ]; then good "ALL.* byte-identical across both invocations (neither touched the rungs)"
else bad "⛔ --help or an unknown flag mutated ALL.* -- the exact defect this requirement exists to cure"; fi
if ! find "$W/f/corpus/tests/snobol4" -name '*.tmp-*' | grep -q .; then good "no stray .tmp-* files left behind"
else bad "⛔ stray temp file(s) left on disk"; fi

echo "== G. VALIDATES BEFORE IT WRITES: a forced post-write round-trip failure corrupts nothing real =="
rm -rf "$W/g"; mkdir -p "$W/g/corpus/tests/snobol4"
python3 - "$W/g/corpus/tests/snobol4" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]
e = h.Entry("block", 1, "base-x", ["OUTPUT = 'base-x'", "END"], ["base-x"])
h.write_suite([e], os.path.join(T, "basefam_probe.sno"), os.path.join(T, "basefam_probe.ref"))
PY
S4E_HOME="$W/g" python3 "$BUILDER" --lang snobol4 --delete-absorbed >/dev/null 2>&1   # a "committed" base rungs, source deleted
snap_g() { md5sum "$W"/g/corpus/tests/snobol4/ALL.* 2>/dev/null | sort; }
before="$(snap_g)"
python3 - "$W/g/corpus/tests/snobol4" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]
e = h.Entry("block", 1, "new-x", ["OUTPUT = 'new-x'", "END"], ["new-x"])
h.write_suite([e], os.path.join(T, "newfam_probe.sno"), os.path.join(T, "newfam_probe.ref"))
PY
test_out="$(S4E_HOME="$W/g" python3 - <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
_orig = h.read_suite
def _boom(sno_path, *a, **kw):
    result = _orig(sno_path, *a, **kw)
    if ".tmp-" in str(sno_path):
        return result[:-1]   # simulate a lossy round trip, ONLY on the scratch temp copy
    return result
h.read_suite = _boom
import util_build_rungs_suite as m
sys.argv = ["util_build_rungs_suite.py", "--lang", "snobol4"]
try:
    m.main()
    print("TEST FAIL: build completed without raising despite the forced round-trip mismatch")
    sys.exit(1)
except (SystemExit, ValueError) as e:
    print("TEST PASS: build raised %s as expected: %s" % (type(e).__name__, e))
    sys.exit(0)
PY
)"; test_rc=$?
after="$(snap_g)"
if [ "$test_rc" -eq 0 ]; then good "forced validation failure raised as expected (see: $test_out)"
else bad "forced validation failure did not raise -- validate-before-write is not wired: $test_out"; fi
if [ "$before" = "$after" ]; then good "PRE-EXISTING rungs byte-identical after the forced failure (nothing real touched)"
else bad "⛔ the committed rungs changed despite the forced post-write validation failure"; fi
if ! find "$W/g/corpus/tests/snobol4" -name '*.tmp-*' | grep -q .; then good "no stray .tmp-* files left behind"
else bad "⛔ stray temp file(s) left on disk after the forced failure"; fi

echo "== H. ALL.excluded.txt IS GENERATED: a hand edit REFUSES rc=2 instead of being silently absorbed (CEO-545) =="
# ⛔ THE TWO ARMS ARE THE TWO MEASURED DEFECTS, and they used to fail in OPPOSITE directions on the same file
# (hq_V 2026-09-10, scratch-tree measurement): a hand DELETION of a line the builder still computes was
# SILENTLY REVERTED by the next full build, and a hand-ADDED line the builder never computes SURVIVED FOREVER
# unchallenged. The second is the worse half -- it is how a WRONG exclusion becomes permanent, and an excluded
# name cannot be red, so nobody looks. Both must now refuse. The third arm is the one that keeps this honest:
# an UNTOUCHED file must rebuild clean, or the guard is a gate that fires on its own correct output.
mkscratch "$W/h"
EXCL="$W/h/corpus/tests/snobol4/ALL.excluded.txt"
S4E_HOME="$W/h" S4E_POST="$W/h/postoffice" python3 "$BUILDER" --lang snobol4 >/dev/null 2>&1
if grep -q '^# builder-digest:' "$EXCL" 2>/dev/null; then good "a legacy file with no digest MIGRATES (stamped, not refused)"
else bad "⛔ no builder-digest stamped -- the guard cannot arm itself"; fi
S4E_HOME="$W/h" S4E_POST="$W/h/postoffice" python3 "$BUILDER" --lang snobol4 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then good "an UNTOUCHED generated file rebuilds clean (no false positive)"
else bad "⛔ rc=$rc on an untouched file -- the guard fires on its own output"; fi
keep_line="$(grep -m1 -P '^keepfam_probe\t' "$EXCL")"
grep -vP '^keepfam_probe\t' "$EXCL" > "$EXCL.x" && mv "$EXCL.x" "$EXCL"
out="$(S4E_HOME="$W/h" S4E_POST="$W/h/postoffice" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then good "a hand DELETION of a computed line REFUSES rc=2 (was: silently reverted)"
else bad "⛔ rc=$rc, expected 2 -- a hand deletion is still absorbed silently: $out"; fi
if [ -z "$(grep -P '^keepfam_probe\t' "$EXCL")" ]; then good "the refused run wrote NOTHING back (the edit is not quietly undone)"
else bad "⛔ the builder restored the deleted line despite refusing"; fi
printf '%s\n' "$keep_line" >> "$EXCL"
grep -v '^# builder-digest:' "$EXCL" > "$EXCL.x" && mv "$EXCL.x" "$EXCL"
S4E_HOME="$W/h" S4E_POST="$W/h/postoffice" python3 "$BUILDER" --lang snobol4 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then good "dropping the digest line ADOPTS the current file as the baseline (the documented escape hatch)"
else bad "⛔ rc=$rc -- the escape hatch named in the refusal message does not work"; fi
printf 'zzz_invented_family\tI WAS ADDED BY HAND AND NOTHING JUSTIFIES ME\n' >> "$EXCL"
out="$(S4E_HOME="$W/h" S4E_POST="$W/h/postoffice" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then good "an INVENTED line REFUSES rc=2 (was: survived every rebuild, unchallenged)"
else bad "⛔ rc=$rc, expected 2 -- an invented exclusion still survives: $out"; fi

GATE_EXAMINED=$ASSERTIONS
gate_verdict "$FAILS" "failed assertion(s)"
