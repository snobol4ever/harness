#!/usr/bin/env bash
# calibrate_bench_scale.sh -- bake corpus/benchmarks/snobol4/SCALE.tsv, the per-kernel fixed
# iteration count angle 2 (bench_snobol4_fixed_iter.sh) runs against.
#
# METHOD: run angle 1 (test_bench_snobol4_timed.sh, fixed TIME / counted ITERS) once, read each
# kernel's measured iters/s for sbl+m3+m4, and take N = fastest_engine_rate * TARGET_SECONDS,
# rounded to 1-2 significant figures. This sizes N so the FASTEST engine on that kernel still runs
# for roughly TARGET_SECONDS -- a slower engine on the SAME N simply takes proportionally longer,
# which is correct (angle 2 bakes one N per kernel, shared by all three engines) and bounded (this
# project's own measured sbl/scrip ratios rarely exceed ~3-4x, so "slower" here means seconds, not
# minutes). Never hand-edit SCALE.tsv -- re-run this script and commit its output; a number picked
# by eye is exactly the "redo from scratch" this row's own brief was minted to end.
#
# Usage: ../harness/scripts/calibrate_bench_scale.sh [TARGET_SECONDS]   (default 2.5)
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"
OUT="${SCALETSV:-$B/SCALE.tsv}"
TARGET="${1:-2.5}"
RAW="$(bash "$HERE/test_bench_snobol4_timed.sh")" || true
{
  echo "# SCALE.tsv -- per-kernel FIXED ITERATION COUNT for angle 2 (bench_snobol4_fixed_iter.sh)."
  echo "# Baked $(date -u +%Y-%m-%dT%H:%M:%SZ) by ../harness/scripts/calibrate_bench_scale.sh, target=${TARGET}s"
  echo "# on the FASTEST of sbl/m3/m4's angle-1-measured rate (a slower engine on this N simply runs"
  echo "# longer -- see this script's own header). Regenerate with this script; never hand-edit."
  awk -v target="$TARGET" '
    function parse(v,   n, suf) {
      if (v == "NA" || v == "-") return -1
      suf = substr(v, length(v), 1)
      n = v + 0
      if (suf == "G") n = n * 1e9
      else if (suf == "M") n = n * 1e6
      else if (suf == "K") n = n * 1e3
      return n
    }
    /^BENCHMARK/{next} /^---/{next} /^$/{next} /^CHECK/{exit} /^  /{next}
    {
      kernel=$1; sbl=parse($2); m3=parse($3); m4=parse($4)
      fastest = sbl; if (m3 > fastest) fastest = m3; if (m4 > fastest) fastest = m4
      if (fastest <= 0) next
      n = fastest * target
      mag = 10 ^ int(log(n)/log(10))
      nr = int(n/mag + 0.5) * mag
      printf "%s\t%d\n", kernel, nr
    }
  ' <<<"$RAW" | sort
} > "$OUT"
echo "wrote $OUT:" >&2
cat "$OUT" >&2
