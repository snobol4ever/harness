#!/usr/bin/env bash
# test_snocone_crosscheck_suites.sh — grades every corpus/tests/snocone/crosscheck_*.{sc,ref} suite pair.
# D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; S4E_HOME overrides).
#
# These 30 pairs are the whole of the former corpus/crosscheck/snocone/ tree (181 entries), converted under
# corpus-crosscheck-probe-total-conversion (Lon 2026-08-28: crosscheck must go). 18 of the 181 are XFAIL
# witnesses for genuinely unlanded features; they bucket as <mode>_xfail, never as <mode>_fail, so this gate's
# FAIL count is unaffected by them — and an XPASS (a marker whose bug got fixed) is surfaced as loudly as a FAIL.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$S4E/corpus/tests/snocone"
H="$HERE/corpus_suite_harness.py"

[ -f "$H" ] || { echo "REFUSE (rc=2): corpus_suite_harness.py not found at $H -- cannot measure, not a pass"; exit 2; }
shopt -s nullglob
suites=("$D"/crosscheck_*.sc)
# ⛔⭐ ABSORBED FALLBACK (hq_B 2026-08-30, row graders-denominator-audit-six-families). The loose
# crosscheck_*.{sc,ref} suite pairs were consolidated into the one flat ALL.* set, so this gate's
# refusal below had become PERMANENT -- and unlike the icon twins, this one IS a real coverage hole:
# MEASURED, 181 of snocone's 273 ALL.csv entries carry a crosscheck origin across 30 families, and the
# only other grader over ALL.sc (test_snocone_corpus_suite.sh) grades TEN. So ~181 entries were graded
# by nothing at all while this gate said "cannot measure" and nobody re-examined it -- the ranked-cover
# law exactly: a refusal is neither audited like a green nor triaged like a red.
# ⛔ Keyed on the `origin` column, the durable provenance link that survives consolidation's renames,
# never on the entry name. Materialized per family into a temp dir named <family>.sc/.ref so the loop
# below -- and its fam label, its m3,m4 modes and its xfail accounting -- runs completely unchanged.
if [ "${#suites[@]}" -eq 0 ] && [ -f "$D/ALL.sc" ] && [ -f "$D/ALL.ref" ] && [ -f "$D/ALL.csv" ]; then
    _abs="$(mktemp -d)"; trap 'rm -rf "$_abs"' EXIT
    for _fam in $(python3 -c "import csv,sys; print(chr(10).join(sorted({r['family'] for r in csv.DictReader(open(sys.argv[1])) if 'crosscheck' in (r['origin'] or '')})))" "$D/ALL.csv"); do
        python3 "$H" extract-family "$D/ALL.sc" "$D/ALL.ref" "$D/ALL.csv" "$_fam" "$_abs/$_fam.sc" "$_abs/$_fam.ref" >/dev/null 2>&1 || true
    done
    suites=("$_abs"/*.sc)
    [ "${#suites[@]}" -gt 0 ] && echo "  [absorbed] materialized ${#suites[@]} crosscheck family/families out of the flat ALL.* set"
fi
[ "${#suites[@]}" -gt 0 ] || { echo "REFUSE (rc=2): no crosscheck_*.sc suites under $D and none recoverable from $D/ALL.* -- cannot measure, not a pass"; exit 2; }

echo "=== snocone crosscheck suites (${#suites[@]} families) ==="
TOT=0; PASS=0; XFAIL=0; BAD=0
for sc in "${suites[@]}"; do
    fam="$(basename "$sc" .sc)"; ref="${sc%.sc}.ref"
    [ -f "$ref" ] || { echo "  FAIL $fam: .sc present but .ref missing"; BAD=$((BAD+1)); continue; }
    board=$(python3 "$H" run "$sc" "$ref" --lang snocone --modes m3,m4 2>/dev/null | grep '^SUITE_BOARD')
    [ -n "$board" ] || { echo "  FAIL $fam: harness emitted no SUITE_BOARD (cannot measure)"; BAD=$((BAD+1)); continue; }
    TOT=$((TOT + $(grep -oP 'total=\K[0-9]+' <<<"$board")))
    for m in m3 m4; do
        PASS=$((PASS + $(grep -oP "${m}_pass=\K[0-9]+" <<<"$board")))
        for k in fail crash hang unproven xpass; do
            v=$(grep -oP "${m}_${k}=\K[0-9]+" <<<"$board")
            [ "$v" -eq 0 ] || { echo "  FAIL $fam: ${m}_${k}=${v}"; BAD=$((BAD+v)); }
        done
    done
    XFAIL=$((XFAIL + $(grep -oP 'm3_xfail=\K[0-9]+' <<<"$board")))
done
echo ""
echo "entries=$TOT  PASS=$PASS (both modes)  XFAIL=$XFAIL (per mode)  FAIL=$BAD"
[ "$BAD" -eq 0 ] && echo "GATE OK" || echo "GATE FAILED"
[ "$BAD" -eq 0 ]
