#!/usr/bin/env bash
# util_fuzz_witness_predicate_ladder.sh — for each tests/snobol4/probe_loose/fuzz witness x mode, find the FINEST
# grading predicate under which it is STABLE.  Companion to util_fuzz_witness_stability.sh.
#
# ⛔⭐ WHY THIS EXISTS.  The stability runner answers one question — "is this witness stable under
# (stdout, rc) as a pair?" — and answered it correctly: 5 of 10 pairs are NOT.  That result was then
# read as "5 pairs are unusable", which is a STRONGER claim than the instrument made.  Stability is
# PREDICATE-RELATIVE.  A witness whose stdout is constantly empty while its crash SIGNAL cycles
# 132/133/139 is unusable for grading an output, and perfectly usable for grading "does it crash" —
# which is the question a memory-safety cure actually has to answer.
#
# ⭐ THE GENERAL SHAPE, and it is this row's own disease seen from the other side: the earlier error
# was an instrument answering a NARROWER question than the sentence built on it (stdout-only read as
# "the witness").  This is the mirror — an instrument answering a WIDER question than the sentence
# needs, and being read as a veto.  Both are the same defect: the predicate was left implicit.
# Naming the predicate is the cure in both directions.
#
# THE LADDER, finest to coarsest.  The finest RUNG THAT IS STABLE is what a cure may be graded on;
# anything finer is noise, anything coarser throws away power the witness still has.
#   P1 (stdout, rc)   strictest — the stability runner's predicate
#   P2 stdout only    usable when a cure must change program OUTPUT
#   P3 rc only        usable when a cure must change TERMINATION
#   P4 crashed?       rc==0 vs rc!=0 — the memory-safety question, coarsest useful rung
#   NONE              disagrees even on P4 -> genuinely excluded, and now for a MEASURED reason
#
# ⛔ P4-stable-but-P1-unstable is NOT a weaker result.  For a memory-safety cure it is the RIGHT
# result: the witness reliably crashes today, so "it stopped crashing" is falsifiable on it.
#
# EXIT: 0 = every witness x mode is stable on at least one rung · 1 = at least one is NONE (a real
# result, not an error) · 2 = REFUSE, could not measure.
# Usage: bash ../harness/scripts/util_fuzz_witness_predicate_ladder.sh          (N=10, both modes)
#        N=30 TIMEOUT=30s bash ../harness/scripts/util_fuzz_witness_predicate_ladder.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
DIR="${FUZZ_DIR:-$ROOT/corpus/tests/snobol4/probe_loose/fuzz}"
N="${N:-10}"; TIMEOUT="${TIMEOUT:-8s}"; MODES="${MODES:-m3 m4}"
[ -d "$DIR" ]                   || { echo "⛔ REFUSE(rc=2): witness dir missing: $DIR"; echo "   The one-flat-suite cutover (corpus c06960a1) ABSORBED 4 of the 5 witnesses into the rungs suite"; echo "   under new names and deleted this directory; only fz_red_m4b survives as a loose pair. The witnesses"; echo "   are not gone, only unreachable BY PATH. Materialize the full set and point FUZZ_DIR at it:"; echo "       FUZZ_DIR=\"\$(bash ../harness/scripts/util_fuzz_witness_materialize.sh)\" bash ../harness/scripts/$(basename "$0")"; exit 2; }
[ -x "$SCRIP" ]                 || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP — build first (make)"; exit 2; }
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
case "$N" in ''|*[!0-9]*) echo "⛔ REFUSE(rc=2): N must be a positive integer, got '$N'"; exit 2;; esac
[ "$N" -ge 2 ]                  || { echo "⛔ REFUSE(rc=2): N=$N cannot detect disagreement — need at least 2"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mapfile -t SNOS < <(find "$DIR" -maxdepth 1 -name '*.sno' | sort)
[ "${#SNOS[@]}" -gt 0 ]         || { echo "⛔ REFUSE(rc=2): zero .sno witnesses in $DIR — an empty set is not a stable set"; exit 2; }

echo "SCRIP  $(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')$([ -n "$(git -C "$SD" status --porcelain 2>/dev/null)" ] && echo ' DIRTY')"
echo "corpus $(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')$([ -n "$(git -C "$ROOT/corpus" status --porcelain 2>/dev/null)" ] && echo ' DIRTY')"
echo "N=$N TIMEOUT=$TIMEOUT MODES=$MODES"
# ⛔⭐ LOAD IS PART OF THE LABEL OF A TIMING-DEPENDENT NUMBER, EXACTLY AS THE TREE HASH IS — but on
# THESE witnesses it is NOT the explanation, and this script must not imply that it is.
# ⛔ HYPOTHESIS RAISED AND THEN KILLED BY MEASUREMENT, recorded because the next reader will have it
# too: this box is one 16-core machine shared by ~20 seat roots, measured at load 20-27 with several
# concurrent pristine builds, so "rc=124 is just the 8s timeout firing under fleet load" is the
# obvious first theory.  IT IS FALSE HERE.  Wall-clock per run (N=8, 20s ceiling) is BIMODAL with
# NOTHING IN BETWEEN: fz_red_m1b 0.02s x2 vs >=20.0s x6; fz_segv_24 0.02s x4 vs >=20.0s x4.  A
# load-induced timeout artifact would cluster durations AROUND the old 8s boundary; these do not go
# near it.  The hang is a genuine unbounded control-flow divergence, and load is irrelevant to it.
# ⭐ Kept as a comment rather than deleted because the theory is reasonable, cheap to re-derive, and
# the DURATION HISTOGRAM is what refutes it — an rc alone never could, which is the whole point.
LOAD1="$(cut -d' ' -f1 /proc/loadavg)"; NCPU="$(nproc)"
echo "load ${LOAD1} on ${NCPU} cpus at start (recorded as provenance; measured NOT to explain the rc=124s here — see header)"
echo

# ⛔ CAPTURE, NEVER PIPE — a crashing subject under `set -o pipefail` makes the pipeline non-zero even
# when the match succeeded, so a piped detector silently under-counts toward green.  (Measured on the
# prolog entry-point gate the same day; kept here because this script's subjects crash BY DESIGN.)
# ⛔ METHODOLOGY IS COPIED VERBATIM FROM util_fuzz_witness_stability.sh's one_run — the cd into $W,
# the -Wl,-rpath -lm link line, the TIMEOUT on the compile step, the md5 of stdout.  DO NOT "improve"
# it here.  Two instruments measuring the same witnesses must differ in exactly ONE axis (the
# predicate ladder) or their results cannot be compared — and a pair of same-day instruments that
# disagreed because each quietly chose its own axis is the whole reason this row exists.
one_run() { # $1=mode $2=sno -> "<rc> <stdout-sha>"
    local mode="$1" sno="$2" out rc
    if [ "$mode" = m3 ]; then out="$(cd "$W" && timeout -k 5 "$TIMEOUT" "$SCRIP" "$sno" </dev/null 2>/dev/null)"; rc=$?
    else
        local s="$W/m4.s" b="$W/m4.bin"; rm -f "$s" "$b"
        if ! (cd "$W" && timeout -k 5 "$TIMEOUT" "$SCRIP" --compile -o "$s" "$sno" </dev/null >/dev/null 2>&1); then echo "CC CC"; return; fi
        if ! gcc -no-pie "$s" -o "$b" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm >/dev/null 2>&1; then echo "LINK LINK"; return; fi
        out="$(cd "$W" && timeout -k 5 "$TIMEOUT" "$b" </dev/null 2>/dev/null)"; rc=$?
    fi
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | md5sum | cut -c1-12)"
}

uniq_n() { printf '%s\n' "$@" | sort -u | wc -l; }
worst=0; unusable=0
printf '%-34s %-4s %-28s %s\n' WITNESS MODE "OBSERVED (rc:count)" "FINEST STABLE PREDICATE"
printf -- '-----------------------------------------------------------------------------------------------------\n'
for sno in "${SNOS[@]}"; do
  base="$(basename "$sno" .sno)"
  for mode in $MODES; do
    rcs=(); shas=(); pairs=[]; pairs=()
    for _ in $(seq 1 "$N"); do
        r="$(one_run "$mode" "$sno")"
        rcs+=("${r%% *}"); shas+=("${r##* }"); pairs+=("$r")
    done
    # the ladder
    n1=$(uniq_n "${pairs[@]}"); n2=$(uniq_n "${shas[@]}"); n3=$(uniq_n "${rcs[@]}")
    crashed=(); for r in "${rcs[@]}"; do case "$r" in 0) crashed+=(clean);; *) crashed+=(nonzero);; esac; done
    n4=$(uniq_n "${crashed[@]}")
    if   [ "$n1" -eq 1 ]; then pred="P1 (stdout,rc) — strictest"
    elif [ "$n2" -eq 1 ]; then pred="P2 stdout only"
    elif [ "$n3" -eq 1 ]; then pred="P3 rc only"
    elif [ "$n4" -eq 1 ]; then pred="P4 crashed? — memory-safety arm"
    else pred="⛔ NONE — genuinely unusable"; unusable=$((unusable+1)); fi
    [ "$n1" -gt 1 ] && worst=1
    hist="$(printf '%s\n' "${rcs[@]}" | sort | uniq -c | awk '{printf "%s:%s ", $2, $1}')"
    printf '%-34s %-4s %-28s %s\n' "${base:0:34}" "$mode" "$hist" "$pred"
  done
done
echo "load ${LOAD1} -> $(cut -d' ' -f1 /proc/loadavg) on ${NCPU} cpus (start -> end)"
echo
if [ "$unusable" -gt 0 ]; then
  echo "⛔ $unusable witness x mode pair(s) disagree even on P4 — those are genuinely excluded."
  exit 1
fi
echo "✅ every witness x mode pair is stable on at least one rung — none needs blanket exclusion."
echo "   ⭐ Grade a memory-safety cure on the coarsest rung a pair supports; do NOT demand P1 of a"
echo "      pair whose P1 instability is in the crash SIGNAL rather than in whether it crashes."
exit 0
