#!/usr/bin/env bash
# test_census_m3_m4_divergence.sh — per-program MODE-3 vs MODE-4 divergence census.
#
# WHY THIS EXISTS (s32): the five EARN-0 pending W-pins were specified in s30, re-stated in s31,
# and never measured in mode 4.  W5 SEGVs in m4 while green in m3.  Nothing in the tree reports a
# per-program m3-vs-m4 delta, because run_suite.sh MODE=compile returns EMPTY in-container
# (BOARD B-0) — so an m4-only crash class survived two sessions of specification.
# GOAL-MODE34-IDENTICAL says the two modes must be 1:1.  This measures that, directly.
#
# ⛔ THE PIPE TRAP — READ BEFORE EDITING.  `out=$(prog | head -1); rc=$?` sets rc from *head*,
# which is ALWAYS 0, so every SIGSEGV reads as success.  A first cut of this census did exactly
# that and reported m4 SEGV=0 over a corpus whose true count was 82.  Capture the status with NO
# PIPE, then trim.  Any edit that reintroduces a pipe on the measured command voids the instrument.
#
# Usage:  bash ../harness/scripts/test_census_m3_m4_divergence.sh [DIR] [OUT.tsv]
#   DIR defaults to corpus/crosscheck/patterns.  Emits TSV: name m3 m4 rc3 rc4
# Exit 0 always — this is an instrument, not a gate.  BOARD sets the floors.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SC="${SC:-$S4E/SCRIP}"
OUT="${2:-/tmp/cen_m34.tsv}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
[ -x "$SC/scrip" ] || { echo "no $SC/scrip — build first"; exit 0; }
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): crosscheck/patterns/
# is gone -- absorbed into THE ONE FLAT RUNGS. An explicit DIR arg ($1) is honored as-is; the
# default now materializes the "crosscheck_patterns" family via lib_rungs_extract.sh.
if [ -n "${1:-}" ]; then
  D="$1"
else
  RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$SC/../harness/scripts/lib_rungs_extract.sh"
  D="$W/crosscheck_patterns_src"; mkdir -p "$D"
  rungs_extract_family crosscheck_patterns "$D" 2>/dev/null
fi
: > "$OUT"
tot=0; agree=0; div=0; s3=0; s4=0; h3=0; h4=0; bf=0; only4=0
for f in "$D"/*.sno; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .sno)"; tot=$((tot+1))
    o3="$(cd "$SC" && timeout -k 5 15 ./scrip --run "$f" < /dev/null 2>/dev/null)"; r3=$?
    m3="$(printf '%s' "$o3" | head -1)"
    [ $r3 -eq 139 ] && m3="<SEGV>"; [ $r3 -eq 124 ] && m3="<HANG>"
    if (cd "$SC" && timeout -k 5 25 ./scrip --compile "$f" > "$W/$n.s" 2>/dev/null) \
       && gcc -no-pie "$W/$n.s" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$W/$n.prog" 2>/dev/null; then
        o4="$(timeout -k 5 15 "$W/$n.prog" < /dev/null 2>/dev/null)"; r4=$?
        m4="$(printf '%s' "$o4" | head -1)"
        [ $r4 -eq 139 ] && m4="<SEGV>"; [ $r4 -eq 124 ] && m4="<HANG>"
    else m4="<BUILDFAIL>"; r4=-1; bf=$((bf+1)); fi
    [ $r3 -eq 139 ] && s3=$((s3+1)); [ $r4 -eq 139 ] && s4=$((s4+1))
    [ $r3 -eq 124 ] && h3=$((h3+1)); [ $r4 -eq 124 ] && h4=$((h4+1))
    [ $r4 -eq 139 ] && [ $r3 -eq 0 ] && only4=$((only4+1))
    if [ "$m3" = "$m4" ]; then agree=$((agree+1)); else div=$((div+1)); fi
    printf '%s\t%s\t%s\t%d\t%d\n' "$n" "$m3" "$m4" "$r3" "$r4" >> "$OUT"
done
echo "CENSUS m3-vs-m4  DIR=$D"
echo "  TOTAL=$tot  AGREE=$agree  DIVERGE=$div"
echo "  m3: SEGV=$s3 HANG=$h3"
echo "  m4: SEGV=$s4 HANG=$h4 BUILDFAIL=$bf"
echo "  PURE m4 CRASH CLASS (m3 rc=0, m4 SEGV) = $only4"
echo "  rows -> $OUT"
exit 0
