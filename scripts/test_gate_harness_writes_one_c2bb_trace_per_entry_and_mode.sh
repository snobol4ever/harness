#!/usr/bin/env bash
# test_gate_harness_writes_one_c2bb_trace_per_entry_and_mode.sh -- WITH S4E_ENTRY_TRACE_DIR SET, THE HARNESS GIVES EVERY ENTRY AND MODE
# ITS OWN SCRIP_C2BB_TRACE FILE, AND util_c2bb_trace_census.py COUNTS A DIRECTORY OF THEM BY MARK (the coo 2026-10-09, the cfo's ask for
# the rank-0 row gc-rt-c-c-to-bb-entries-leave-no-emitted-code-...; the reading it made is .github/findings/2026-10-09-coo-c2bb-trace-reading.md).
# MEASURED: rt_c2bb_hit appends to the ONE path SCRIP_C2BB_TRACE names, so a suite run under one path cannot say which entry entered a
# box from C -- the question the row asks of every mark.
# THE FIXTURE (mktemp, two SNOBOL4 programs, graded through corpus_suite_harness.run_all_modes itself, both modes):
#   apply_witness  APPLY(.SIZE,'abc') -- a builtin applied by name, the rungs' apply.open witness (apply_omitted_args_1)
#   plain_witness  OUTPUT = 'hi' -- enters nothing from C
#   ARM 1  both witnesses PASS in both modes (the hook changes no verdict)
#   ARM 2  apply_witness leaves apply_witness.m3.trace and .m4.trace, each naming apply.open; plain_witness leaves no file
#   ARM 3  the hook leaves no SCRIP_C2BB_TRACE behind in the harness's environment
#   ARM 4  FAIL-ONCE: without S4E_ENTRY_TRACE_DIR no trace file is written anywhere in the fixture
#   ARM 5  the census counts apply.open on 1 entry, m3 1 and m4 1, witness apply_witness; on an empty directory it REFUSES rc=2
# EXIT: 0 all arms pass · 1 an arm failed · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
G=harness_writes_one_c2bb_trace_per_entry_and_mode
[ -x "$ROOT/scrip" ] || { echo "GATE UNPROVEN(2) [$G]: no $ROOT/scrip (make first)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "test_gate_$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
drive() {  # $1 = trace dir or "" -> one line per witness: name m3-kind m4-kind leftover-env
    ( cd "$W" && S4E_PROGRESS_OFF=1 S4E_ENTRY_TRACE_DIR="$1" python3 - "$HERE" "$W" <<'PY'
import os, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1]); w = Path(sys.argv[2])
if not os.environ.get("S4E_ENTRY_TRACE_DIR"):
    os.environ.pop("S4E_ENTRY_TRACE_DIR", None)
import corpus_suite_harness as h
paths = h.resolve_paths()
for name, src, exp in (("apply_witness", "        OUTPUT = 'size ' APPLY(.SIZE,'abc')\nEND\n", "size 3"),
                       ("plain_witness", "        OUTPUT = 'hi'\nEND\n", "hi")):
    d = w / ("run_" + name); d.mkdir(exist_ok=True)
    p = d / (name + ".sno"); p.write_text(src)
    out = h.run_all_modes(paths, p, exp, d, ["m3", "m4"])
    print(name, out["m3"].kind, out["m4"].kind, os.environ.get("SCRIP_C2BB_TRACE", "-"))
PY
    ) 2>"$W/drive.err"; }
o1="$(drive "$W/tr")"
echo "=== gate: one SCRIP_C2BB_TRACE file per entry and mode, counted by mark ==="
if [ "$(printf '%s\n' "$o1" | awk '{print $1, $2, $3}' | tr '\n' ' ')" = "apply_witness PASS PASS plain_witness PASS PASS " ]; then ck ok "both witnesses PASS in both modes with the hook armed"
elif [ -z "$o1" ]; then echo "GATE UNPROVEN(2) [$G]: the harness did not grade the fixture: $(tail -2 "$W/drive.err" | tr '\n' ' ')"; exit 2
else ck no "arm 1: $(printf '%s' "$o1" | tr '\n' ' ')"; fi
if grep -q '^apply\.open' "$W/tr/apply_witness.m3.trace" 2>/dev/null && grep -q '^apply\.open' "$W/tr/apply_witness.m4.trace" 2>/dev/null && [ ! -e "$W/tr/plain_witness.m3.trace" ] && [ ! -e "$W/tr/plain_witness.m4.trace" ]; then
    ck ok "apply_witness wrote its own m3 and m4 traces naming apply.open; plain_witness wrote none"
else ck no "arm 2: files [$(ls "$W/tr" 2>/dev/null | tr '\n' ' ')]"; fi
if [ "$(printf '%s\n' "$o1" | awk '{print $4}' | sort -u)" = "-" ]; then ck ok "no SCRIP_C2BB_TRACE is left in the harness's environment after an entry"
else ck no "arm 3: SCRIP_C2BB_TRACE left set: $(printf '%s\n' "$o1" | awk '{print $4}' | sort -u | tr '\n' ' ')"; fi
rm -rf "$W"/run_*; o4="$(drive "")"; n4="$(find "$W" -name '*.trace' -not -path "$W/tr/*" | wc -l)"
if [ -n "$o4" ] && [ "$n4" = 0 ]; then ck ok "FAIL-ONCE: without S4E_ENTRY_TRACE_DIR the same fixture writes no trace file"
else ck no "arm 4: graded=[$(printf '%s' "$o4" | tr '\n' ' ')] trace files outside the armed dir: $n4"; fi
c5="$(python3 "$HERE/util_c2bb_trace_census.py" "$W/tr" 2>&1)"; mkdir -p "$W/empty"; python3 "$HERE/util_c2bb_trace_census.py" "$W/empty" >/dev/null 2>&1; r5=$?
if printf '%s\n' "$c5" | grep -qE '^apply\.open +[0-9]+ +1 +1 +1  tr apply_witness m[34]$' && [ "$r5" = 2 ]; then ck ok "the census counts apply.open on 1 entry (m3 1, m4 1, witness apply_witness) and refuses an empty directory rc=2"
else ck no "arm 5: census [$(printf '%s' "$c5" | grep -E '^apply' | head -1)] empty-dir rc=$r5"; fi
echo "population: $checks arm(s), $fails failed (two mktemp SNOBOL4 witnesses through corpus_suite_harness.run_all_modes, both modes)"
[ "$fails" = 0 ] && { echo "GATE PASS(0) [$G]: $checks of $checks arms hold"; exit 0; }
echo "GATE FAIL(1) [$G]: $fails of $checks arms red"; exit 1
