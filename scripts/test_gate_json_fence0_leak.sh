#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# JSON-FENCE0 GATE -- bare FENCE0 stack-release regression (FINDING-2026-08-23-seat04-json-fence0-static-release-cant-see-past-alternation-unbounded-stack-leak.md).
# Guards the unbounded C-stack leak cured at SCRIP a42571b7 (bare FENCE0 in blob scope restores rsp to
# the blob activation floor at commit -- killswitch SCRIP_FENCE0_DYNAMIC, default ON). Before the fix,
# json.sno's own jarray/jobject trailing FENCE billed 0 release bytes whenever preceded by an
# ALTERNATE/ARBNO (every bare-FENCE site in this grammar takes that branch) -- every element's backtrack
# state leaked, unreleased, for the rest of the top-level match, and citm_catalog.json's `performances`
# section exhausted the C stack (fast, deterministic SIGSEGV).
# WITNESSES: synth_perf223/224.json (corpus/tests/snobol4/probe_loose/json_fence0_leak/, gen_synth_perf.py) are a synthetic,
# citm_catalog-independent minimal pair -- 223 always passed, 224 crashed pre-fix (rc=139). Asserts the
# SHAPE (bounded stack for bounded input), not one pinned threshold: the exact crash boundary moved
# between two same-session rebuilds pre-fix (233/234 -> 223/224) as an unrelated allocation change
# shifted per-record stack cost, so both sides of a known-bad boundary are checked, not a single number.
# ORACLE NOTE: x64/bin/sbl's default stack (-s4m) overflows (ERROR 246) on BOTH witnesses -- an oracle
# limit, unrelated to this bug. Refs were minted with -s16m (headroom measured clean 16m-64m; 128m+
# fails allocation in this environment), matching existing -s16m precedent (FINDING-2026-08-21-s199/s200).
# json.sno prints a deterministic structural summary (input bytes / root kind / per-kind counts /
# maxdepth) with no timing line, so unlike demo_calculator_1/demo_roman this needs no output filter.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT="${RT:-$S4E/SCRIP/out}"
DEMO="${DEMO:-$S4E/corpus/demos/snobol4}"   # composed below as "$DEMO/json/json.sno" -- corpus/demos/ itself
                                             # resolves (so the fossil-path gate's bare-default check misses
                                             # this), but the language-segment nesting added since means the
                                             # COMPOSED path needs the /snobol4/ this default was missing
pass=0; fail=0
# ⛔ PROBE IS ASSEMBLED, NOT ONE FIXED TREE (row dead-suite-path-consumer-sweep): the old
# probe_loose/json_fence0_leak/ directory is gone. The two witnesses now live split across two
# different locations by extension -- .ref stayed flat under tests/snobol4/ (prefixed
# probe_loose_json_fence0_leak_), .json landed under tests/snobol4/config/ (same prefix) -- confirmed
# by find, not assumed from one directory. An explicit PROBE override is honoured as-is, unchanged.
if [ -z "${PROBE:-}" ]; then
    PROBE="$(mktemp -d)"
    trap 'rm -rf "$PROBE"' EXIT
    for f in "$S4E"/corpus/tests/snobol4/probe_loose_json_fence0_leak_*.ref \
             "$S4E"/corpus/tests/snobol4/config/probe_loose_json_fence0_leak_*.json; do
        [ -f "$f" ] || continue
        cp "$f" "$PROBE/$(basename "$f" | sed 's/^probe_loose_json_fence0_leak_//')"
    done
fi
chk() { if [ "$1" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $2"; fi; }

if [ ! -x "$SCRIP" ]; then
  echo "  FAIL: no scrip binary at $SCRIP -- build first (make pristine)"
  echo "JSON-FENCE0 GATE: PASS=0 FAIL=1"
  exit 1
fi

"$SCRIP" --compile "$DEMO/json/json.sno" -o /tmp/gate_json_fence0.s < /dev/null > /dev/null 2>&1
gcc -no-pie /tmp/gate_json_fence0.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o /tmp/gate_json_fence0.bin 2>/dev/null

for w in synth_perf223 synth_perf224; do
  if [ ! -f "$PROBE/$w.json" ] || [ ! -f "$PROBE/$w.ref" ]; then
    echo "  FAIL: missing witness or ref for $w"; fail=$((fail+1)); continue
  fi

  timeout -k 5 60 "$SCRIP" --run "$DEMO/json/json.sno" < "$PROBE/$w.json" > /tmp/gate_m3_$w.txt 2>/dev/null
  diff -q /tmp/gate_m3_$w.txt "$PROBE/$w.ref" > /dev/null 2>&1; chk $? "m3 $w matches oracle"

  timeout -k 5 60 /tmp/gate_json_fence0.bin < "$PROBE/$w.json" > /tmp/gate_m4_$w.txt 2>/dev/null
  diff -q /tmp/gate_m4_$w.txt "$PROBE/$w.ref" > /dev/null 2>&1; chk $? "m4 $w matches oracle"
done

echo "JSON-FENCE0 GATE: PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] || exit 1
