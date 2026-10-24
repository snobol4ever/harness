#!/usr/bin/env bash
# util_precarve_whack_probe.sh -- PROBE A PRE-CARVE BY WHACKING IT (ceo CEO-1940/1941; Lon 2026-10-24, verbatim: "The strategy to do so is to WHACK each
# pre-carve one at a time and see what breaks. Most will work since BB allocate their own memory." · "whacking the pre-alloc will SCREAM what's wrong." ·
# "Take a list of those spots in the code that do a carve, and one by one mark them off by whacking it and doing a little testing.").
#
#   util_precarve_whack_probe.sh <site>...            from any cwd; the sites are util_precarve_whack_patches.py --list
#   PROBE_TEST='<command run from SCRIP>'             the little test; default `bash ../harness/scripts/test_fleet_smoke.sh` (the eight smokes). A site
#                                                     that reads green on the smokes is UNEXERCISED, not dead: run it again with the feature handful
#                                                     (`bash ../harness/scripts/test_feature_reps.sh <lang> <feature>`) or the cores of the languages
#                                                     that reach the site (`python3 ../harness/scripts/corpus_suite_harness.py run ... --partition core`).
#   PROBE_LOG=<tsv>                                   default /home/resources/progress/PRECARVE-PROBE.tsv (when, seat, scrip, site, test, rc, summary)
#
# Per site: refuse unless the files it touches are clean in git; apply the whack; make -j8; run the test; append one record; `git checkout` the files.
# After the last site: make -j8 on the restored tree. Sequential, one probe at a time, every child under an 8 GB address space (a 2 GB cap aborts
# bb_pool_init's mmap; the 09:42 oomd kill of 2026-10-24 is why there is a bound at all). It never commits: a whack that reads green on the right test
# becomes a LANDING by the seat's own hand, with the smokes and the handful before the push (CEO-1928) and its row marked in PRECARVE-WHACK-LIST.md.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="$HERE/../../SCRIP"; PAT="$HERE/util_precarve_whack_patches.py"
LOG="${PROBE_LOG:-/home/resources/progress/PRECARVE-PROBE.tsv}"; TEST="${PROBE_TEST:-bash ../harness/scripts/test_fleet_smoke.sh}"
SEAT="$(cat "$HERE/../../HQ" 2>/dev/null || basename "$(cd "$HERE/../.." && pwd)")"
[ $# -ge 1 ] || { echo "usage: util_precarve_whack_probe.sh <site>...   (python3 $PAT --list names the sites)"; exit 2; }
cd "$SCRIP" || { echo "REFUSE(2): no SCRIP at $SCRIP"; exit 2; }
ulimit -v 8000000
[ -s "$LOG" ] || printf 'when\tseat\tscrip\tsite\ttest\trc\tsummary\n' >> "$LOG"
SCRATCH="$(mktemp -d /tmp/precarve-probe.XXXXXX)"
for site in "$@"; do
  echo "=== $site $(date '+%H:%M:%S')"
  out="$(python3 "$PAT" "$site" 2>&1)"; prc=$?; echo "$out"
  files="$(printf '%s\n' "$out" | sed -n 's/^FILES //p')"
  if [ $prc -ne 0 ]; then printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%FT%T')" "$SEAT" "$(git rev-parse --short HEAD)" "$site" "$TEST" NOPATCH "$out" | tr -d '\r' >> "$LOG"; continue; fi
  if timeout 900 make -j8 > "$SCRATCH/$site.make.out" 2>&1; then brc=0; else brc=$?; fi
  if [ $brc -ne 0 ]; then printf '%s\t%s\t%s\t%s\t%s\tBUILD_FAIL\t%s\n' "$(date '+%FT%T')" "$SEAT" "$(git rev-parse --short HEAD)" "$site" "$TEST" "$(grep -m1 error "$SCRATCH/$site.make.out" | cut -c1-160)" >> "$LOG"; git checkout -q -- $files; continue; fi
  timeout 1800 bash -c "$TEST" > "$SCRATCH/$site.test.out" 2>&1; trc=$?
  summary="$(grep -E 'FLEET_SMOKE total|FEATURE_REPS|^SUITE|PASS=|pass=' "$SCRATCH/$site.test.out" | tail -3 | sed -E 's/[[:space:]]+/ /g' | tr '\n' ';' | cut -c1-300)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%FT%T')" "$SEAT" "$(git rev-parse --short HEAD)" "$site" "$TEST" "$trc" "${summary:-no summary line; see $SCRATCH/$site.test.out}" >> "$LOG"
  echo "rc=$trc $summary"
  git checkout -q -- $files
done
echo "=== restore build $(date '+%H:%M:%S')"; timeout 900 make -j8 > "$SCRATCH/restore.make.out" 2>&1; echo "restore make rc=$? dirty files: $(git status --short | wc -l); outputs in $SCRATCH"
