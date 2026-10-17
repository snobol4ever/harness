#!/usr/bin/env bash
# test_gate_bench_prolog_kernels_pristine.sh -- EVERY PROLOG BENCHMARK KERNEL IS PRISTINE AND HAS A REF
# (CEO-567, RULES.md:321, ARCH-PROGRAM-LEDGER.md; row bench-kernels-are-not-pristine-and-carry-no-refs).
#
# THE RULE: a benchmark kernel's source holds the COMPUTATION AND NOTHING ELSE. The timing bracket and the
# iteration loop are GENERATED around it by ../harness/scripts/bench_prolog_wrap.sh, and every kernel carries a ref cut
# from the ORACLE so the run that is timed is also graded.
#
# WHY THIS GATE EXISTS -- MEASURED hq_P 2026-09-13, SCRIP 202d8bfff, corpus 7bedb92d0, and the reason it is a
# gate rather than a one-off cleanup:
#   corpus/benchmarks/prolog/bench/ shipped TWO conventions in ONE directory -- 13 pristine result-signature
#   kernels and 10 with a wall_us/wall_ms bracket baked into main/0.  The rival arms consult
#   prelude_gplc.pl / prelude_swipl.pl, which define wall_us/1, so gprolog and swipl kept publishing real
#   numbers for all 23.  ⛔ SCRIP HAS NO PROLOG-REACHABLE WALL CLOCK AT ANY SPELLING, so on the engine
#   actually under measurement each of the ten raised existence_error(wall_us/1), printed NO answer, and
#   EXITED 0.  A sweep counted that as a run.  The defect was therefore invisible from every direction that
#   mattered: the board was full, the rival columns were real, and the SCRIP column was empty for a reason
#   nothing reported.  That is the shape this gate exists to make impossible -- not the ten files, which are
#   already cured, but the SECOND convention silently reappearing beside the first.
#
# ⭐ IT ALSO CAUGHT A REAL RED THE MOMENT IT MADE ONE MEASURABLE: with the bracket gone, tak.pl reaches
#   SCRIP and dies at ERROR 246 stack overflow.  That red is now visible instead of masked; it is a Prolog
#   runtime defect, not a benchmark defect, and it is filed rather than fixed here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
BD="${1:-$ROOT/../corpus/benchmarks/prolog/bench}"
WRAP="$HERE/bench_prolog_wrap.sh"
# REFUSES rc=2 WHEN IT CANNOT MEASURE -- never skip-as-success (RULES.md: a test that cannot measure refuses).
[ -d "$BD" ] || { echo "GATE REFUSED (rc=2): no kernel directory at $BD -- nothing was checked" >&2; exit 2; }
n=$(ls "$BD"/*.pl 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "GATE REFUSED (rc=2): $BD/*.pl matched 0 files -- a green here would be an empty claim" >&2; exit 2; }
[ -x "$WRAP" ] || { echo "GATE REFUSED (rc=2): the generator $WRAP is missing -- the kernels would be pristine with nothing able to wrap them" >&2; exit 2; }
# ⭐⛔ NAME THE CORPUS TREE THIS GATE GRADED, ON THE VERDICT LINE, GREEN OR RED (hq_P 2026-09-13, on hq_B's
# report). THIS GATE READS A SIBLING REPO. hq_B ran it against a corpus checkout predating the conversion
# commit 84249578f and got a full, well-formed "23 of 23 violate the contract" -- a content verdict whose real
# cause was cross-repo staleness, escalated as a standing red and costing a round trip to disprove. Nothing in
# the output could have told them: the gate named the DIRECTORY and never the TREE, and a seat whose SCRIP is
# current has no reason to suspect its corpus is not. A gate that grades a repo it does not live in must say
# which commit of that repo it graded, or every one of its verdicts is unfalsifiable from the outside.
CTREE="$(git -C "$BD" rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
CDIRTY=""; [ "$CTREE" = UNKNOWN ] || git -C "$BD" diff --quiet HEAD -- "$BD" 2>/dev/null || CDIRTY=" -dirty"
bad=0
for pl in "$BD"/*.pl; do
  k=$(basename "$pl" .pl); why=""
  # 1. NO TIMING AND NO ITERATION BUILTIN IN THE SOURCE. The spellings are every one the three engines use.
  #    Comments are stripped first: the cure for these ten files left prose behind describing a bracket that
  #    no longer existed, and prose that names a builtin is not a builtin.
  code=$(sed 's/^%.*//' "$pl")
  if printf '%s' "$code" | grep -qE '\b(wall_us|wall_ms|statistics|real_time|get_time|cputime|realtime)\b'; then
    why="$why timing-builtin"; fi
  if printf '%s' "$code" | grep -qE '^\s*l__\(|between\(\s*1\s*,\s*[0-9]+\s*,'; then
    why="$why baked-iteration-loop"; fi
  # 2. THE CONTRACT bench_prolog_wrap.sh READS. Without it the generator would emit a wrapper whose bracket
  #    encloses nothing, and the harness would publish the startup cost as the work.
  grep -qE '^% \*BENCH kernel='"$k"'\b' "$pl" || why="$why no-BENCH-marker"
  grep -qE '^bench_work\(' "$pl"             || why="$why no-bench_work/1"
  grep -qE '^main :- bench_work\(Res\), write\(Res\), nl\.$' "$pl" || why="$why no-standalone-main"
  # 3. A REF, SO THE RUN THAT IS TIMED IS ALSO GRADED -- <k>.ref, the one expected-output spelling (CEO-1222, Lon:
  #    "do not use *.expected or other, just *.ref"), which lib_prolog_bench.sh and every harness beside it read.
  [ -s "$BD/$k.ref" ] || why="$why no-ref"
  [ -n "$why" ] && { echo "⛔ NOT PRISTINE: $k --$why"; bad=$((bad+1)); }
done
# 4. NO CHECKED-IN WRAPPED FORM MAY REAPPEAR ANYWHERE UNDER benchmarks/prolog/ (hq_P 2026-09-13, CEO-567).
#    ⛔ THE KERNELS BEING PRISTINE IS ONLY HALF THE CONTRACT: for months bench/ and a SECOND directory,
#    vanroy/, coexisted -- the same 21 programs with `main :- l__(N).` frozen in, i.e. the iteration count
#    inside the artifact under measurement, regenerated by a script that has since been retired. Curing the
#    kernels without forbidding the second convention leaves the exact state this gate's header describes,
#    one directory over. So the check is a SWEEP, not a per-file test: any .pl under benchmarks/prolog/
#    outside the reference tree src/ that carries a generated loop wrapper is a RED, whatever it is named.
#    ⭐ KEYED ON THE WRAPPER'S OWN SHAPE, NEVER ON THE NAME "vanroy" -- a guard keyed on a directory name is
#    not a guard, it is a coincidence (this root has two inert guards that died exactly that way when a
#    re-grid renamed their target). The generator writes `l__(N__) :- between(1, N__, _)`; that line is what
#    is searched for, so a wrapped form under any new name is caught by the same check.
wrapped=$(grep -rlE '^l__\(N__\) :- between|^main :- l__\([0-9]+\)\.' "$BD/.." --include='*.pl' 2>/dev/null \
          | grep -v "/src/" | sort)
if [ -n "$wrapped" ]; then
  echo "⛔ CHECKED-IN WRAPPED FORM(S) under benchmarks/prolog/ -- the iteration count belongs in fixed-iter-n.tsv,"
  echo "   and the wrapper is GENERATED by $(basename "$WRAP") --mode=iter (CEO-567). Offending file(s):"
  printf '     %s\n' $wrapped
  bad=$((bad+1))
fi
# 5. THE GENERATOR MUST REFUSE A NON-PRISTINE KERNEL, or the contract is advisory. Negative-tested here so
#    the gate proves the refusal rather than trusting it.
probe=$(mktemp -t gate_nonpristine_XXXXXX.pl)
{ echo "% *BENCH kernel=probe"; echo ":- initialization(main)."
  echo "bench_work(X) :- wall_us(X)."; echo "main :- bench_work(Res), write(Res), nl."; } > "$probe"
"$WRAP" "$probe" --mode=single --engine=gnu >/dev/null 2>&1
rc=$?; rm -f "$probe"
[ "$rc" = 2 ] || { echo "⛔ THE GENERATOR DID NOT REFUSE a kernel carrying wall_us (rc=$rc, wanted 2) -- the contract is unenforced"; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then
  echo "GATE RED: $bad of $n Prolog benchmark kernel(s) violate the pristine-kernel contract  [corpus $CTREE$CDIRTY]"
  echo "   ⛔ BEFORE FILING THIS: the kernels live in the SIBLING corpus repo, graded here at $CTREE$CDIRTY. The"
  echo "      pristine convention landed at corpus 84249578f -- a checkout older than that reads 23 of 23 red for"
  echo "      staleness, not for content. Run: git -C \"$BD\" fetch origin && git -C \"$BD\" merge --ff-only origin/main"
  exit 1
fi
echo "GATE GREEN: $n Prolog benchmark kernels are pristine, carry the bench_work/1 contract and a ref, and the generator refuses a non-pristine source  [corpus $CTREE$CDIRTY]"
exit 0
