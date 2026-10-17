#!/bin/bash
# build_bench_oracle_from_pristine.sh -- REPRODUCE the benchmark oracle from version control.
#
# ⛔ WHY THIS EXISTS (Lon s259, in-chat: "Why are we not using simple clones?").  MEASURED answer: we were not.
# /home/resources/spitbol-bench-oracle was a clone of upstream 4fe74db with TWO UNCOMMITTED WORKING-TREE
# MODIFICATIONS -- osint/systm.c (45 lines, the s249 NS-TIME CLOCK_MONOTONIC fix) and sbl.min (374 lines, the
# uppercase-keyword/datatype table conversion + flc/flstg fold reversal so `-bf` accepts SCRIP-convention
# uppercase keywords).  No commit, no branch, no stash. EVERY SCRIP-vs-SPITBOL number this project has ever
# published depended on a dirty directory that existed on ONE machine and was in NO repository.
# The diff is now versioned at .github/wip-patches/spitbol-bench-oracle-4fe74db.patch and this script rebuilds
# the oracle from a SIMPLE CLONE plus that patch, which is what Lon asked for.
set -eu
BASE="${BASE:-/tmp/bench-oracle-build}"
PATCH="${PATCH:-$(cd "$(dirname "$0")/../../.github" && pwd)/wip-patches/spitbol-bench-oracle-4fe74db.patch}"
[ -f "$PATCH" ] || { echo "⛔ patch not found: $PATCH"; exit 2; }
rm -rf "$BASE"; mkdir -p "$BASE"
echo "1/4 simple clone of upstream"; git clone -q https://github.com/spitbol/spitbol "$BASE/spitbol"
cd "$BASE/spitbol"; git checkout -q 4fe74db
echo "2/4 apply the versioned patch"; git apply --check "$PATCH" && git apply "$PATCH"
echo "3/4 build (BASEBOL = the tree's own bin/sbl bootstrap)"; make spitbol >/dev/null 2>&1 || { echo "⛔ build failed"; exit 1; }
echo "4/4 verify the product accepts the MANDATORY -bf"
printf "        OUTPUT = 'ok'\nEND\n" > "$BASE/smoke.sno"
out="$(./sbl -bf "$BASE/smoke.sno" </dev/null 2>&1 | tr -d '[:space:]')"
[ "$out" = "ok" ] || { echo "⛔ REBUILD REJECTS -bf -- it is the bootstrap trap, not an oracle: '$out'"; exit 1; }
echo "✅ reproduced at $BASE/spitbol/sbl  (md5 $(md5sum < ./sbl | cut -d' ' -f1))"
echo "   compare against the live oracle: md5sum /home/resources/spitbol-bench-oracle/sbl"
