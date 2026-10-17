#!/usr/bin/env bash
# test_gate_raku_roast_runner_leaves_the_checkout_clean.sh -- A ROAST CASE THAT WRITES A FILE WHERE IT STANDS WRITES IT
# IN A SCRATCH DIRECTORY, NEVER IN THE CHECKOUT THE RUNNER GRADES (coo 2026-10-09).
# MEASURED: pass 42 (SCRIP cfcfaf46d) ran raku_roast_scoreboard.sh --run with cwd = the checkout, and roast's IO tests wrote
# 16 files there (.tmp-test-file, temp-evalfile.*, io-native-descriptor-testfile, names holding a literal \0 ...). The runner's
# own row write then REFUSED the dirty tree ("SCRIP has uncommitted"), so a whole Roast run (96/1464 both modes) published no
# row -- and a dirty checkout makes every board after it grade a tree nobody can check out.
# THE FIXTURE (outside corpus, under mktemp): a two-file roast tree -- write.t spurts a file into its cwd and checks it is
# there; plain.t passes -- with its own manifest and attribute table, graded by the real runner in its NON-PUBLISHING mode
# (--limit), a scratch progress table, no score write.
#   ARM 1  the runner measures the fixture (its board line names 2 files)
#   ARM 2  write.t PASSES in m3: a case can still write where it stands -- it stands in its own scratch directory
#   ARM 3  the checkout gains NO file: git status --porcelain is the same before and after the run
# FAIL-ONCE: on the runner before incwd(), arm 3 reads the fixture's file in the checkout and reds (measured by hand on
# 3de1f00bb; this gate removes that file if it ever finds one, so a red run never leaves the checkout dirty).
# EXIT: 0 all arms pass · 1 an arm failed · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
BOARD="$HERE/raku_roast_scoreboard.sh"
[ -f "$BOARD" ] || { echo "GATE UNPROVEN(2): missing $BOARD"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE UNPROVEN(2): no $ROOT/scrip (make first)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_raku_roast_runner_leaves_the_checkout_clean "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { echo "GATE UNPROVEN(2): $ROOT is not a git checkout -- arm 3 reads its status"; exit 2; }
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }
DEBRIS="gate-roast-cwd-debris-$$.txt"
trap 'rm -rf "$W"; rm -f "$ROOT/$DEBRIS"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

mkdir -p "$W/roast/S99-fixture"
printf 'use Test;\nplan 1;\nspurt "%s", "x";\nok "%s".IO.e, "wrote a file where it stands";\n' "$DEBRIS" "$DEBRIS" > "$W/roast/S99-fixture/write.t"
printf 'use Test;\nplan 1;\nok 1, "plain";\n' > "$W/roast/S99-fixture/plain.t"
printf '# fixture manifest\nS99-fixture/plain.t\nS99-fixture/write.t\n' > "$W/manifest"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n' > "$W/ALL.csv"
printf '1,S99-fixture/plain,roast__S99-fixture/plain,roast,3,0,0,131072,4096,,\n2,S99-fixture/write,roast__S99-fixture/write,roast,4,0,0,131072,4096,,\n' >> "$W/ALL.csv"

before="$(git -C "$ROOT" status --porcelain 2>/dev/null)"
out="$(cd "$ROOT" && RAKU_ROAST_TREE="$W/roast" RAKU_ROAST_MANIFEST="$W/manifest" RAKU_ROAST_DCSV="$W/ALL.csv" \
       S4E_PROGRESS_DB="$W/progress.tsv" S4E_SCORE_NO_WRITE="gate test_gate_raku_roast_runner_leaves_the_checkout_clean" \
       timeout -k 5 300 bash "$BOARD" --run --limit 2 2>&1)"; rc=$?
after="$(git -C "$ROOT" status --porcelain 2>/dev/null)"

echo "=== gate: a roast case that writes where it stands never writes into the checkout ==="
if printf '%s\n' "$out" | grep -qE '^ROAST_SUITE_BOARD total=2 '; then ck ok "the runner measured the fixture (2 files, non-publishing)"
else echo "GATE UNPROVEN(2): the runner did not measure the fixture (rc=$rc): $(printf '%s\n' "$out" | grep -E 'REFUS|BLOCKED|⛔' | head -2 | tr '\n' ' ')"; exit 2; fi
if [ "$(awk -F'\t' '$8 ~ /write$/ && $9 == "m3" {print $10}' "$W/progress.tsv" 2>/dev/null | tail -1)" = PASS ]; then ck ok "write.t PASSES in m3: it wrote its file in its own scratch directory"
else ck no "write.t did not pass in m3: $(awk -F'\t' '$8 ~ /write$/ {print $9, $10}' "$W/progress.tsv" 2>/dev/null | tr '\n' ' ')"; fi
if [ "$before" = "$after" ] && [ ! -e "$ROOT/$DEBRIS" ]; then ck ok "the checkout gained no file (git status --porcelain unchanged)"
else ck no "the checkout changed under the runner: $(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep '^>' | head -3 | tr '\n' ' ')"; fi

echo "population: $checks arm(s), $fails failed (a two-file fixture roast tree under mktemp, the runner's --limit mode)"
[ "$fails" = 0 ] && { echo "GATE PASS(0) [raku_roast_runner_leaves_the_checkout_clean]: $checks of $checks arms hold"; exit 0; }
echo "GATE FAIL(1) [raku_roast_runner_leaves_the_checkout_clean]: $fails of $checks arms red"; exit 1
