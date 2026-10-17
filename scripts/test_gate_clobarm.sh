#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_clobarm.sh -- s130 LEAF-SUSPENSION FRAME SLOT gate (GOAL-SNOBOL4-100 R-0 class).
# Runs the clobarm suite in BOTH modes against the checked-in .ref oracle, under whatever
# SCRIP_CHOICE_RBP the caller sets, and prints one PASS/FAIL row per program plus a tally.
# ⭐ RE-POINTED 2026-08-29 (seat07, corpus-crosscheck-probe-total-conversion clause 3): corpus/probe/clobarm/
# is gone -- converted to corpus/tests/snobol4/probe/clobarm.{sno,ref} (corpus-suites-consolidation format,
# byte-equal-validated both directions, both modes, all three SCRIP_CHOICE_RBP arm states before the loose
# files were deleted -- see tests/snobol4/probe/clobarm.README.md and FINDING-2026-08-29-seat07-s129-blob-
# leaf-cell-corruption-is-resolved-clobarm-5-of-5.md: the s129 corruption this gate exists to catch is now
# FIXED, all 5 witnesses pass in every arm). Same idiom as test_gate_fz_release.sh / probe_leafsib_measure.sh's
# re-points: extract every entry via corpus_suite_harness.py (the ONE parsing authority) into a scratch dir,
# then use that exactly as the old loose-file DIR -- the per-witness loop below is otherwise unchanged.
# An explicit DIR override (a caller's own standalone witness dir) is used AS-IS, exactly as before --
# extraction only runs on the default path, so override semantics are unchanged.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
RT=${RT:-$S4E/SCRIP/out/libscrip_rt.so}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0; fail=0
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "${DIR:-}" ]; then
    # ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): clobarm.{sno,ref}
    # (itself a 2026-08-29 re-point onto the per-family suite pair) was absorbed into THE ONE FLAT
    # RUNGS and deleted; lib_rungs_extract.sh materializes the "probe_clobarm" family's origins
    # back into a loose-file dir, same idiom this file's own header already documents.
    RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$HERE/lib_rungs_extract.sh"
    DIR="$WORK/clobarm_src"; mkdir -p "$DIR"
    rungs_extract_family probe_clobarm "$DIR" 2>/dev/null
fi
[ -n "$(ls -A "$DIR" 2>/dev/null)" ] || { echo "⛔ REFUSED-TO-GRADE no $DIR (suite missing or extraction failed)"; exit 2; }
for f in "$DIR"/*.sno; do
  b=$(basename "$f" .sno); ref=$(cat "$DIR/$b.ref" 2>/dev/null)
  m3=$(timeout -k 5 15 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); r3=$?
  s=/tmp/clobarm_$b.s; o=/tmp/clobarm_$b.bin; m4=""; r4=1
  if timeout -k 5 15 "$SCRIP" --compile "$f" > "$s" 2>/dev/null; then
    if gcc -no-pie -o "$o" "$s" "$RT" > /dev/null 2>&1; then
      m4=$(timeout -k 5 15 "$o" < /dev/null 2>/dev/null); r4=$?
    fi
  fi
  v3=FAIL; v4=FAIL
  [ "$m3" = "$ref" ] && v3=PASS
  [ "$m4" = "$ref" ] && v4=PASS
  if [ "$v3" = PASS ] && [ "$v4" = PASS ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
  printf "%-34s m3=%-4s rc=%-4s m4=%-4s rc=%-4s got3=[%s]\n" "$b" "$v3" "$r3" "$v4" "$r4" "$(echo "$m3" | head -1)"
done
echo "clobarm: PASS=$pass FAIL=$fail (both modes must match .ref)"
[ "$fail" -eq 0 ]
