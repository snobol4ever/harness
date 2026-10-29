#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_scan_argtype.sh -- THE INVARIANT GATE for the Icon builtin argument-type class on the
# SCAN-NODE route: inside a scanning expression, `any many upto bal find match tab move` must RAISE the
# oracle's own error and abort on a wrong-type argument, and must CONVERT-AND-SUCCEED on a right-type-
# convertible one.  Row `icon-scan-node-builtins-do-not-refuse-wrong-argument-types` (hq_B 2026-09-04);
# cure and sizing in FINDING-2026-09-04-hq_B-icon-scan-node-builtins-now-refuse-wrong-argument-types-
# and-the-class-is-closed-on-both-routes.md.
#
# ⛔⭐ WHY THIS EXISTS BESIDE test_icon_ladder.sh, WHICH ALREADY RUNS THESE WITNESSES.  The ladder grades
# stdout against a CHECKED-IN .ref.  A .ref is a photograph of what SCRIP printed on the day someone cut
# it, so a ladder green proves only "unchanged since then" -- it cannot distinguish a cured builtin from
# a .ref that was cut while the builtin was broken.  This gate re-cuts every verdict from the LIVE ORACLE
# (icont/iconx v9.5.25a) on each run, so it answers the question the row was actually opened about.  It
# is also NAMED BY BUILTIN: a regression prints `any m4 code=none want=104` instead of moving a 420-row
# ladder total by two, which is the difference between a diagnosis and a search.
#
# ⛔ IT COMPARES THE ERROR CODE, THE rc AND stdout -- NEVER THE WHOLE DIAGNOSTIC.  icont prints `File/Line`,
# `offending value:` and a `Traceback:` that SCRIP does not; that verbosity gap is a real but SEPARATE and
# much wider class, and folding it in here would make this gate red for a reason it does not own and
# cannot cure.  Measured while writing this gate: a naive full-stderr diff calls all 8 refusals DIFF while
# every one of them raises the correct code with the correct rc.  An instrument wider than its question
# is as wrong as one narrower than it -- the same defect the digest records for `command -v`, pointing the
# other way.
#
# ⛔ AND IT REFUSES RATHER THAN PRINTING A ZERO.  Population comes from the corpus by ORIGIN column, never
# a filename glob and never a hardcoded list of 11 that silently stops covering witnesses added later.  A
# missing oracle, a missing rungs, or an EMPTY census exits 2: a census that cannot see its population
# must never report success over it (`find corpus/crosscheck -name '*.sno'` printing nothing and exiting 0
# is the house example).
#
# EXIT: 0 every witness agrees with the oracle in both modes · 1 any disagreement · 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
RT="$ROOT/out"
# ⭐ FAIL-ONCE HOOK (instrument law batch 1, ceo audit 2026-09-04): the ONLY override this gate honours. Point it at a
# deliberately wrong-coded stub and the gate must go RED (DIVERGENT>0, rc=1) -- proven and recorded in the FINDING.
SCRIP="${SCAN_ARGTYPE_SCRIP:-$ROOT/scrip}"
T="${TIMEOUT:-20}"
refuse() { echo "⛔ GATE REFUSE(2) [icn-scan-argtype]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
RUNGS_DIR="$S4E/corpus/tests/icon"; RUNGS_EXT=.icn
. "$HERE/lib_rungs_extract.sh" || refuse "cannot source lib_rungs_extract.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
ICONX="$(iconx_bin)" || refuse "no iconx oracle (lib_oracle_flags iconx_bin)"
[ -x "$SCRIP" ] || refuse "$SCRIP is not built -- run make"
[ -f "$RT/libscrip_rt.so" ] || refuse "$RT/libscrip_rt.so missing -- run make"
[ -f "$RUNGS_DIR/ALL.csv" ] || refuse "$RUNGS_DIR/ALL.csv missing -- cannot census the population"
# THE POPULATION, by origin: every scan-route argtype witness the rungs carries, refusals and coercions
# alike.  Both halves are graded by ONE census on purpose -- the cure that makes `tab([1,2])` raise is the
# same helper that makes `tab("2")` convert, so a gate holding only the refusals would go green on a
# regression that re-broke the coercions, which is precisely how this class was half-cured the first time.
ORIGINS="$(awk -F, 'NR>1 && $3 ~ /^ladder__rung[0-9]+_.*_scan_(refuse|coerce)/ {print $3}' "$RUNGS_DIR/ALL.csv")"
N="$(printf '%s' "$ORIGINS" | grep -c . || true)"
[ "$N" -gt 0 ] || refuse "census over $RUNGS_DIR/ALL.csv found ZERO scan-argtype witnesses -- the population is unreachable, not empty"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
code_of() { grep -oE '(Run-time error|scrip: error) [0-9]+' | grep -oE '[0-9]+' | head -1; }   # the ONE field this gate compares out of stderr
echo "=== Icon scan-node builtin argument-type gate (oracle-cut, both modes) ==="
echo "oracle: $ICONT / $ICONX"
echo "population: $N witnesses by origin from $RUNGS_DIR/ALL.csv"
printf '%-46s | %-8s %-3s | %-8s %-3s | %-8s %-3s | %s\n' witness orac rc m3 rc m4 rc verdict
fail=0; graded=0
for org in $ORIGINS; do
    src="$W/w.icn"
    rungs_extract_origin "$org" "$src" >/dev/null 2>&1 || { echo "REFUSE: cannot extract $org"; exit 2; }
    # THE ORACLE CUTS THE ANSWER EVERY RUN -- never a stored .ref.  Compile failure here is a refusal, not
    # a fail: an oracle that will not build the witness has not graded it.
    ( cd "$W" && timeout -k 5 "$T" "$ICONT" -s -o w.x w.icn >/dev/null 2>&1 ) && [ -s "$W/w.x" ] \
        || refuse "oracle icont could not build witness $org -- cannot grade it"
    o_out="$( cd "$W" && timeout -k 5 "$T" "$ICONX" ./w.x 2>/dev/null </dev/null )"; o_rc=$?
    o_code="$( cd "$W" && timeout -k 5 "$T" "$ICONX" ./w.x 2>&1 >/dev/null </dev/null | code_of )"
    m3_out="$( cd "$W" && timeout -k 5 "$T" "$SCRIP" w.icn 2>/dev/null </dev/null )"; m3_rc=$?
    m3_code="$( cd "$W" && timeout -k 5 "$T" "$SCRIP" w.icn 2>&1 >/dev/null </dev/null | code_of )"
    if ( cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --out=w.s w.icn </dev/null >/dev/null 2>&1 ) && [ -s "$W/w.s" ] \
       && as --64 -o "$W/w.o" "$W/w.s" 2>/dev/null \
       && gcc -no-pie -o "$W/w.bin" "$W/w.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; then
        m4_out="$( cd "$W" && timeout -k 5 "$T" ./w.bin 2>/dev/null </dev/null )"; m4_rc=$?
        m4_code="$( cd "$W" && timeout -k 5 "$T" ./w.bin 2>&1 >/dev/null </dev/null | code_of )"
    else
        m4_out="<BUILD-FAILED>"; m4_rc=-1; m4_code="<BUILD-FAILED>"
    fi
    v=OK
    [ "$o_code" = "$m3_code" ] && [ "$o_code" = "$m4_code" ] || v="CODE-DIFF"
    [ "$o_rc" = "$m3_rc" ] && [ "$o_rc" = "$m4_rc" ] || v="$v RC-DIFF"
    [ "$o_out" = "$m3_out" ] && [ "$o_out" = "$m4_out" ] || v="$v OUT-DIFF"
    graded=$((graded + 2))
    [ "$v" = OK ] || fail=$((fail + 1))
    printf '%-46s | %-8s %-3s | %-8s %-3s | %-8s %-3s | %s\n' \
        "${org#ladder__}" "${o_code:-none}" "$o_rc" "${m3_code:-none}" "$m3_rc" "${m4_code:-none}" "$m4_rc" "$v"
done
echo "SCAN-ARGTYPE: witnesses=$N modes=2 graded=$graded DIVERGENT=$fail  tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo ?) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo ?)"
if [ "$fail" -ne 0 ]; then
    echo "⛔ GATE FAIL(1) [icn-scan-argtype]: $fail of $N witnesses diverge from the oracle"
    exit 1
fi
echo "✅ GATE PASS(0) [icn-scan-argtype]: $N/$N witnesses agree with the oracle in both modes"
exit 0
