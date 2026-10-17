#!/usr/bin/env bash
# lib_prolog_bench.sh -- the ONE implementation of two checks every Prolog loop-benchmark angle needs (hq_P 2026-09-02,
# row prolog-instruments-and-baseline-standup). Sourced by test_bench_prolog_timed.sh (angle 1) and bench_prolog_fixed_iter.sh
# (angle 2); a harness that cannot source it REFUSES rc=2 rather than re-implementing either check -- a rule with two copies
# proves the copies agree, never that either is right (same law as lib_perf_fmt.sh / lib_oracle_flags.sh).
#
# ⛔⛔ THE LOOP MUST BE PROVEN TO HAVE LOOPED BEFORE ITS TIME IS DIVIDED BY N. MEASURED on SCRIP f4532dea, -O0, the pin tree of the
# van Roy baseline: the between/3+fail wrapper vanroy/fib.pl (N=64) prints 64 answers on gprolog and on swipl and TWO on SCRIP m3
# and m4 -- then exits 0. Both angle harnesses gated only on bench_rusage's exit= field, so they divided N=65536 by the CPU time of
# two iterations and printed m3 at 3,102,442 iter/s against gprolog's 485 (fib), a 6,400x multiple for a program that had stopped
# after its second iteration. Angle 1 and angle 2 then AGREED on it to within 1% -- the two angles share the defect, so the
# cross-proof certified the fabrication (the "engines agreed at reps=0" witness of RULES.md THE INSTRUMENT LAWS §2, again).
# The cure is not a SCRIP-specific guard (NO PER-ENGINE FILTER): every engine's loop stdout is compared byte-for-byte against N
# copies of the kernel's .ref, and a run whose output is not exactly N answers is reported as what it IS --
# LOOP-OUTPUT-MISMATCH(lines=<seen>/<wanted>) -- and never as a rate. The observation prints first, the belief nowhere.
# gnu_filter is the one gprolog output filter, defined beside the oracle accessors (CEO-1599); four callers source this library and
# not lib_oracle_flags.sh, so it is sourced here when it is not already in scope.
command -v gprolog_output_filter >/dev/null 2>&1 || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
gnu_filter() { gprolog_output_filter; }
# loop_check <engine> <stdout-file> <N> <expected-file>: rc=0 when stdout == N x expected (gnu stdout banner-filtered first, the
# same filter the single-shot correctness gate uses); otherwise echoes the reason and returns 1. No N or no .ref is UNGRADED,
# also rc=1: a loop whose iteration count cannot be verified has no rate.
loop_check() {
  local eng="$1" o="$2" n="$3" exp="$4"
  [ -n "$n" ] && [ -f "$exp" ] || { echo "UNGRADED(no N or no .ref)"; return 1; }
  awk -v n="$n" '{a[NR]=$0} END{for(i=1;i<=n;i++) for(j=1;j<=NR;j++) print a[j]}' "$exp" > "$o.want"
  case "$eng" in gnu) gnu_filter < "$o" > "$o.f" ;; *) cp "$o" "$o.f" ;; esac
  cmp -s "$o.f" "$o.want" && return 0
  echo "LOOP-OUTPUT-MISMATCH(lines=$(wc -l < "$o.f")/$(wc -l < "$o.want"))"; return 1
}
# ⭐ gen_counted_set <outdir> [engine] -- MATERIALISE THE COUNTED KERNEL SET, the ONE replacement for the retired checked-in
# corpus/benchmarks/prolog/vanroy/ directory (hq_P 2026-09-13, CEO-567: the iteration count may not live inside the artifact under
# measurement). vanroy/ was 21 files, each bench/<k>.pl with `main :- l__(N).` frozen in; the N values were lifted verbatim into
# corpus/benchmarks/prolog/fixed-iter-n.tsv when it was retired, so this generates the same 21 programs at the same 21 counts from
# the pristine sources instead of reading a derived artifact out of git. Writes <outdir>/<kernel>.pl and echoes the count.
# ⛔ REFUSES rc=2 on every way of producing a SMALLER set -- missing table, missing generator, zero rows, a row whose bench source
# does not exist, or a generator failure. A census that cannot see its whole population must not print a number (THE INSTRUMENT LAWS):
# the failure this replaces is precisely a board that got quietly shorter when a directory moved.
gen_counted_set() {
  local out="$1" eng="${2:-scrip}"
  local here root pro tsv gen k n src
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="${S4E_HOME:-$(cd "$here/../.." && pwd)}"
  pro="$root/corpus/benchmarks/prolog"; tsv="$pro/fixed-iter-n.tsv"; gen="$here/bench_prolog_wrap.sh"
  [ -s "$tsv" ] || { echo "⛔ REFUSED (rc=2): committed-N table missing or empty: $tsv" >&2; return 2; }
  [ -x "$gen" ] || { echo "⛔ REFUSED (rc=2): wrapper generator missing: $gen -- the counted form is generated, never checked in (CEO-567)" >&2; return 2; }
  mkdir -p "$out" || return 2
  local made=0
  while IFS=$'\t' read -r k n _nr; do   # _nr: the rival count column (CEO-1281) -- this set is the SCRIP count's; a two-field read would swallow it into n
    case "$k" in ''|'#'*|kernel) continue ;; esac
    case "$n" in ''|*[!0-9]*) echo "⛔ REFUSED (rc=2): $tsv row '$k' has a non-numeric N '$n'" >&2; return 2 ;; esac
    src="$pro/bench/$k.pl"
    [ -f "$src" ] || { echo "⛔ REFUSED (rc=2): $tsv names '$k' but $src does not exist -- an orphan denominator entry is a lie, not a smaller board" >&2; return 2; }
    "$gen" "$src" --mode=iter --n="$n" --engine="$eng" -o "$out/$k.pl" >/dev/null 2>&1 \
      || { echo "⛔ REFUSED (rc=2): $(basename "$gen") failed to wrap $k at n=$n" >&2; return 2; }
    # ⭐ THE N SIDECAR (hq_P 2026-09-13).  N is what makes the run GRADEABLE: loop_check needs it to build
    # the N x .ref it compares stdout against.  Without it every consumer of this set is left grading
    # "did it exit 0", which scored ten silent no-ops as passes for months.  Written beside the kernel so a
    # consumer cannot reach the program without also being able to reach its iteration count.
    printf '%s\n' "$n" > "$out/$k.n" || return 2
    made=$((made+1))
  done < "$tsv"
  [ "$made" -gt 0 ] || { echo "⛔ REFUSED (rc=2): $tsv carries zero kernel rows -- an empty set is not a green board" >&2; return 2; }
  echo "$made"
}
