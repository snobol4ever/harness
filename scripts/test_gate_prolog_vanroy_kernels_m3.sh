#!/usr/bin/env bash
# The van Roy kernels must RUN in mode 3, in their COUNTED form. hq_P's I26 reported them as one "m3 crash
# class"; measured, they are FOUR distinct classes (trail-arena refusal, timeout, stack overflow, and an
# unbound variable printed as the answer). Refuses rc=2 when it cannot measure -- never skip-as-success.
#
# ⛔⭐ THE KERNELS ARE GENERATED, NOT READ OUT OF GIT (hq_P 2026-09-13, CEO-567). This gate used to enumerate
#   corpus/benchmarks/prolog/vanroy/*.pl -- 21 checked-in files, each bench/<k>.pl with `main :- l__(N).`
#   frozen in, i.e. the iteration count living inside the artifact under measurement. That directory is
#   RETIRED. The same 21 kernels at the same 21 counts are now built on demand by gen_counted_set() from
#   the pristine bench/ sources plus corpus/benchmarks/prolog/fixed-iter-n.tsv, which is where those N
#   values were lifted to, verbatim by execution, so the retirement re-calibrated nothing.
#   THE NAME STAYS: "van Roy" is the kernels' PROVENANCE (van Roy's Prolog benchmark set), never the name
#   of the directory that used to hold a generated copy of them.
set -u
here=$(cd "$(dirname "$0")/../../SCRIP" && pwd)
root=$(cd "$here/.." && pwd)
[ -x "$here/scrip" ] || { echo "REFUSE: no ./scrip in $here -- run make first"; exit 2; }
. "$here/../harness/scripts/lib_prolog_bench.sh" 2>/dev/null || { echo "REFUSE: cannot source lib_prolog_bench.sh -- the one authority for materialising the counted set"; exit 2; }
d=$(mktemp -d "${TMPDIR:-/tmp}/vanroy_m3.XXXXXX") || { echo "REFUSE: cannot create a work dir"; exit 2; }
trap 'rm -rf "$d"' EXIT
n=$(gen_counted_set "$d" scrip) || exit 2
[ "$n" -gt 0 ] || { echo "REFUSE: zero .pl kernels generated -- a census that cannot see its population must not print 0"; exit 2; }
# ⛔⭐ THIS GATE GRADES OUTPUT, NOT EXIT STATUS (hq_P 2026-09-13, CEO-676).  It used to score a kernel
#   PASS on `rc == 0` alone.  Measured: TEN of the 21 exited 0 having printed NOTHING AT ALL -- they were
#   generated from pre-conversion sources, raised existence_error at their first goal, and never reached the
#   computation.  All ten scored as passes for months.  `nrev` and `qsort` exit 0 having printed 1438 and
#   1338 lines where N=65536 and 16384 were asked -- truncated runs scored as clean.  loop_check() compares
#   stdout against N copies of the kernel's .ref, which is the only evidence the loop ran N times.
#   A pass criterion weaker than the claim the gate is read as making is the same defect as a blank cell.
. "$here/../harness/scripts/lib_perf_fmt.sh" 2>/dev/null || { echo "REFUSE: cannot source lib_perf_fmt.sh -- the one authority for stamping a measurement with its load"; exit 2; }
bench="$root/corpus/benchmarks/prolog/bench"
bad=0; dark=0
for f in "$d"/*.pl; do
  b=$(basename "$f"); k="${b%.pl}"
  (cd "$d" && timeout -k 5 30 "$here/scrip" "$b" < /dev/null > "$d/$k.stdout" 2> "$d/$k.stderr"); rc=$?
  if [ "$rc" != 0 ]; then
    bad=$((bad+1)); printf 'FAIL %-16s rc=%-4s %s\n' "$b" "$rc" "$(head -1 "$d/$k.stderr" 2>/dev/null | cut -c1-72)"; continue
  fi
  # rc=0 is NOT the verdict -- prove the loop actually ran N times and printed N answers
  why=$(loop_check scrip "$d/$k.stdout" "$(cat "$d/$k.n" 2>/dev/null)" "$bench/$k.ref") || {
    dark=$((dark+1)); printf 'FAIL %-16s rc=0 BUT %s\n' "$b" "$why"; }
done
echo "van Roy m3 census (counted form, generated): kernels=$n non-zero-exit=$bad rc0-but-wrong-output=$dark"
echo "⛔ THIS VERDICT MOVES WITH MACHINE LOAD AND IS NOT A GRADE OF THE COMPILER UNTIL THE PROLOG HEAP LEAK IS CURED."
echo "   measured at $(perf_load_stamp) -- a counted Prolog loop retains 89.5 kB/iteration (dead linear), so a"
echo "   budget-driven N crosses the leak threshold on a FAST box and stays under it on a LOADED one: these"
echo "   kernels go GREEN WHEN THE BOX IS BUSY. Witness .github/probes/prolog-heap-leak-2026-09-13/, routed to hq_V/cto."
[ $((bad + dark)) -eq 0 ] || { echo "GATE RED: $bad of $n van Roy kernels do not run in mode 3, and $dark more exit 0 without producing their N answers"; exit 1; }
command -v swipl > /dev/null || { echo "REFUSE: no swipl -- cannot grade the answer arm"; exit 2; }
for b in queens.pl queens_8.pl; do
  [ -f "$d/$b" ] || continue
  got=$(cd "$d" && timeout -k 5 30 "$here/scrip" "$b" < /dev/null 2>/dev/null | head -1)
  want=$(cd "$d" && timeout -k 5 30 swipl -q -g halt "$b" < /dev/null 2>/dev/null | head -1)
  [ -n "$want" ] || { echo "REFUSE: oracle produced nothing for $b"; exit 2; }
  [ "$got" = "$want" ] || { echo "GATE RED: $b first answer [$got] != oracle [$want]"; exit 1; }
done
echo "van Roy GREEN: $n generated counted kernels run in mode 3 and the queens answers match the oracle"
