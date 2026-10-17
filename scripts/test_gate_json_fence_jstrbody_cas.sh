#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# JSON-FENCE-JSTRBODY-CAS GATE -- row fence-jstrbody-cas item 1 (FENCE after jkey/jstring's closing quote,
# corpus/demos/snobol4/json/{json.sno,json-match-fence.sno}), graded on its own real DONE-WHEN target:
# the full 1.7MB corpus/demos/snobol4/json/citm_catalog.json, both files, both modes, byte-identical to the
# correctness oracle (sbl_correctness_bin, -bf per lib_oracle_flags.sh -- the s189 authority, never -b alone).
# Refs minted this session from a clean oracle run (rc=0, ~0.2s wall, match_ms=240 -- FENCE keeps this cheap;
# maxdepth=8 matches hq_P's independent citm measurement in FINDING-2026-08-23-hq_P-fence0-blob-floor-...).
# Item 2 (relocating jobject/jarray's FENCE from definition-site to use-site) is NOT exercised here and never
# will be by this gate: seat04 (FINDING-2026-08-22-seat04-json-alternate-af-spin-root-cause-flat-choice-record-
# rsp-drift.md §7b) proved it trades the af-spin hang for a SIGSEGV on recursive boxes via blob_choice_rbp_scan
# eligibility -- a receipted refusal, not an oversight; see FINDING-2026-08-29-seat10-fence-jstrbody-cas-citm-
# measured-item2-stays-refused.md.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT="${RT:-$S4E/SCRIP/out}"
DEMO="${DEMO:-$S4E/corpus/demos/snobol4/json}"
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): corpus/probe/ was
# deleted wholesale (corpus-crosscheck-probe-total-conversion); these two .ref files are part of the
# un-absorbable residue and now live as flat probe_loose_-prefixed files directly under tests/snobol4/.
PROBE="${PROBE:-$S4E/corpus/tests/snobol4}"
JFJC_JSON_REF="probe_loose_json_fence_jstrbody_cas_citm_catalog_json.ref"
JFJC_MF_REF="probe_loose_json_fence_jstrbody_cas_citm_catalog_match_fence.ref"
# ⛔ EACH WORKLOAD RUNS AT THE STACK AND HEAP IT DECLARES (clause 8 (f); the coo 2026-10-01, the ceo's yes to the instrument row): the
# unit is a program ON AN INPUT, so its .heap/.stack sidecars sit beside its ref under the ref's stem and are read by the one reader,
# declared_switches_beside. MEASURED at SCRIP 4cfd7e0f4, two readings each: json-match-fence.sno on citm_catalog.json overflows (ERROR
# 246) at -s8192k, -s16384k and -s32768k and matches the ref at -s65536k; sbl -bf overflows at its default and matches from -s16384k.
# The gate ran every arm at the runtime's defaults until this, so the two match-fence arms read FAIL on a stack, not on FENCE.
# json.sno on the same input matches at the defaults and declares nothing.
. "$(dirname "${BASH_SOURCE[0]}")/lib_declared_arena.sh" || { echo "  REFUSED TO GRADE: lib_declared_arena.sh unloadable"; exit 2; }
JSON_SW="$(declared_switches_beside "$PROBE/${JFJC_JSON_REF%.ref}.sno")" || { echo "  REFUSED TO GRADE: a sidecar of ${JFJC_JSON_REF%.ref} is refused (the reader said why above)"; exit 2; }
MF_SW="$(declared_switches_beside "$PROBE/${JFJC_MF_REF%.ref}.sno")" || { echo "  REFUSED TO GRADE: a sidecar of ${JFJC_MF_REF%.ref} is refused (the reader said why above)"; exit 2; }
pass=0; fail=0
chk() { if [ "$1" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $2"; fi; }

if [ ! -x "$SCRIP" ]; then
  echo "  REFUSED TO GRADE: no scrip binary at $SCRIP -- build first (make pristine)"
  echo "JSON-FENCE-JSTRBODY-CAS GATE: PASS=0 FAIL=0 REFUSED"
  exit 2
fi
if [ ! -f "$DEMO/citm_catalog.json" ] || [ ! -f "$PROBE/$JFJC_JSON_REF" ] || [ ! -f "$PROBE/$JFJC_MF_REF" ]; then
  echo "  REFUSED TO GRADE: missing input or ref under $DEMO / $PROBE"
  echo "JSON-FENCE-JSTRBODY-CAS GATE: PASS=0 FAIL=0 REFUSED"
  exit 2
fi

T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
"$SCRIP" --compile "$DEMO/json.sno" -o "$T/json.s" < /dev/null > /dev/null 2>&1
gcc -no-pie "$T/json.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "$T/json.bin" 2>/dev/null
"$SCRIP" --compile "$DEMO/json-match-fence.sno" -o "$T/jmf.s" < /dev/null > /dev/null 2>&1
gcc -no-pie "$T/jmf.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "$T/jmf.bin" 2>/dev/null

timeout -k 5 60 "$SCRIP" $JSON_SW --run "$DEMO/json.sno" < "$DEMO/citm_catalog.json" > "$T/m3_json.txt" 2>/dev/null
diff -q "$T/m3_json.txt" "$PROBE/$JFJC_JSON_REF" > /dev/null 2>&1; chk $? "m3 json.sno matches oracle on citm_catalog.json"

timeout -k 5 60 "$T/json.bin" $JSON_SW < "$DEMO/citm_catalog.json" > "$T/m4_json.txt" 2>/dev/null
diff -q "$T/m4_json.txt" "$PROBE/$JFJC_JSON_REF" > /dev/null 2>&1; chk $? "m4 json.sno matches oracle on citm_catalog.json"

timeout -k 5 60 "$SCRIP" $MF_SW --run "$DEMO/json-match-fence.sno" < "$DEMO/citm_catalog.json" > "$T/m3_jmf.txt" 2>/dev/null
diff -q "$T/m3_jmf.txt" "$PROBE/$JFJC_MF_REF" > /dev/null 2>&1; chk $? "m3 json-match-fence.sno matches oracle on citm_catalog.json (at ${MF_SW:-the defaults})"

timeout -k 5 60 "$T/jmf.bin" $MF_SW < "$DEMO/citm_catalog.json" > "$T/m4_jmf.txt" 2>/dev/null
diff -q "$T/m4_jmf.txt" "$PROBE/$JFJC_MF_REF" > /dev/null 2>&1; chk $? "m4 json-match-fence.sno matches oracle on citm_catalog.json (at ${MF_SW:-the defaults})"

# ⭐ REGRESSION LOCK, NOT JUST A CORRECTNESS CHECK: jstrbody's FENCE must still be textually present at both
# sites -- a future edit that silently drops it would still pass the byte-identical checks above (small/no
# backtrack either way on this input's happy path) while reintroducing the CAS-retention this row cured.
grep -qE "jkey[[:space:]]*=.*dq FENCE \(epsilon \. \*ekey\(\)\)" "$DEMO/json.sno"; chk $? "json.sno jkey still carries the trailing FENCE"
grep -qE "jstring[[:space:]]*=.*dq FENCE \(epsilon \. \*estr\(\)\)" "$DEMO/json.sno"; chk $? "json.sno jstring still carries the trailing FENCE"
grep -qE "jstring[[:space:]]*=.*ARBNO\(jescape jchunk\) '\"' FENCE" "$DEMO/json-match-fence.sno"; chk $? "json-match-fence.sno jstring still carries the trailing FENCE"

echo "JSON-FENCE-JSTRBODY-CAS GATE: PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] || exit 1
