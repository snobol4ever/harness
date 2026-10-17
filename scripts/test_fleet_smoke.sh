#!/usr/bin/env bash
# test_fleet_smoke.sh -- THE FLEET SMOKE, tier 1 of the verifier loop (Lon 2026-10-11 12:4x CDT, in-chat to the ceo, verbatim: "The COO should run a set of
# super-fast test, a so-called smoke test, often. Then full regressions much less often. And in general run test subsets as features are changed."; ceo CEO-1673;
# RULES.md section ONE TESTING OFFICER clause (8)). It runs the eight per-language smokes, one after another, and prints one labelled line per language and
# one FLEET_SMOKE total line. MEASURED by the ceo at SCRIP 19f33b101, load 12: snobol4 1.0 s, icon 2.3 s, prolog 10.6 s, snocone 0.2 s, rebus 0.3 s, raku
# 2.0 s, pascal 1.9 s, polyglot 1.7 s -- about 20 s in all, so the coo runs it after EVERY origin landing, before anything else, and a red reaches the lane
# within minutes of the landing. ZERO OR ONE TEST PER SEAT (CEO-1671): this runner is the coo's; every other seat is refused rc 2 unless the ceo's audit-window
# override S4E_ONE_TEST_ADMIT="why" is set, and only the coo's run appends a line to the record. THE RECORD: /home/resources/progress/SMOKE.tsv, one line per
# coo run -- at_utc, scrip tree, corpus tree, green langs, red langs, pass, fail, secs, the red languages by name -- which the coo's rank-0 row reads.
# rc 0 = every language smoke green; 1 = a red, named; 2 = could not measure (a smoke refused, or a runner is missing).
# usage: bash ../harness/scripts/test_fleet_smoke.sh [--list]   (--list prints the eight runners and runs nothing)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
LANGS="snobol4 icon prolog snocone rebus raku pascal polyglot"
RECORD="${S4E_SMOKE_RECORD:-/home/resources/progress/SMOKE.tsv}"
if [ "${1:-}" = --list ]; then for l in $LANGS; do echo "../harness/scripts/test_smoke_$l.sh"; done; exit 0; fi
seat="$(bash "$HERE/lib_one_runner.sh" --seat 2>/dev/null)"
if [ "$seat" != coo ] && [ -z "${S4E_ONE_TEST_ADMIT:-}" ]; then echo "FLEET_SMOKE REFUSE(2): ZERO OR ONE TEST PER SEAT (CEO-1671) -- the fleet smoke is the coo's tier-1 run; seat ${seat:-?} verifies a landing by its row's DONE-WHEN alone"; exit 2; fi
[ -x ./scrip ] || { echo "FLEET_SMOKE REFUSE(2): ./scrip is not built"; exit 2; }
for l in $LANGS; do [ -f "../harness/scripts/test_smoke_$l.sh" ] || { echo "FLEET_SMOKE REFUSE(2): ../harness/scripts/test_smoke_$l.sh is missing"; exit 2; }; done
tree="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"; ctree="$(git -C "$ROOT/../corpus" rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
T0=$(date +%s.%N); green=0; red=0; refused=0; pass=0; fail=0; reds=""; W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
for l in $LANGS; do
  t0=$(date +%s.%N); timeout -k 5 300 bash "../harness/scripts/test_smoke_$l.sh" </dev/null >"$W/$l.out" 2>&1; rc=$?; t1=$(date +%s.%N)
  p=$(grep -oE 'PASS=[0-9]+' "$W/$l.out" | sed 's/PASS=//' | awk '{s+=$1} END{print s+0}'); f=$(grep -oE 'FAIL=[0-9]+' "$W/$l.out" | sed 's/FAIL=//' | awk '{s+=$1} END{print s+0}')
  pass=$((pass + p)); fail=$((fail + f))
  case "$rc" in 0) v=GREEN; green=$((green + 1));; 2) v=REFUSED; refused=$((refused + 1)); reds="$reds $l(refused)";; *) v=RED; red=$((red + 1)); reds="$reds $l";; esac
  printf 'FLEET_SMOKE lang=%-8s %-7s rc=%-3s pass=%-4s fail=%-3s secs=%s\n' "$l" "$v" "$rc" "$p" "$f" "$(echo "$t1 - $t0" | bc | sed 's/^\./0./')"
  [ "$v" = GREEN ] || { echo "---- $l (last 6 lines) ----"; tail -6 "$W/$l.out" | sed 's/^/    /'; }
done
secs="$(echo "$(date +%s.%N) - $T0" | bc | sed 's/^\./0./')"
printf 'FLEET_SMOKE total: langs=8 green=%s red=%s refused=%s pass=%s fail=%s wall=%ss tree=%s corpus=%s%s\n' "$green" "$red" "$refused" "$pass" "$fail" "$secs" "$tree" "$ctree" "${reds:+ reds:$reds}"
if [ "$seat" = coo ]; then
  [ -f "$RECORD" ] || printf '# THE FLEET SMOKE RECORD (ceo CEO-1673): one line per coo run of ../harness/scripts/test_fleet_smoke.sh -- tier 1 of the verifier loop, run after every origin landing.\nat_utc\tscrip\tcorpus\tgreen\tred\trefused\tpass\tfail\tsecs\treds\n' > "$RECORD"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tree" "$ctree" "$green" "$red" "$refused" "$pass" "$fail" "$secs" "${reds# }" >> "$RECORD"
fi
[ "$refused" = 0 ] || exit 2
[ "$red" = 0 ]
