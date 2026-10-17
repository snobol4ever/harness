#!/bin/bash
# test_gate_vanroy_prolog_acceptance.sh -- the PERF-SIDE ACCEPTANCE INSTRUMENT of the PROLOG REDESIGN program (Lon escalation 2026-09-02 10:00, ceo-routed; hq_P owns P6 and P7).
#
# ⭐ WHAT IT GRADES: the 21 van Roy kernels in their COUNTED form, mode 3, GENERATED per run (see the note at D= below; they were read from the retired corpus/benchmarks/prolog/vanroy/ until 2026-09-13). Baseline measured by hq_P at SCRIP fa12d7cb, -O0:
#     3 CLEAN · 8 REFUSE (rc=134) · 8 SIGSEGV (rc=139) · 2 rc=1
# The 8 REFUSE are derive deriv divide10 ham meta_qsort queens sendmore tak, and every one is the SAME failure -- "SCRIP FATAL: pl_trail_unwind refuses corrupt trail mark ... its PRODUCER handed
# over garbage" -- i.e. the PZ-4 trail-mark-corruption class. That is why PZ-4 (hq_C) lands first and P7/P6 sequence behind it.
#
# ⛔⛔ WHY IT DOES NOT GRADE "REFUSE 0" ALONE, WHICH IS WHAT THE PROGRAM WAS FIRST SCOPED AS (hq_P raised it, and it is the single most important line in this file): THE REFUSAL IS A GUARD.
# `pl_trail_unwind` REFUSES because it caught a corrupt trail mark before acting on it. So a change that turns a REFUSE into a SIGSEGV PASSES a REFUSE-0 criterion -- and so does DELETING THE GUARD.
# ⭐ THAT IS NOT HYPOTHETICAL HERE: there are ALREADY 8 SIGSEGVs sitting beside the 8 REFUSEs, so "make the refusals stop" has a shorter path than curing them, and it ends at a board that is strictly
# worse than today while reading green. An acceptance test whose cheapest satisfying change is a regression is the vacuous-test class Lon flagged, aimed at the row Lon escalated.
# ✅ SO ACCEPTANCE IS ALL THREE AT ONCE: REFUSE 0 **and** SIGSEGV 0 **and** CLEAN never below the pinned floor. Any one alone is gameable; together they are not.
#
# ⛔ NEVER LOWER A PIN TO REACH GREEN. Raising CLEAN_FLOOR after a real cure is the intended motion and belongs in the same commit as the cure, citing the FINDING.
#
# ⛔⛔⭐ AND IT REPEATS EACH KERNEL, BECAUSE A SINGLE PASS OVER THIS BOARD IS NOT A MEASUREMENT. MEASURED hq_P 2026-09-02 on ONE UNCHANGED BINARY (SCRIP fa12d7cb), four consecutive full passes:
#   CLEAN 3,4,4,4 · REFUSE 8,4,7,5 · CRASH 8,11,8,10
# ELEVEN OF THE 21 KERNELS FLIP between REFUSE, CRASH and CLEAN run to run with no change of any kind -- derive deriv divide10 ham log10 meta_qsort ops8 queens sendmore tak times10. `tak` reads R.R.
# (clean half the time); `deriv` reads .RRR. ⛔ SO "REFUSE 0" AS A SINGLE-PASS CRITERION IS NOT REPRODUCIBLE: a seat can reach it BY CHANCE, and can read a real cure as a regression, in the same hour.
# ⭐ THE CURE FOR THE INSTRUMENT IS WORST-OF-N: each kernel runs REPS times and is classified by its WORST outcome (CRASH > REFUSE > other > CLEAN). That is monotone and stable -- a kernel counts as
# CLEAN only if it is clean EVERY time -- so the board stops flapping and a cure has to hold, not merely occur once.
# ⭐ THE FLAPPING IS ALSO EVIDENCE, AND IT BELONGS IN THE DESIGN PAGE: a corrupt trail mark that sometimes crashes and sometimes gets CAUGHT by pl_trail_unwind is reading memory whose content varies
# between runs -- consistent with the retained frame living BELOW rsp and being clobbered by whatever the next call happens to write there. That is PZ-4's clause (a) mechanism, observed from the outside.
set -u
R="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the SEAT ROOT is derived from THIS script, never a hardcoded seat (hq_C measured 2026-09-02: the old /home/claude_P default graded hq_P's checkout from hq_C's seat)

CLEAN_FLOOR=3      # WORST-OF-REPS, measured hq_P 2026-09-02, SCRIP fa12d7cb, -O0, mode 3: fib nrev queens_8 are clean on every pass. Raise it WITH a cure, never lower it.
REPS="${VANROY_REPS:-3}"   # worst-of-N. 1 is NOT a valid setting for a verdict -- see the header; it is offered only for a quick eyeball.
cd "$R/SCRIP" 2>/dev/null || { echo "⛔ REFUSED (rc=2): no $R/SCRIP"; exit 2; }
[ -x ./scrip ] || { echo "⛔ REFUSED (rc=2): ./scrip is not built -- a board built on a missing binary is a plausible all-FAIL table, not a measurement"; exit 2; }
# ⛔⭐ THE 21 KERNELS ARE GENERATED, NOT READ OUT OF GIT (hq_P 2026-09-13, CEO-567). This gate used to read
# corpus/benchmarks/prolog/vanroy/*.pl -- 21 checked-in files, each bench/<k>.pl with `main :- l__(N).` frozen in, i.e. the
# iteration count living inside the artifact under measurement. That directory is RETIRED; gen_counted_set() rebuilds the same
# 21 kernels at the same 21 counts from the pristine bench/ sources plus corpus/benchmarks/prolog/fixed-iter-n.tsv, which is
# where those N values were lifted to, verbatim by execution. THE NAME STAYS: "van Roy" is the kernels' PROVENANCE, not the
# directory's. ⛔ The CLEAN_FLOOR above was pinned against the OLD checked-in files, which were generated from PRE-conversion
# bench/ sources (they wrapped a self-timing main/0 that raised existence_error(wall_us/1)); the subject is the same 21
# computations at the same counts, but it is not the same bytes -- so the floor is re-proven against this form, never assumed.
# ⛔⭐ FOURTH DIMENSION, REPORTED NOT BLOCKING (hq_P 2026-09-13, CEO-676): "CLEAN" HERE MEANS rc=0, AND rc=0 IS
# WEAKER THAN THE CLAIM THIS BOARD IS READ AS MAKING. Measured on this tree with loop_check() wired into the m3
# census: SEVEN of the 21 exit 0 WITHOUT producing their N answers -- deriv 26954/65536, divide10 15186/65536,
# meta_qsort 199/1024, nrev 1438/65536, ops8 26954/65536, zebra 11/256, and ham 107/16 (which OVER-produces,
# because the wrapper's trailing `fail` backtracks into a nondeterministic kernel). A truncated run scored CLEAN.
# ⛔ SO WHY IS THE VERDICT NOT SIMPLY RE-CUT? BECAUSE `nrev` IS ONE OF THE THREE KERNELS CLEAN_FLOOR=3 IS PINNED
# ON. Redefining CLEAN to include the output check would drop CLEAN below its own floor and the gate would read
# as a REGRESSION when nothing regressed -- and the cure for that reads as LOWERING A PIN, which line 15 forbids
# outright and rightly: it is the motion every gamed gate makes. ⭐ A criterion that gets STRONGER is not a cure
# and must never be cashed as one, and it is not a regression either; it is a re-cut baseline, and the honest
# shape for a re-cut is the SUITES.tsv `criterion_changed` discipline -- the new number published BESIDE the old
# with its reason, never silently in place of it. So CLEAN_FLOOR keeps grading exactly what it was pinned
# against (rc=0, worst-of-REPS), and CLEAN_GRADED is printed beside it, named per kernel, blocking NOTHING today.
# ⛔ THE RAMP TO BLOCKING IS A ceo/Lon DECISION, NOT A SCRIPT AUTHOR'S -- it needs the floor re-pinned against the
# graded criterion in the same commit, citing the measurement. Until then this half is EVIDENCE, not a verdict.
. "$R/harness/scripts/lib_prolog_bench.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot source lib_prolog_bench.sh -- the one authority for materialising the counted set"; exit 2; }
. "$R/harness/scripts/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot source lib_perf_fmt.sh -- the one authority for stamping a measurement with its load"; exit 2; }
D=$(mktemp -d "${TMPDIR:-/tmp}/vanroy_accept.XXXXXX") || { echo "⛔ REFUSED (rc=2): cannot create a work dir"; exit 2; }
trap 'rm -rf "$D"' EXIT
gen_counted_set "$D" scrip >/dev/null || exit 2
n=0; clean=0; refuse=0; segv=0; other=0; refuse_l=""; segv_l=""; other_l=""
clean_graded=0; ungraded_l=""; BENCH="$R/corpus/benchmarks/prolog/bench"
for f in "$D"/*.pl; do
    [ -f "$f" ] || continue
    n=$((n+1)); b="$(basename "$f" .pl)"; worst=0; seen=""
    # worst-of-REPS: 3 CRASH > 2 REFUSE > 1 other > 0 CLEAN. A kernel is CLEAN only if it is clean EVERY pass.
    i=0; while [ $i -lt "$REPS" ]; do i=$((i+1))
        # ⛔ STDOUT GOES STRAIGHT TO THE FILE, NEVER THROUGH $( ) (hq_P 2026-09-13, caught by this gate's own
        # first run). Command substitution STRIPS TRAILING NEWLINES, so writing it back out cost exactly one
        # line and loop_check read cal 65535/65536, fib 63/64, sendmore 255/256 -- three PASSING kernels
        # reported as failures, in an off-by-one that looks like a real truncation. The tell was the pattern:
        # three mismatches each exactly one short of a power of two. An instrument that damages its own
        # evidence on the way to the comparison is the same class as grading by exit code.
        timeout -k 5 60s ./scrip "$f" < /dev/null > "$D/$b.stdout" 2>"$D/$b.err"; rc=$?
        out="$(cat "$D/$b.stdout" "$D/$b.err" 2>/dev/null)"
        if   printf '%s' "$out" | grep -qi 'refuses\|REFUSE'; then k=2; seen="${seen}R"
        elif [ $rc -eq 139 ] || [ $rc -eq 134 ];              then k=3; seen="${seen}C"
        elif [ $rc -ne 0 ];                                    then k=1; seen="${seen}o"
        else                                                        k=0; seen="${seen}."; fi
        [ $k -gt $worst ] && worst=$k
    done
    flap=""; [ "$(printf '%s' "$seen" | grep -o . | sort -u | tr -d '\n' | wc -c)" -gt 1 ] && flap="!"
    case $worst in
      3) segv=$((segv+1));   segv_l="$segv_l $b[$seen]$flap" ;;
      2) refuse=$((refuse+1)); refuse_l="$refuse_l $b[$seen]$flap" ;;
      1) other=$((other+1));  other_l="$other_l $b[$seen]$flap" ;;
      0) clean=$((clean+1))
         # rc=0 on every rep. Now ask the STRONGER question the board is read as answering: did it print its N answers?
         if why=$(loop_check scrip "$D/$b.stdout" "$(cat "$D/$b.n" 2>/dev/null)" "$BENCH/$b.ref" 2>/dev/null)
         then clean_graded=$((clean_graded+1)); else ungraded_l="$ungraded_l $b($why)"; fi ;;
    esac
done
[ "$n" -gt 0 ] || { echo "⛔ REFUSED (rc=2): zero kernels generated -- an empty board is not a green board"; exit 2; }
echo "van Roy Prolog acceptance ($n generated counted kernels, mode 3, worst-of-$REPS): CLEAN=$clean (floor $CLEAN_FLOOR) · REFUSE=$refuse · CRASH=$segv · other=$other"
echo "  [] shows the per-rep outcome string (. clean, R refuse, C crash, o other); a trailing ! marks a kernel that FLIPPED between reps -- 11 of 21 do so on an unchanged binary."
[ -n "$refuse_l" ] && echo "  REFUSE:$refuse_l"
[ -n "$segv_l" ]   && echo "  CRASH :$segv_l"
[ -n "$other_l" ]  && echo "  other :$other_l"
echo "  measured at $(perf_load_stamp) -- ⛔ this board's classification moves with machine load while the Prolog heap leak stands (89.5 kB/iteration, dead linear): a budget-driven N crosses the threshold on a FAST box and stays under it on a LOADED one. Witness .github/probes/prolog-heap-leak-2026-09-13/, routed to hq_V/cto."
echo "  CLEAN_GRADED=$clean_graded of CLEAN=$clean -- ⭐ REPORTED, BLOCKING NOTHING (see the header): CLEAN means rc=0, CLEAN_GRADED additionally means the loop printed its N answers."
[ -n "$ungraded_l" ] && echo "  ⛔ rc=0 BUT NOT N ANSWERS:$ungraded_l"
[ "$clean_graded" -eq "$clean" ] || echo "  ⛔ $((clean - clean_graded)) kernel(s) above are counted CLEAN on exit status alone. That is the pass criterion being weaker than the claim; it is named here rather than cashed as a verdict."
F=0
[ "$refuse" -eq 0 ] || { echo "  ⛔ REFUSE=$refuse, must be 0"; F=1; }
[ "$segv"   -eq 0 ] || { echo "  ⛔ CRASH=$segv, must be 0 -- a refusal converted into a crash is a REGRESSION, not progress"; F=1; }
[ "$clean" -ge "$CLEAN_FLOOR" ] || { echo "  ⛔ CLEAN=$clean fell below the pinned floor $CLEAN_FLOOR -- kernels that passed no longer do"; F=1; }
[ $F -eq 0 ] && { echo "PASS: REFUSE 0, CRASH 0, CLEAN $clean >= $CLEAN_FLOOR"; exit 0; }
echo "GATE FAIL(1) [vanroy_prolog_acceptance]"
exit 1
