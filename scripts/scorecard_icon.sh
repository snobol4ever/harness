#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
# scorecard_icon.sh — THE Icon instrument (GOAL-ICON-100.md). Sibling of scorecard_snobol4.sh.
# Usage:
#   bash ../harness/scripts/scorecard_icon.sh run    [--suites a,b] [--out DIR]   # runs suites, writes "<pass> <total>" per suite file
#   bash ../harness/scripts/scorecard_icon.sh report [DIR]                        # weighted META = 100 * Σ(w·pass/total) / Σw  (suites present)
# WEIGHTS (Lon's knob — edit here, ONE authority):
#   rungs_m3 25 · rungs_m4 20 · rungs_m3_cells 10 · bench_correct 15 · smoke 10 · crosscheck 5 · gates 10   (Σ=95)
# Grading laws: XFAIL counts in the denominator (end state 293/0/0); bench graded by honest_icon_correctness.sh
# (IDENTICAL only — never rc/non-empty, the s164 rsg lesson); a missing suite file drops from BOTH sums and the
# report says PARTIAL. FALSIFIABILITY: report recomputes from files only — edit one file, META must move.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -uo pipefail
SD="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"; CORPUS="${CORPUS:-$S4E/corpus}"; ORACLE_BIN="${ORACLE_BIN:-$S4A/icon-build/bin}"
SUITES_ALL="rungs_m3 rungs_m3_cells rungs_m4 bench_correct smoke crosscheck gates"
w_of(){ case "$1" in rungs_m3) echo 25;; rungs_m4) echo 20;; rungs_m3_cells) echo 10;; bench_correct) echo 15;; smoke) echo 10;; crosscheck) echo 5;; gates) echo 10;; *) echo 0;; esac; }
parse_rungs(){ sed -n 's/.*PASS=\([0-9]*\) FAIL=\([0-9]*\) XFAIL=\([0-9]*\) TOTAL=\([0-9]*\).*/\1 \4/p' | tail -1; }
run_suite(){ local s="$1" out="$2" r=""
  case "$s" in
    rungs_m3)       r="$(cd "$SD" && bash ../harness/scripts/test_icon_all_rungs.sh 2>/dev/null | parse_rungs)";;
    rungs_m3_cells) r="$(cd "$SD" && SCRIP_ICN_CELLS=1 bash ../harness/scripts/test_icon_all_rungs.sh 2>/dev/null | parse_rungs)";;
    rungs_m4)       r="$(cd "$SD" && bash ../harness/scripts/test_icon_x64_all_rungs.sh --corpus "$CORPUS/icon" 2>/dev/null | parse_rungs)";;
    bench_correct)  local raw rc pc tc
                    # ⛔ row icon-board-timeout-scored-as-zero (hq_C find): `timeout 900` killing this suite used to
                    # collapse into "0 0" (awk's END block always prints something, even over zero input lines), which
                    # `run_suite`'s `[ -n "$r" ]` check cannot distinguish from a genuine 0-pass run -- a timeout was
                    # SCORED AS A FAILURE (0%) at weight 15 instead of reported as UNPROVEN, understating Icon META by
                    # ~13 points (69.0 vs the honest 82.0). lib_gate.sh's own law applies here even though this suite
                    # doesn't source it: zero-examined is indistinguishable from all-clean, so it is refused, not passed.
                    raw="$( { [ -d "$ORACLE_BIN" ] && export PATH="$ORACLE_BIN:$PATH"; cd "$SD" && SCRIPDIR="$SD" timeout -k 5 900 bash ../harness/scripts/honest_icon_correctness.sh; } 2>/dev/null )"; rc=$?  # timeout-retry: exempt -- a whole-script cap, not a graded unit
                    read -r pc tc <<< "$(printf '%s\n' "$raw" | awk -F'|' '/^[a-z0-9_]+ *\|/{t++; if ($0 ~ /IDENTICAL/) p++} END{print p+0, t+0}')"
                    if [ "$rc" -eq 124 ]; then r="UNPROVEN timeout(900s)_examined=${tc:-0}"
                    elif [ "${tc:-0}" -eq 0 ]; then r="UNPROVEN examined=0_rc=$rc"
                    else r="$pc $tc"; fi;;
    smoke)          r="$(cd "$SD" && timeout -k 5 600 bash ../harness/scripts/test_smoke_icon.sh 2>/dev/null | sed -n 's/.*PASS=\([0-9]*\) FAIL=\([0-9]*\) *\/ *\([0-9]*\).*/\1 \3/p' | awk '{p+=$1; t+=$2} END{print p+0, t+0}')";;  # timeout-retry: exempt -- a whole-script cap, not a graded unit
    crosscheck)     r="$(cd "$SD" && timeout -k 5 600 bash ../harness/scripts/test_crosscheck_icon.sh 2>/dev/null | sed -n 's/.*PASS=\([0-9]*\) FAIL=\([0-9]*\).*/\1 \2/p' | tail -1 | awk '{print $1, $1+$2}')";;  # timeout-retry: exempt -- a whole-script cap, not a graded unit
    gates)          local p=0 t=0 g; for g in no_stack one_reg_frame semicolon_required rbp_census_ratchet zk5_gva zcells_gva local_no_nv global_no_nv_m3 scan var; do t=$((t+1)); (cd "$SD" && timeout -k 5 240 bash "../harness/scripts/test_gate_icn_$g.sh" >/dev/null 2>&1) && p=$((p+1)); done; r="$p $t";;  # timeout-retry: exempt -- a gate's cap, not a graded unit
  esac
  [ -n "$r" ] && echo "$r" > "$out/$s" && echo "  $s: $r" || echo "  $s: NO RESULT (suite errored — file not written)"; }
cmd="${1:-report}"; shift || true
if [ "$cmd" = run ]; then
  OUT="$SD/test-results/scorecard-icon-$(date +%Y%m%d-%H%M%S)"; SEL="$SUITES_ALL"
  while [ $# -gt 0 ]; do case "$1" in --suites) SEL="$(echo "$2" | tr ',' ' ')"; shift 2;; --out) OUT="$2"; shift 2;; *) shift;; esac; done
  mkdir -p "$OUT"; echo "scorecard_icon run → $OUT"; for s in $SEL; do run_suite "$s" "$OUT"; done
  bash "$0" report "$OUT"
elif [ "$cmd" = report ]; then
  DIR="${1:-$(ls -dt "$SD"/test-results/scorecard-icon-* 2>/dev/null | head -1)}"
  [ -d "${DIR:-}" ] || { echo "no scorecard dir"; exit 1; }
  echo "=== ICON SCORECARD ($DIR) ==="; miss=0
  awk_in=""; for s in $SUITES_ALL; do
    if [ ! -f "$DIR/$s" ]; then printf "  %-15s MISSING\n" "$s"; miss=1; continue; fi
    read -r p t < "$DIR/$s"
    # ⛔ row icon-board-timeout-scored-as-zero: UNPROVEN (timeout or zero-examined) gets the SAME treatment as a
    # MISSING file -- named, excluded from Σw -- never folded in as a scored 0/t. Scoring "over MEASURED rows,
    # with unmeasured rows named and counted separately" per the row's own NEXT block, rather than a false zero.
    if [ "$p" = "UNPROVEN" ]; then
      w=$(w_of "$s"); printf "  %-15s UNPROVEN (%s)  w=%-3s -- excluded from META, NOT scored 0\n" "$s" "$t" "$w"; miss=1; continue
    fi
    w=$(w_of "$s"); printf "  %-15s %5s / %-5s  w=%-3s %6.1f%%\n" "$s" "$p" "$t" "$w" "$(awk -v p="$p" -v t="$t" 'BEGIN{print (t>0)?100*p/t:0}')"; awk_in="$awk_in$s $p $t $w\n"
  done
  printf "%b" "$awk_in" | awk '{n+=$4*(($3>0)?$2/$3:0); d+=$4} END{printf "META SCORE = %.1f  (Σw=%d%s)\n", (d>0)?100*n/d:0, d, ""}'
  # ⛔ drive-by, separately noted (not the row's own defect): without this, a fully-clean report (miss=0) exited 1 --
  # the FALSE test result of the line below, with no exit after it -- while a PARTIAL report exited 0. Backwards from
  # what any future caller wiring this into a gate would expect. lib_gate.sh's own convention (2=UNPROVEN, could not
  # fully examine) fits PARTIAL exactly better than 1=VIOLATION -- this script has no pass/fail bar to violate.
  if [ "$miss" = 1 ]; then echo "⚠ PARTIAL — one or more suites missing or UNPROVEN (excluded from Σw, never scored 0) in this run dir."; exit 2; fi
  exit 0
else echo "usage: scorecard_icon.sh run|report"; exit 2; fi
