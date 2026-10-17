#!/usr/bin/env bash
# util_out_sweep.sh — per-program mode-3 RUN-OUTPUT md5 sweep, for behavioural blast-radius gates.
#   bash ../harness/scripts/util_out_sweep.sh OUT.md5 [LISTFILE]        SCRIP=/path/to/scrip selects the arm
# The OUTPUT counterpart to util_s_md5_sweep.sh (which hashes --compile .s text and cannot see a runtime defect).
# Compare arms with:  diff A.md5 B.md5.  Row format:  <value>\t<path>  where value = md5 | RUN_RC_<rc> | RUN_FLAKY.
#
# ⛔ THIS IS THE INSTRUMENT s148 USED UNSOUNDLY AND s149 COULD NOT NAME (s149 NEXT-SEAT item 1).  NAMED AND FIXED
# HERE, s150, mechanism measured not guessed.  s148 saw "7 of 510 differ run-to-run under a FIXED .so" and split
# them into "5 already-crashing + 2 TIME() deltas".  Both halves are ONE root cause with TWO faces, and the second
# face is created BY THE SWEEP ITSELF:
#   (a) rc!=0 runs emit nondeterministic text (partial stdout + a crash message racing the flush), so hashing a
#       dead run manufactures movers.  Same s33 "non-empty is not alive" class util_s_md5_sweep.sh fixed at s149.
#   (b) ⛔ ELAPSED-TIME FIELDS TRACK MACHINE LOAD, SO ANY *PARALLEL* SWEEP IS SELF-POISONING.  Measured s150:
#       demo/calculator-1 and calculator-2 run SERIALLY are byte-identical to each other and stable across 3 runs
#       (md5 fd95ab76); run under `xargs -P $(nproc)` they take TWO different md5s, match NEITHER serial value, and
#       SWAP with each other between runs -- which reads exactly like cross-contamination and is not.  Root cause
#       proven by diffing the text, not the hash: `match_ms=0` serial vs `match_ms=1` under load, stdout otherwise
#       byte-identical.  demo/snobol4/json/json.sno is the same shape (`match_ms=`, TIME() at :273/:275) and was likewise a
#       FALSE mover in the s150 CN-8 A/B -- serially it is 8d262c4d on BOTH arms.
# CURE, faces (a)+(b): rc is recorded and a failed run is labelled RUN_RC_<rc> (stable in both arms, never hashed);
# and every elapsed-time field is normalised to a constant BEFORE hashing, which makes the sweep parallel-safe
# instead of merely parallel-fast.  ⛔ NORMALISE, DO NOT EXCLUDE: dropping the programs would blind the sweep to
# real defects in exactly the demos (json, calculator) that exercise the biggest pattern graphs in the corpus.
#
# ⛔ FACE (c) — AN INTERMITTENT CRASH DEFEATS FACES (a) AND (b) AT ONCE, AND READS AS A MOVER IN EITHER DIRECTION
# (seat1 s170, routed as queue row `sweep-false-mover-defence`; cured here s185/seat2).  Witness:
# `crosscheck/patterns/141_pat_eval_double_fn_arbno` is m3 rc=0 run serially and an INTERMITTENT load-dependent
# rc=139 under a parallel sweep.  Face (a)'s cure is not a cure here — the LABEL is what moves (an md5 in one arm,
# RUN_RC_139 in the other), and WHICH arm draws which is a coin flip, so a single-sample sweep manufactures a
# mover in EITHER direction and the direction reads as a win or as a regression AT RANDOM.  Face (b) cannot see it
# either: a run that dies never reaches its elapsed-time fields.  A timeout under load (rc=124) is the same shape.
# CURE (c): ⭐ THE SWEEP IS ITS OWN CONTROL ARM.  Every program is sampled REPS times (default 3) across REPS FULL
# PASSES — full passes, NOT REPS back-to-back runs inside one xargs slot, because the defect is LOAD-dependent and
# back-to-back samples share one load draw.  All REPS samples equal ⇒ that value.  Not equal ⇒ `RUN_FLAKY`, a
# VALUE-FREE label that is stable in both arms, so a diff cannot manufacture a mover from it.  Value-free is the
# load-bearing part: a label carrying the distinct-sample COUNT would itself move (2 in one arm, 3 in the other).
# ⛔ THE DEFENCE DOES NOT BLIND THE SWEEP.  It suppresses ONLY the both-arms-flaky case, which is the only
# false-mover case.  Flaky-in-A but stable-in-B still DIFFERS (RUN_FLAKY vs md5) and still reads as a mover — and
# that is correct, because an arm that CREATES or CURES nondeterminism is a real finding.  Same doctrine as
# NORMALISE-DO-NOT-EXCLUDE above, and the pin file is a DECLARATION, NEVER AN EXCLUSION: pinned programs are still
# run REPS times and still compared; the pin only decides whether a flake prints as `pinned` or as `⛔ NEW`.
# ⛔ REPS=1 DISARMS FACE (c) and says so on stderr.  Cost measured s185, 583 programs, 16 cpus, SCRIP ffbc1425:
# REPS=1 2.5s · REPS=3 7.4s — the whole defence is ~5s, which is why it is ON BY DEFAULT and not an opt-in flag.
# NEGATIVE TEST: `../harness/scripts/test_gate_out_sweep_flaky.sh` injects a flaky arm and asserts all three behaviours — the
# false mover REPRODUCED at REPS=1 in BOTH directions, CAUGHT at REPS=3, and a genuinely-moved program still read
# as a mover at REPS=3.  ⛔ Run it after ANY edit to this file; a defence with no negative test is a claim.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SC="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$SC/scrip}"; CORPUS="${CORPUS:-$S4E/corpus}"; TMO="${TMO:-25}"
REPS="${REPS:-3}"; [ "$REPS" -ge 1 ] 2>/dev/null || REPS=3
PIN="${SWEEP_PIN:-$HERE/util_out_sweep.pins}"
OUT="${1:?usage: util_out_sweep.sh OUT.md5 [LISTFILE]}"; LIST="${2:-}"
T="$(mktemp)"; RAW="$(mktemp)"; FLP="$(mktemp)"; trap 'rm -f "$T" "$RAW" "$FLP"' EXIT
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- the library/probe_reference/bb find below now contributes 0 by construction. EXPECTED, not a
# regression; pass LISTFILE to include tests/snobol4/probe/bb*.sno entries (materialize via
# corpus_suite_harness.py extract first -- suite files are not standalone-runnable .sno programs).
if [ -n "$LIST" ]; then cp "$LIST" "$T"; else
  { find "$CORPUS/crosscheck" -name '*.sno'; find "$CORPUS/library/probe_reference/bb" -name '*.sno'; find "$CORPUS/tests/snobol4/probe_loose/cn" -name '*.sno'
    find "$CORPUS/probe/kw" -name '*.sno'; find "$CORPUS/probe/arbnostore" -name '*.sno'
    find "$CORPUS/demos" -maxdepth 1 -name '*.sno'; } | sort > "$T"; fi
run1() { local p="$1" d o rc; d="$(dirname "$p")"
  o="$(cd "$d" && SNO_LIB="$d" timeout -k 5 "$TMO" "$SCRIP" --run "$p" </dev/null 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then printf 'RUN_RC_%s\t%s\n' "$rc" "$p"; return; fi
  printf '%s\t%s\n' "$(printf '%s' "$o" | sed -E 's/(match_ms|_ms|msec|elapsed|execution time msec)[= ]+[0-9]+/\1=<T>/g' | md5sum | cut -d' ' -f1)" "$p"; }
export -f run1; export SCRIP TMO
[ "$REPS" -eq 1 ] && echo "⛔ util_out_sweep: REPS=1 — face (c), the intermittent-crash defence, is DISARMED; one sample cannot tell a mover from a coin flip" >&2
for _r in $(seq 1 "$REPS"); do xargs -a "$T" -P "$(nproc)" -I{} bash -c 'run1 "$@"' _ {} >> "$RAW"; done
awk -F'\t' -v FL="$OUT.flaky" 'BEGIN{OFS="\t"}{v=$1;p=$2;n[p]++;if(!((p SUBSEP v) in s)){s[p SUBSEP v]=1;d[p]++;agg[p]=((p in agg)?agg[p]" "v:v)}last[p]=v}END{for(p in n){if(d[p]==1)print last[p],p;else{print "RUN_FLAKY",p;print p,d[p]"/"n[p],agg[p] > FL}}}' "$RAW" | sort -k2 > "$OUT"
[ -f "$OUT.flaky" ] || : > "$OUT.flaky"
sort -o "$OUT.flaky" "$OUT.flaky"; cut -f1 "$OUT.flaky" > "$FLP"; FLN="$(wc -l < "$FLP")"
echo "$(wc -l < "$OUT") programs -> $OUT   (REPS=$REPS, flaky=$FLN)"
if [ "$FLN" -gt 0 ]; then echo "⛔ $FLN NONDETERMINISTIC program(s), labelled RUN_FLAKY in BOTH arms so they cannot be read as movers — samples in $OUT.flaky" >&2
  while read -r p; do if [ -f "$PIN" ] && grep -qxF "$p" "$PIN"; then echo "   pinned $p" >&2; else echo "   ⛔ NEW  $p" >&2; fi; done < "$FLP"; fi
if [ -f "$PIN" ]; then grep -v '^[[:space:]]*\(#\|$\)' "$PIN" | while read -r p; do grep -qxF "$p" "$FLP" || echo "   stale pin (stable across $REPS reps this run) $p" >&2; done; fi
if [ "${SWEEP_PIN_UPDATE:-0}" = 1 ]; then cp "$FLP" "$PIN"; echo "   pins rewritten ($FLN) -> $PIN" >&2; fi
exit 0
