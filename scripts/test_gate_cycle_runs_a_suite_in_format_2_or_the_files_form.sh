#!/usr/bin/env bash
# test_gate_cycle_runs_a_suite_in_format_2_or_the_files_form.sh -- THE CYCLE RUNS A SUITE IN ANY OF THE THREE FORMS THE ONE LAUNCH READS (row
# cycle-a-suite-in-format-2-or-the-files-form-is-run-not-refused-sno-rungs-refused-three-laps; the coo 2026-11-10: the SNOBOL4 master, in format 2,
# had its 24 cells logged rc=2 secs=0 for three laps, and aisnobol and dotnet, in the files form, for one, because run_cell tested for the container).
# A scratch home holds a planted runner table of four one-cell suites and stand-ins for every outside call the cycle makes (sync, make, budget, run
# slot, the harness, the score row); the real harness/scripts/s4e_cycle.sh beside this gate runs one lap over it with every store scratch:
#   c1  the container: ALL.sno and ALL.ref
#   m1  format 2 of a test folder: MULTI-LINERS.md and ALL.csv, no ALL.sno (CIO-24)
#   f1  the files form of a package: ALL.csv with a path column, no ALL.sno (CIO-59, CIO-113)
#   x1  nothing but its partition: no suite on disk
#   r1  the files form, and its CONTRACT.tsv names the road run-files (the package switch, run-switches step 12; the row
#       cycle-a-package-whose-contract-names-the-run-files-road-is-run-by-the-package-switch-fpc-first)
# GREEN: the stand-in harness is launched for c1, m1, f1 and r1 (each CELL line rc=0) and never for x1 (its CELL line rc=2); r1's launch carries
# --run-files and f1's, in the same form with no such row, does not (road=flagged on the board line). No live store is read or
# AND A TEST REQUEST WAITS FOR ITS ENTRIES (row cycle-a-test-request-for-an-entry-the-cycles-tree-does-not-hold-yet-waits-for-the-next-sync): the cycle's own
# request_ready, taken from the script, is asked three things over the planted table: a request filed after the lap's sync that names an entry the tree does not hold
# waits (rc 1); one that names c1_e is ready (rc 0); the first, once a sync is newer than it, is ready too (it is served and refuses as written). request=waits on
# the board line; a script with no such test spends the request (request=spent).
# written: the progress dir, the request folder, the postoffice and the results table are all scratch. rc 0 GREEN, rc 1 RED, rc 2 could not measure.
set -u
G=test_gate_cycle_runs_a_suite_in_format_2_or_the_files_form
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYC="$HERE/s4e_cycle.sh"
[ -f "$CYC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $CYC"; exit 2; }
w="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-gate}-cycleforms.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
cpid=""
trap '[ -n "$cpid" ] && kill -- -"$cpid" 2>/dev/null; rm -rf "$w"' EXIT
H="$w/home"; mkdir -p "$H/harness/scripts" "$H/SCRIP" "$H/.github" "$w/prog" "$w/tmp" "$w/rq" "$w/po"; : > "$w/results.tsv"
printf 'all:\n\t@true\n' > "$H/SCRIP/Makefile"
: > "$H/harness/scripts/SUITE_RUNNERS.tsv"
for s in c1 m1 f1 x1 r1; do
    mkdir -p "$H/pkg/$s"; printf 'entry\tpart\n%s_e\tcore\n' "$s" > "$H/pkg/$s/PARTITION.tsv"
    printf '%s\tpkg\tsnobol4\tcorpus_suite_harness.py\tpkg/%s\n' "$s" "$s" >> "$H/harness/scripts/SUITE_RUNNERS.tsv"
done
: > "$H/pkg/c1/ALL.sno"; : > "$H/pkg/c1/ALL.ref"
printf '# planted\n' > "$H/pkg/m1/MULTI-LINERS.md"; printf 'entry\nm1_e\n' > "$H/pkg/m1/ALL.csv"
printf 'entry,path\nf1_e,f1_e.sno\n' > "$H/pkg/f1/ALL.csv"; printf ' OUTPUT = 1\nEND\n' > "$H/pkg/f1/f1_e.sno"
printf 'entry,path\nr1_e,r1_e.sno\n' > "$H/pkg/r1/ALL.csv"; printf ' OUTPUT = 1\nEND\n' > "$H/pkg/r1/r1_e.sno"
printf '# planted\nroad\trun-files\tread equal on both roads (planted)\n' > "$H/pkg/r1/CONTRACT.tsv"
printf '#!/usr/bin/env bash\nexit 0\n' > "$H/harness/scripts/util_sync_root.sh"
printf '#!/usr/bin/env bash\nexec "$@"\n' > "$H/harness/scripts/util_run_slot.sh"
printf 'import sys\nprint("BUDGET ttr_s=120")\n' > "$H/harness/scripts/util_grade_job.py"
printf 'import sys\n' > "$H/harness/scripts/util_score_row.py"
printf 'import sys\nopen(%s, "a").write(" ".join(sys.argv[1:]) + "\\n")\nsys.exit(0)\n' "'$w/launched'" > "$H/harness/scripts/corpus_suite_harness.py"
setsid env S4E_HOME="$H" S4E_CYCLE_PROG="$w/prog" S4E_CYCLE_TMP="$w/tmp" S4E_CYCLE_WIDTH=2 S4E_TEST_REQUEST_DIR="$w/rq" S4E_POST="$w/po" S4E_RESULTS="$w/results.tsv" bash "$CYC" > "$w/cycle.out" 2>&1 < /dev/null & cpid=$!
n=0; for i in $(seq 1 90); do n=$(grep -c ' CELL lap=1 ' "$w/prog/CYCLE.log" 2>/dev/null); [ "${n:-0}" -ge 5 ] && break; sleep 0.5; done
kill -- -"$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null; cpid=""
grep -q ' LAP 1 start ' "$w/prog/CYCLE.log" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the scratch cycle never started its lap: $(head -c 300 "$w/cycle.out" "$w/prog/CYCLE.log" 2>/dev/null | tr '\n' ' ')"; exit 2; }
[ "${n:-0}" -ge 5 ] || { echo "CYCLE_FORMS_BOARD cells=${n:-0}/5"; echo "⛔ GATE REFUSE(2) [$G]: only ${n:-0} of 5 CELL lines in 45 s"; exit 2; }
rc_of() { grep ' CELL lap=1 ' "$w/prog/CYCLE.log" | sed -n "s/.* CELL lap=1 [0-9]*\/[0-9]* $1 [^ ]* rc=\([0-9]*\) .*/\1/p" | head -1; }
ran() { grep -c "/pkg/$1/" "$w/launched" 2>/dev/null; }
req=spent; REQF="$(sed -n '/^request_ready() {/,/^}/p' "$CYC")"
if [ -n "$REQF" ]; then
    q="$w/q"; mkdir -p "$q/cycle" "$q/rq"
    printf 'seat=gate\nsuite=c1\nentries=not_in_this_tree\n' > "$q/rq/a.req"; printf 'seat=gate\nsuite=c1\nentries=c1_e\n' > "$q/rq/b.req"
    : > "$q/cycle/lap.sync"; touch -d 2000-01-01 "$q/cycle/lap.sync"
    ask() { RUNNERS="$H/harness/scripts/SUITE_RUNNERS.tsv" S4E="$H" TMPDIR="$q" bash -c "$REQF"'; request_ready "$1"; echo $?' _ "$1" 2> /dev/null; }
    q1="$(ask "$q/rq/a.req")"; q2="$(ask "$q/rq/b.req")"
    touch -d 2000-01-01 "$q/rq/a.req"; touch "$q/cycle/lap.sync"; q3="$(ask "$q/rq/a.req")"
    [ "$q1" = 1 ] && [ "$q2" = 0 ] && [ "$q3" = 0 ] && req=waits
fi
c=$(rc_of c1); m=$(rc_of m1); f=$(rc_of f1); x=$(rc_of x1); r=$(rc_of r1)
road=unflagged; grep "/pkg/r1/" "$w/launched" 2>/dev/null | grep -q -- ' --run-files' && ! grep "/pkg/f1/" "$w/launched" 2>/dev/null | grep -q -- ' --run-files' && road=flagged
echo "CYCLE_FORMS_BOARD cells=5 container=rc${c:-?}/launched$(ran c1) format2=rc${m:-?}/launched$(ran m1) files_form=rc${f:-?}/launched$(ran f1) nothing=rc${x:-?}/launched$(ran x1) contract_road=rc${r:-?}/launched$(ran r1) road=$road request=$req (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$c" = 0 ] && [ "$(ran c1)" -ge 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: the control did not run: the container suite read rc=${c:-?}"; exit 2; }
[ "$m" = 0 ] && [ "$f" = 0 ] && [ "$(ran m1)" -ge 1 ] && [ "$(ran f1)" -ge 1 ] && [ "$x" = 2 ] && [ "$(ran x1)" = 0 ] && [ "$r" = 0 ] && [ "$road" = flagged ] && [ "$req" = waits ] \
    && { echo "GATE OK [$G]: the cycle launched the container, format 2 and the files form, and refused the suite that is not on disk"; exit 0; }
echo "⛔ GATE FAIL(1) [$G]: format 2 rc=${m:-?}, the files form rc=${f:-?} (want 0 and a launch each); nothing on disk rc=${x:-?} (want 2 and no launch); the contract's road rc=${r:-?} road=$road (want 0 and flagged); request=$req (want waits: a request newer than the sync that names a missing entry waits, a ready one and one older than the sync do not)"; exit 1
