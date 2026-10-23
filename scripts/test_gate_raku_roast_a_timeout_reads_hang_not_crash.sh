#!/usr/bin/env bash
# test_gate_raku_roast_a_timeout_reads_hang_not_crash.sh -- THE ROAST RUNNER WRITES A TIMEOUT AS HANG, NEVER CRASH (coo 2026-10-23).
# raku_roast_scoreboard.sh's classify() files rc 124 under CRASH (its board line's bucket is CRASH / TIMEOUT) and roast_outcome wrote that
# CRASH into the progress DB, so ten S15-normalization files that ran past the 30 s m3 cap under the verifier pool's load read CRASH m3 on
# ab0adf375 and went to the ceo as crashes (COO-412); nfc-9 runs 22.8 s alone on 26e79fe3e and dies by no signal. The verdict ladder's HANG
# is the timeout's verdict. The gate grades on its own fixture tree (CEO-547): a spinning .t and a passing control, the runner pointed at
# them by RAKU_ROAST_TREE/MANIFEST/DCSV, the progress DB and the score row redirected, the retry off (S4E_TIMEOUT_RETRY=0) so the m3 cap is
# 5 s and the m4 run's 10 s. RED BEFORE THE CURE: on harness bf76cbe the spin's two rows read CRASH.
# EXIT: 0 every arm holds · 1 an arm is red · 2 REFUSED -- cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP -- this gate measures SCRIP"; exit 2; }
BOARD="$HERE/raku_roast_scoreboard.sh"
[ -f "$BOARD" ] || { echo "GATE UNPROVEN(2): missing $BOARD"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE UNPROVEN(2): no $ROOT/scrip (make first)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_raku_roast_a_timeout_reads_hang_not_crash "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
checks=0; fails=0; ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
mkdir -p "$W/roast/S99-fixture" "$W/pkg"
printf 'use Test;\nplan 1;\nok 1, "plain1";\n' > "$W/roast/S99-fixture/plain1.t"
printf 'use Test;\nplan 1;\nmy $i = 0;\nloop { $i++ }\nok 1, "never";\n' > "$W/roast/S99-fixture/spin.t"
printf '# fixture manifest\nS99-fixture/plain1.t\nS99-fixture/spin.t\n' > "$W/manifest"
{ printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n'
  i=0; for t in plain1 spin; do i=$((i+1)); printf '%d,S99-fixture/%s,roast__S99-fixture/%s,roast,3,0,0,131072,4096,,\n' "$i" "$t" "$t"; done; } > "$W/pkg/ALL.csv"
: > "$W/progress.tsv"
(cd "$ROOT" && RAKU_ROAST_TREE="$W/roast" RAKU_ROAST_MANIFEST="$W/manifest" RAKU_ROAST_DCSV="$W/pkg/ALL.csv" S4E_TIMEOUT_RETRY=0 \
  S4E_PROGRESS_DB="$W/progress.tsv" S4E_SCORE_NO_WRITE="gate test_gate_raku_roast_a_timeout_reads_hang_not_crash" \
  timeout -k 5 300 bash "$BOARD" --run --limit 2 > "$W/out" 2>&1); rc=$?
outcome() { awk -F'\t' -v p="S99-fixture/$1" -v m="$2" '$8==p && $9==m {o=$10} END {print o}' "$W/progress.tsv"; }
echo "=== gate: the Roast runner writes a timeout as HANG, never CRASH ==="
[ "$rc" -le 1 ] || { echo "GATE UNPROVEN(2): the runner returned rc=$rc: $(tail -3 "$W/out" | tr '\n' ' ' | cut -c1-300)"; exit 2; }
[ "$(outcome plain1 m3)" = PASS ] && ck ok "(1) CONTROL plain1 m3 PASS -- the fixture tree grades" || ck no "(1) control plain1 m3 reads '$(outcome plain1 m3)': $(tail -2 "$W/out" | tr '\n' ' ' | cut -c1-200)"
[ "$(outcome spin m3)" = HANG ] && ck ok "(2) spin m3 HANG (rc 124 at the 5 s cap)" || ck no "(2) spin m3 reads '$(outcome spin m3)', not HANG"
o4="$(outcome spin m4)"; { [ "$o4" = HANG ] || [ "$o4" = REJECT ]; } && ck ok "(3) spin m4 $o4 (HANG at its 10 s cap, or REJECT if mode 4 refuses the file) -- never CRASH" || ck no "(3) spin m4 reads '$o4'"
echo "population: 2 fixture files, $checks arm(s), $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [raku_roast_a_timeout_reads_hang_not_crash]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [raku_roast_a_timeout_reads_hang_not_crash]: $fails of $checks arms FAIL"; exit 1
