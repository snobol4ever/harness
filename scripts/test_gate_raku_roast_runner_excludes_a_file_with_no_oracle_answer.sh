#!/usr/bin/env bash
# test_gate_raku_roast_runner_excludes_a_file_with_no_oracle_answer.sh -- A ROAST FILE RAKUDO ITSELF REFUSES LEAVES THE DENOMINATOR
# (CEO-1696; hq_raku's parse-only census, CEO-1713): raku_roast_scoreboard.sh --run reads the package's EXCLUDED.tsv beside its ALL.csv
# through the ONE reader (lib_inventory.sh inventory_excluded_names); a named file is never graded, writes no progress row, and is
# counted as excluded= on the board line and --excluded on the row. A malformed row refuses rc 2.
# FIXTURE (mktemp, outside corpus/, CEO-547; the shape of test_gate_raku_roast_runner_leaves_the_checkout_clean.sh): three one-line TAP
# files, run with --run --limit (non-publishing: no score row), the progress rows into a scratch table.
# ARMS: (1) with S99-fixture/refused named: the board reads total=2 excluded=1 and the scratch progress table holds no row for it
#       (2) CONTROL without EXCLUDED.tsv: total=3 excluded=0 and refused has its rows -- the exclusion is what moved it
#       (3) a row whose class is not in the vocabulary refuses rc 2 before grading
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; BOARD="$HERE/raku_roast_scoreboard.sh"
[ -f "$BOARD" ] || { echo "GATE UNPROVEN(2): missing $BOARD"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE UNPROVEN(2): no $ROOT/scrip (make first)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_raku_roast_runner_excludes_a_file_with_no_oracle_answer "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
checks=0; fails=0; ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
mkdir -p "$W/roast/S99-fixture" "$W/pkg"
for t in plain1 plain2 refused; do printf 'use Test;\nplan 1;\nok 1, "%s";\n' "$t" > "$W/roast/S99-fixture/$t.t"; done
printf '# fixture manifest\nS99-fixture/plain1.t\nS99-fixture/plain2.t\nS99-fixture/refused.t\n' > "$W/manifest"
{ printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n'
  i=0; for t in plain1 plain2 refused; do i=$((i+1)); printf '%d,S99-fixture/%s,roast__S99-fixture/%s,roast,3,0,0,131072,4096,,\n' "$i" "$t" "$t"; done; } > "$W/pkg/ALL.csv"
EV='a fixture row: rakudo-local raku -c refuses this file, so it has no oracle answer (gate fixture)'
run() { : > "$W/progress.tsv"; (cd "$ROOT" && RAKU_ROAST_TREE="$W/roast" RAKU_ROAST_MANIFEST="$W/manifest" RAKU_ROAST_DCSV="$W/pkg/ALL.csv" \
        S4E_PROGRESS_DB="$W/progress.tsv" S4E_SCORE_NO_WRITE="gate test_gate_raku_roast_runner_excludes_a_file_with_no_oracle_answer" \
        timeout -k 5 300 bash "$BOARD" --run --limit 3 > "$W/out" 2>&1); echo $?; }
board() { grep -m1 '^ROAST_SUITE_BOARD ' "$W/out"; }
rows_for() { grep -c "S99-fixture/$1" "$W/progress.tsv" 2>/dev/null; }
echo "=== gate: the Roast runner excludes a file with no oracle answer (CEO-1696) ==="
printf 'S99-fixture/refused\tNO_ORACLE_ANSWER\t%s\n' "$EV" > "$W/pkg/EXCLUDED.tsv"
rc=$(run); b="$(board)"
[ "$rc" -le 1 ] && grep -q ' total=2 ' <<<"$b" && grep -q ' excluded=1 ' <<<"$b" && [ "$(rows_for refused)" = 0 ] && [ "$(rows_for plain1)" -gt 0 ] \
  && ck ok "(1) refused is excluded: total=2 excluded=1, no progress row for it, plain1 graded" \
  || ck no "(1) rc=$rc board [$b] refused rows=$(rows_for refused) plain1 rows=$(rows_for plain1): $(tail -2 "$W/out" | tr '\n' ' ' | cut -c1-200)"
rm -f -- "$W/pkg/EXCLUDED.tsv"; rc=$(run); b="$(board)"
grep -q ' total=3 ' <<<"$b" && grep -q ' excluded=0 ' <<<"$b" && [ "$(rows_for refused)" -gt 0 ] \
  && ck ok "(2) CONTROL without EXCLUDED.tsv: total=3 excluded=0, refused graded" || ck no "(2) control: rc=$rc board [$b] refused rows=$(rows_for refused)"
printf 'S99-fixture/refused\tNOT_A_CLASS\t%s\n' "$EV" > "$W/pkg/EXCLUDED.tsv"; rc=$(run)
[ "$rc" = 2 ] && ck ok "(3) an unknown class refuses rc 2" || ck no "(3) unknown class: rc=$rc $(grep -m1 -E 'REFUS|MALFORMED' "$W/out" | cut -c1-150)"
echo "population: 3 fixture files, $checks arm(s), $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [raku_roast_runner_excludes_a_file_with_no_oracle_answer]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [raku_roast_runner_excludes_a_file_with_no_oracle_answer]: $fails of $checks arms FAIL"; exit 1
