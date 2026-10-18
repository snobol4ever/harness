#!/usr/bin/env bash
# test_gate_rungs_shrink_refusal.sh — the executable DONE-WHEN for row
# `snobol4-master-guard-sync-and-builder-shrink-refusal` (hq_C, 2026-08-30).
#
# WHAT IT PROVES, and why each arm exists:
#   A. NEGATIVE — a would-collapse rebuild REFUSES rc=2 and writes NOTHING. This is the arm that matters:
#      hq_P and seat14 each reproduced `rm ALL.* && rebuild` turning a 1576-entry cut-over rungs into TWO
#      entries, with the build reporting SUCCESS. The guard must stop `0 < pairs << base`.
#   B. POSITIVE — the guard can say YES. A criterion nobody has watched go green is not a criterion
#      (RULES.md § TWO-PART PROOF): if this arm is missing, a builder that refused unconditionally would
#      pass arm A forever and nobody would notice until a real rebuild was needed.
#   C. ORDERING — zero pairs over a healthy rungs is the SUCCESS state of consolidation, not a collapse,
#      and must exit 0 with the rungs intact. With the collapse test placed first, `0 * 4 < 97` refused
#      raku and prolog and told them not to delete ALL.* — correct advice for a disaster, addressed to a
#      success. This arm pins the order.
#   D. PROCEDURE — the cut-over scratch-verify procedure is documented in the builder's own header, not
#      only in law prose. A procedure that lives only in a task file is not reachable from the tool.
#
# ⛔ EVERY ARM RUNS ON A SCRATCH COPY. This gate must never be able to damage the live rungs — which is
# the very failure it exists to prevent. It reads `corpus/tests/snobol4` and writes only under mktemp.
#
# Usage: bash ../harness/scripts/test_gate_rungs_shrink_refusal.sh [--informational]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
GATE_NAME="rungs-shrink-refusal"
GATE_STRICT=1
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

BUILDER="$ROOT/../harness/scripts/util_build_rungs_suite.py"
LIVE="$ROOT/../corpus/tests/snobol4"
gate_require "$BUILDER" "the rungs builder"
gate_require "$LIVE/ALL.sno" "the live snobol4 rungs"
gate_require "$LIVE/ALL.csv" "the live snobol4 attribute database"

FAILS=0
good() { echo "  ✓ $*"; }
bad()  { echo "  ✗ $*"; FAILS=$((FAILS + 1)); }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkscratch() {  # $1 = dest root; copies the live language tree under it
    rm -rf "$1"; mkdir -p "$1/corpus/tests/snobol4"
    cp -r "$LIVE/." "$1/corpus/tests/snobol4/" 2>/dev/null
}

echo "== A. NEGATIVE: a rebuild that would LOSE a known origin must REFUSE rc=2 and name it"
# ⛔⭐ THIS ARM WAS REWRITTEN 2026-08-30 BECAUSE IT HAD GONE VACUOUSLY GREEN, AND THE REASON IS THE LESSON.
# The original arm copied the LIVE tree and expected the builder's `len(pairs)*4 < len(base)` ratio guard to
# fire. It did, the day it was written. Then the ratio guard was CORRECTLY RETIRED (SCRIP 85e120b8, 89646b4c)
# for reasons measured by others: a count cannot detect a SUBSTITUTION, the ratio false-refused icon's
# ordinary merge (1 new pair over 534 entries), and it missed hq_P's partial cutover entirely because
# surviving sources keep the RATIO healthy while a disjoint subset has no source at all. The replacement is
# an ORIGIN-SET check -- every origin the rungs is known to hold must still be in the rungs about to be
# written -- which is strictly better.
# ⛔ SO THE ARM DID NOT CATCH A REGRESSION. IT ASSERTED A MECHANISM THAT NO LONGER EXISTS, and when the
# mechanism was improved the arm stopped exercising anything and PASSED. seat13 caught it on an unmodified
# builder while regression-testing something unrelated.
# ⭐ THE FIX IS NOT A BETTER FIXTURE, IT IS A BETTER SUBJECT: pin the PROPERTY (a rebuild must not silently
# lose entries), never the IMPLEMENTATION (this particular arithmetic). A gate written against a mechanism
# expires the moment the mechanism improves, and it expires SILENTLY -- green, not red.
mkscratch "$W/a"
python3 - "$W/a/corpus/tests/snobol4" <<'PYA'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]; p = os.path.join(T, "ALL.sno")
es = h.read_suite(p, os.path.join(T, "ALL.ref"),
                  in_path=h.sidecar_in_path(p), x_path=h.sidecar_xfail_path(p))
# ⛔ drop only entries with NO sidecar references: an entry carrying an xfail reason or stdin trips the
# sidecar guards FIRST (they refuse on a block naming no entry -- correctly), and the fixture would then
# test those guards instead of the origin check. Reaching a late guard means satisfying every earlier one.
drop = [e for e in es if not e.xfail and not e.stdin][:5]
names = {e.name for e in drop}
h.write_suite([e for e in es if e.name not in names], p, os.path.join(T, "ALL.ref"))
PYA
before="$(md5sum "$W/a/corpus/tests/snobol4/ALL.csv" | cut -d' ' -f1)"
out="$(S4E_HOME="$W/a" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
after="$(md5sum "$W/a/corpus/tests/snobol4/ALL.csv" | cut -d' ' -f1)"
if [ "$rc" -eq 2 ]; then good "refused rc=2 on a rebuild that would drop known origins"
else bad "expected rc=2 when known origins would be lost, got rc=$rc — the loss guard did not fire"; fi
if printf '%s' "$out" | grep -qE 'probe_|__'; then good "named the specific origins it would have lost"
else bad "refused without naming what it lost — a refusal nobody can act on"; fi
if [ "$before" = "$after" ]; then good "ALL.csv byte-identical after the refusal (nothing written)"
else bad "⛔ THE CSV CHANGED during a refusal — and the CSV is the only record that made the refusal possible"; fi

# ⛔ COUNT REAL ENTRIES, NOT A GREP PROXY. `grep -c ';END;*'` counts only format-A LINE entries; the
# two-line witness below absorbs as a BLOCK, so the proxy read 816 -> 816 and the arm reported "proceeded
# without doing the work" while the builder had correctly absorbed it (1726 -> 1727). A marker count is a
# proxy for the thing, and it silently answers a narrower question than the one asked.
count_entries() {  # $1 = language dir
    python3 - "$1" <<'PYC'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]; p = os.path.join(T, "ALL.sno")
try:
    es = h.read_suite(p, os.path.join(T, "ALL.ref"),
                      in_path=h.sidecar_in_path(p), x_path=h.sidecar_xfail_path(p))
    print(len(es))
except Exception:
    print(-1)
PYC
}
echo "== B. POSITIVE: a rebuild that loses nothing must PROCEED (the guard can say YES)"
# ⛔ THIS ARM WAS ALSO WRITTEN AGAINST THE RETIRED RATIO GUARD and failed the moment arm A was fixed: it
# SHRANK the scratch rungs to 3 entries to make `pairs*4 >= base` true. Under the origin-set guard that
# fixture is precisely the thing that must REFUSE -- it drops 1723 known origins. The old positive arm had
# become a second negative arm wearing the wrong label, which is worse than no positive arm at all: it
# would have reported "the guard cannot say YES" forever while the guard was working perfectly.
# ⭐ The property a positive arm must show is not "a small rungs accepts pairs" but "a rebuild that LOSES
# NOTHING proceeds". So: keep the rungs whole, add ONE genuinely new pair, expect it absorbed.
mkscratch "$W/b"
find "$W/b/corpus/tests/snobol4" -name '*.sno' ! -name 'ALL.sno' -delete 2>/dev/null
printf '\tOUTPUT = "brandnew"\nEND\n' > "$W/b/corpus/tests/snobol4/zz_gate_brandnew.sno"
printf 'brandnew\n'                     > "$W/b/corpus/tests/snobol4/zz_gate_brandnew.ref"
n_before="$(count_entries "$W/b/corpus/tests/snobol4")"
out="$(S4E_HOME="$W/b" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
n_after="$(count_entries "$W/b/corpus/tests/snobol4")"
if [ "$rc" -eq 0 ]; then good "proceeded rc=0 on a rebuild that loses nothing"
else bad "expected rc=0 when no origin is lost, got rc=$rc — the guard cannot say YES"; fi
if [ "$n_after" -gt "$n_before" ]; then good "absorbed the new pair (${n_before} -> ${n_after} entries)"
else bad "rc=0 but nothing was absorbed (${n_before} -> ${n_after}) — proceeding without doing the work"; fi

echo "== C. ORDERING: zero pairs over a healthy rungs is SUCCESS, not collapse"
mkscratch "$W/c"
# ⛔ RECURSIVE, and -maxdepth 1 is why the first version of this arm failed: a copy of the language tree
# carries .sno files under config/ too, so a depth-1 delete left ONE pair behind, the builder correctly took
# the COLLAPSE branch at pairs=1, and the arm reported an ORDER REGRESSION THAT DOES NOT EXIST. The fixture
# was wrong, not the builder. Reaching "zero absorbable pairs" means every .sno but the rungs, at any depth.
find "$W/c/corpus/tests/snobol4" -name '*.sno' ! -name 'ALL.sno' -delete 2>/dev/null
out="$(S4E_HOME="$W/c" python3 "$BUILDER" --lang snobol4 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'RUNGS CURRENT'; then good "zero pairs over a full rungs exits 0 as RUNGS CURRENT"
elif printf '%s' "$out" | grep -q 'COLLAPSE'; then bad "⛔ ORDER REGRESSION: zero pairs took the COLLAPSE branch — that refuses every language the moment its consolidation SUCCEEDS"
else bad "expected rc=0 RUNGS CURRENT, got rc=$rc"; fi

echo "== D. PROCEDURE: the cut-over rule is in the builder's own header"
if grep -q 'CUT-OVER LANGUAGES RE-VERIFY IN A SCRATCH TREE' "$BUILDER"; then good "scratch-verify procedure documented in the builder"
else bad "the cut-over procedure is not in the builder header — it lives only in law prose"; fi

gate_verdict "$FAILS" "failed assertion(s)"
