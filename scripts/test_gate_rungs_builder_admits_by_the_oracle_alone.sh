#!/usr/bin/env bash
# test_gate_rungs_builder_admits_by_the_oracle_alone.sh -- THE RUNGS BUILDER ASKS THE ORACLE, NEVER SCRIP, WHETHER A PROGRAM JOINS (CIO-37, the cio
# 2026-11-10 on the coo's design point; row tests-layout-snobol4-folder-is-its-container-and-config-alone). util_build_rungs_suite.py --additive
# on a scratch copy of the SNOBOL4 master, with SCRIP pointed at a stand-in that prints nothing (so every SCRIP run of every candidate would read
# FAIL): a program with a stable oracle answer and no ref is absorbed; a program whose committed .ref is stale is absorbed on the oracle's fresh
# answer, not excluded; neither is marked xfail; every entry already in the master reads back unchanged (util_rungs_content_diff.py: lost 0,
# changed 0, gained 2). On the builder before CIO-37 the stale-ref program read "committed .ref disagrees with a fresh oracle run" and stayed out.
# rc 0 green · 1 red (the failing arm named) · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_rungs_builder_admits_by_the_oracle_alone
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no SPITBOL oracle at $SBL"; exit 2; }
[ -f "$ROOT/corpus/tests/snobol4/ALL.csv" ] && { [ -f "$ROOT/corpus/tests/snobol4/ALL.sno" ] || [ -f "$ROOT/corpus/tests/snobol4/MULTI.md" ] || [ -f "$ROOT/corpus/tests/snobol4/ONE.sno" ]; } || { echo "⛔ REFUSE(2) [$GATE_NAME]: no SNOBOL4 master to copy"; exit 2; }
D=$(mktemp -d "${TMPDIR:-/tmp}/rungs_oracle_gate.XXXXXX") || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
[ -x "$ROOT/SCRIP/scrip" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $ROOT/SCRIP/scrip (the builder's own build-behaviour probe compiles with it)"; exit 2; }
mkdir -p "$D/corpus/tests" "$D/corpus/demos/snobol4" "$D/corpus/benchmarks/snobol4" "$D/corpus/include" "$D/bin" || exit 2
cp -r "$ROOT/corpus/tests/snobol4" "$D/corpus/tests/snobol4" || exit 2
# THE STAND-IN: a mode-3 run (--run) prints nothing and exits 0, so any SCRIP verdict on a candidate reads FAIL; every other call (the builder's own
# --compile probes) goes to the real scrip, which the builder needs to start at all.
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = --run ] && exit 0; done\nexec "%s" "$@"\n' "$ROOT/SCRIP/scrip" > "$D/bin/scrip"; chmod +x "$D/bin/scrip"
printf "        OUTPUT = 'stable answer'\n        OUTPUT = 6 * 7\nEND\n" > "$D/corpus/demos/snobol4/gate_stable.sno"
printf "        OUTPUT = 'fresh answer'\nEND\n" > "$D/corpus/demos/snobol4/gate_stale.sno"; printf 'stale answer\n' > "$D/corpus/demos/snobol4/gate_stale.ref"
RED=0; ARMS=0
arm() { ARMS=$((ARMS+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else RED=$((RED+1)); echo "  RED  $1"; echo "       got:  [$2]"; echo "       want: [$3]"; fi; }
( cd "$ROOT/SCRIP" && S4E_HOME="$D" SCRIP="$D/bin/scrip" timeout -k 10 900 python3 "$HERE/util_build_rungs_suite.py" --lang snobol4 --additive --from demos < /dev/null ) > "$D/build.log" 2>&1; brc=$?
grep -q 'new entries absorbed' "$D/build.log" || { echo "⛔ REFUSE(2) [$GATE_NAME]: the builder printed no accounting (rc $brc) -- cannot measure"; tail -3 "$D/build.log"; exit 2; }
arm "the builder ran (rc)" "$brc" 0
names="$(python3 "$HERE/corpus_suite_harness.py" list "$D/corpus/tests/snobol4/ALL.sno" "$D/corpus/tests/snobol4/ALL.ref" --lang snobol4 2>/dev/null)"
arm "a stable answer with no ref is absorbed (SCRIP prints nothing)" "$(printf '%s\n' "$names" | grep -cx 'demo_gate_stable')" 1
arm "a stale committed ref is absorbed, not excluded" "$(printf '%s\n' "$names" | grep -cx 'demo_gate_stale')" 1
arm "neither is named in ALL.excluded.txt" "$(grep -c 'gate_st' "$D/corpus/tests/snobol4/ALL.excluded.txt")" 0
python3 "$HERE/corpus_suite_harness.py" extract "$D/corpus/tests/snobol4/ALL.sno" "$D/corpus/tests/snobol4/ALL.ref" demo_gate_stale "$D/x.sno" --out-ref "$D/x.ref" > /dev/null 2>&1
arm "the stale one's ref is the oracle's fresh answer" "$(cat "$D/x.ref" 2>/dev/null)" "fresh answer"
arm "neither is marked xfail" "$(grep -cE 'demo_gate_st' "$D/corpus/tests/snobol4/ALL.xfail" 2>/dev/null || echo 0)" 0
cd_out="$(python3 "$HERE/util_rungs_content_diff.py" "$ROOT/corpus/tests/snobol4" "$D/corpus/tests/snobol4" --lang snobol4 2>&1)"
arm "no entry already in the master moved (lost 0, changed 0, gained 2)" "$(printf '%s\n' "$cd_out" | grep -oE 'lost \(in A, not B\) : [0-9]+|gained \(in B, not A\): [0-9]+|differing content: [0-9]+' | grep -oE '[0-9]+$' | paste -sd' ')" "0 2 0"
[ "$RED" = 0 ] && { echo "GATE OK [$GATE_NAME]: $ARMS arms green -- with a stand-in scrip that prints nothing, the oracle alone admits both programs and the master's entries are unchanged"; exit 0; }
echo "GATE FAIL [$GATE_NAME]: $RED of $ARMS arms red"; exit 1
