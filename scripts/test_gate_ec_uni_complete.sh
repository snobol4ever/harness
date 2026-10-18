#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_ec_uni_complete.sh — EC-UNI-21 formal close gate for EC-UNI-14.
#
# Runs the five gates from GOAL-HEADQUARTERS.md "EC-UNI gate" block, plus
# baseline md5 reconciliation against the watermark, plus the M1 oracle md5
# check.  Reports each cell honestly; exits 0 iff all five gates PASS and
# the baseline md5 matches.  M1 oracle drift is REPORTED, not enforced —
# the watermark notes M1 has drifted at abfd19a7..., and re-convergence is
# its own task (either flip beauty back to oracle parity, or formally retire
# M1 — see EC-UNI-21 follow-up in GOAL-HEADQUARTERS.md).
#
# Gate definitions (from GOAL-HEADQUARTERS.md):
#   GATE-1  beauty.sno --compile  →  md5 6bf2e9daa777f54f04c8f7160da435d1  (882524 bytes)  [PPV-2: SM_PAT_* substitution removes SM_PUSH_VAR+SM_PAT_DEREF for protected names]
#   GATE-2  bash ../harness/scripts/test_smoke_icon.sh                                # PASS=5
#   GATE-3  bash ../harness/scripts/test_smoke_unified_broker.sh                      # PASS≥23
#   GATE-4  bash ../harness/scripts/test_icon_all_rungs.sh                            # PASS=194/36/35
#   GATE-5  bash ../harness/scripts/test_smoke_{snobol4,snocone,prolog,rebus,raku}.sh # 7/0 5/0 5/0 4/0 5/0
#
# Reconciliation:
#   BASELINE md5 (binding) :  6bf2e9daa777f54f04c8f7160da435d1  (beauty --compile)  [PPV-2]
#   M1 ORACLE  md5 (drifted):  abfd19a7a834484a96e824851caee159  (SPITBOL oracle baseline)
#
# Self-contained per RULES.md.  Paths derive from $0; corpus/oracle paths
# hardcoded with SKIP fallback.  Each scrip call gets `< /dev/null` and
# `timeout`.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
ORACLE="${ORACLE:-$S4A/x64/bin/sbl}"
TIMEOUT_SHORT="${TIMEOUT_SHORT:-8}"
TIMEOUT_LONG="${TIMEOUT_LONG:-180}"

BASELINE_MD5="6bf2e9daa777f54f04c8f7160da435d1"
BASELINE_BYTES="882524"
M1_ORACLE_MD5="abfd19a7a834484a96e824851caee159"

BEAUTY_SNO="$CORPUS/beauty/beauty.sno"

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip not built at $SCRIP"
    exit 0
fi
if [ ! -f "$BEAUTY_SNO" ]; then
    echo "SKIP beauty.sno not found at $BEAUTY_SNO"
    exit 0
fi

PASS_TOTAL=0
FAIL_TOTAL=0
FAILS=""

note_pass() { PASS_TOTAL=$((PASS_TOTAL+1)); echo "  PASS $1"; }
note_fail() { FAIL_TOTAL=$((FAIL_TOTAL+1)); FAILS="$FAILS $1"; echo "  FAIL $1: $2"; }

echo "=== EC-UNI-21 close gate ==="
echo ""

# ---- GATE-1: beauty.sno --compile byte-identity baseline ----
echo "--- GATE-1: beauty.sno --compile baseline md5 ---"
TMP_ASM="$(mktemp /tmp/ec_uni_beauty_XXXX.s)"
trap 'rm -f "$TMP_ASM"' EXIT
timeout -k 5 "$TIMEOUT_LONG" "$SCRIP" --compile "$BEAUTY_SNO" > "$TMP_ASM" 2>/dev/null < /dev/null
rc=$?
got_bytes=$(wc -c < "$TMP_ASM")
got_md5=$(md5sum "$TMP_ASM" | cut -d' ' -f1)
echo "  scrip rc=$rc  bytes=$got_bytes  md5=$got_md5"
echo "  expect      bytes=$BASELINE_BYTES  md5=$BASELINE_MD5"
if [ "$rc" -eq 0 ] && [ "$got_md5" = "$BASELINE_MD5" ] && [ "$got_bytes" = "$BASELINE_BYTES" ]; then
    note_pass "gate1_beauty_baseline_md5"
else
    note_fail "gate1_beauty_baseline_md5" "rc=$rc bytes=$got_bytes md5=$got_md5"
fi
echo ""

# ---- GATE-2: smoke icon ----
echo "--- GATE-2: smoke icon (PASS=5 FAIL=0) ---"
out=$(bash "$HERE/test_smoke_icon.sh" 2>&1 | tail -1)
echo "  $out"
if echo "$out" | grep -qE "^PASS=5 FAIL=0$"; then
    note_pass "gate2_smoke_icon"
else
    note_fail "gate2_smoke_icon" "$out"
fi
echo ""

# ---- GATE-3: smoke unified_broker (PASS>=23) ----
echo "--- GATE-3: smoke unified_broker (PASS>=23) ---"
out=$(bash "$HERE/test_smoke_unified_broker.sh" 2>&1 | tail -1)
echo "  $out"
broker_pass=$(echo "$out" | grep -oE "PASS=[0-9]+" | head -1 | cut -d= -f2)
if [ -n "$broker_pass" ] && [ "$broker_pass" -ge 23 ]; then
    note_pass "gate3_smoke_broker"
else
    note_fail "gate3_smoke_broker" "$out"
fi
echo ""

# ---- GATE-4: icon all rungs (PASS=194 FAIL=36 XFAIL=35) ----
echo "--- GATE-4: icon all rungs (PASS=194 FAIL=36 XFAIL=35 TOTAL=265) ---"
out=$(timeout -k 5 "$TIMEOUT_LONG" bash "$HERE/test_icon_all_rungs.sh" 2>&1 | tail -1)
echo "  $out"
if echo "$out" | grep -qE "PASS=194 FAIL=36 XFAIL=35 TOTAL=265"; then
    note_pass "gate4_icon_all_rungs"
else
    note_fail "gate4_icon_all_rungs" "$out"
fi
echo ""

# ---- GATE-5: smoke {snobol4, snocone, prolog, rebus, raku} ----
echo "--- GATE-5: smoke snobol4/snocone/prolog/rebus/raku ---"
declare -A G5_EXPECT=(
    [snobol4]="PASS=7 FAIL=0"
    [snocone]="PASS=5 FAIL=0"
    [prolog]="PASS=5 FAIL=0"
    [rebus]="PASS=4 FAIL=0"
    [raku]="PASS=5 FAIL=0"
)
for lang in snobol4 snocone prolog rebus raku; do
    out=$(bash "$HERE/test_smoke_$lang.sh" 2>&1 | tail -1)
    echo "  $lang: $out"
    if [ "$out" = "${G5_EXPECT[$lang]}" ]; then
        note_pass "gate5_smoke_$lang"
    else
        note_fail "gate5_smoke_$lang" "got '$out' expected '${G5_EXPECT[$lang]}'"
    fi
done
echo ""

# ---- M1 oracle reconciliation (REPORT-ONLY, not a fail condition) ----
echo "--- M1 oracle md5 reconciliation (report-only) ---"
if [ -x "$ORACLE" ]; then
    TMP_ORACLE_OUT="$(mktemp /tmp/ec_uni_oracle_XXXX.out)"
    SETL4PATH=".:$CORPUS/include" timeout -k 5 "$TIMEOUT_LONG" \
        "$ORACLE" -bf "$BEAUTY_SNO" < "$BEAUTY_SNO" > "$TMP_ORACLE_OUT" 2>/dev/null
    rc=$?
    oracle_md5=$(md5sum "$TMP_ORACLE_OUT" | cut -d' ' -f1)
    oracle_lines=$(wc -l < "$TMP_ORACLE_OUT")
    echo "  SPITBOL oracle: rc=$rc lines=$oracle_lines md5=$oracle_md5"
    echo "  M1 baseline:                                   md5=$M1_ORACLE_MD5"
    if [ "$oracle_md5" = "$M1_ORACLE_MD5" ]; then
        echo "  M1 status: CONVERGED — beauty.sno output matches oracle baseline"
    else
        echo "  M1 status: DRIFTED — beauty.sno output differs from oracle baseline."
        echo "             Re-converge or formally retire M1 in GOAL-HEADQUARTERS.md."
    fi
    rm -f "$TMP_ORACLE_OUT"
else
    echo "  SKIP SPITBOL oracle not found at $ORACLE — M1 status: UNKNOWN"
fi
echo ""

# ---- Summary ----
echo "=== EC-UNI-21 close gate summary ==="
echo "PASS=$PASS_TOTAL FAIL=$FAIL_TOTAL"
if [ -n "$FAILS" ]; then
    echo "FAILS:$FAILS"
fi
[ "$FAIL_TOTAL" -eq 0 ]
