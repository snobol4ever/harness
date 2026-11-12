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
[ -f "$ROOT/corpus/tests/snobol4/ALL.csv" ] && { [ -f "$ROOT/corpus/tests/snobol4/ALL.sno" ] || [ -f "$ROOT/corpus/tests/snobol4/MULTI-LINERS.md" ] || [ -f "$ROOT/corpus/tests/snobol4/ONE-LINERS.sno" ]; } || { echo "⛔ REFUSE(2) [$GATE_NAME]: no SNOBOL4 master to copy"; exit 2; }
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
arm "neither is named in ALL.omit" "$(grep -c 'gate_st' "$D/corpus/tests/snobol4/ALL.omit")" 0
python3 "$HERE/corpus_suite_harness.py" extract "$D/corpus/tests/snobol4/ALL.sno" "$D/corpus/tests/snobol4/ALL.ref" demo_gate_stale "$D/x.sno" --out-ref "$D/x.ref" > /dev/null 2>&1
arm "the stale one's ref is the oracle's fresh answer" "$(cat "$D/x.ref" 2>/dev/null)" "fresh answer"
arm "neither is marked xfail" "$(grep -cE 'demo_gate_st' "$D/corpus/tests/snobol4/ALL.xfail" 2>/dev/null || echo 0)" 0
cd_out="$(python3 "$HERE/util_rungs_content_diff.py" "$ROOT/corpus/tests/snobol4" "$D/corpus/tests/snobol4" --lang snobol4 2>&1)"
arm "no entry already in the master moved (lost 0, changed 0, gained 2)" "$(printf '%s\n' "$cd_out" | grep -oE 'lost \(in A, not B\) : [0-9]+|gained \(in B, not A\): [0-9]+|differing content: [0-9]+' | grep -oE '[0-9]+$' | paste -sd' ')" "0 2 0"
# CIO-64: THE BUILDER EDITS A FORMAT-2 MASTER NATIVELY. The snobol4 master is format 2 and holds an entry the old form cannot hold (the fwctx
# standalone entry, corpus ddbd15a22); before the cure every builder run on it refused at the ungroup. After the run the scratch master is still
# format 2 (no ALL.sno came back) and reads back through the harness with that entry in it.
if [ -f "$ROOT/corpus/tests/snobol4/MULTI-LINERS.md" ]; then
    arm "snobol4: the master stays format 2 (MULTI-LINERS.md present, no ALL.sno written)" "$([ -f "$D/corpus/tests/snobol4/MULTI-LINERS.md" ] && [ ! -f "$D/corpus/tests/snobol4/ALL.sno" ] && echo yes)" yes
    arm "snobol4: every entry of the master reads back after the native write" "$(printf '%s\n' "$names" | grep -c .)" "$(( $(python3 "$HERE/corpus_suite_harness.py" list "$ROOT/corpus/tests/snobol4/ALL.sno" "$ROOT/corpus/tests/snobol4/ALL.ref" --lang snobol4 2>/dev/null | grep -c .) + 2 ))"
fi
# ---- THE TRANSPILE ROAD AND THE STALE OMIT KEY (CIO-56 (d), row tests-layout-the-rungs-builder-admits-by-the-oracle-cut-alone-in-every-language-
# and-retracts-an-omit-line-with-no-source): a scratch copy of the Rebus master, the pair road (no --additive), two planted pairs each with a stale
# loose .ref: gate_hang loops on the oracle road (scrip --transpile, then sbl -bf) and gate_recut prints "fresh answer"; one planted omit key that
# names no file. Before the cure both pairs entered from their loose .ref and the key was kept (officer_08's reading on harness 21201d3).
[ -f "$ROOT/corpus/tests/rebus/ALL.reb" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no Rebus master at $ROOT/corpus/tests/rebus/ALL.reb to copy"; exit 2; }
R="$D/reb"; RT="$R/corpus/tests/rebus"; mkdir -p "$R/corpus/tests" "$R/corpus/include" || exit 2
cp -r "$ROOT/corpus/tests/rebus" "$RT" || exit 2
printf 'function main()\nbegin\n  while 1 do x := 1\nend\n' > "$RT/gate_hang.reb"; printf 'stale answer\n' > "$RT/gate_hang.ref"
printf 'function main()\nbegin\n  output := "fresh answer"\nend\n' > "$RT/gate_recut.reb"; printf 'stale answer\n' > "$RT/gate_recut.ref"
# CIO-70: a program SPITBOL refuses on the transpile road (an undefined function, ERROR 022 on both runs) is NO-ANSWER, never an entry
printf 'function main()\nbegin\n  output := nosuchfunction(1)\nend\n' > "$RT/gate_refused.reb"; printf 'stale answer\n' > "$RT/gate_refused.ref"
sed -i '/^# builder-digest:/d' "$RT/ALL.omit"; printf 'gate_no_source_key\tplanted by the gate: names no file\n' >> "$RT/ALL.omit"
( cd "$ROOT/SCRIP" && S4E_HOME="$R" SCRIP="$D/bin/scrip" timeout -k 10 900 python3 "$HERE/util_build_rungs_suite.py" --lang rebus --recipe-timeout 2 < /dev/null ) > "$R/build.log" 2>&1; rrc=$?
grep -q '^WROTE ' "$R/build.log" || { echo "⛔ REFUSE(2) [$GATE_NAME]: the Rebus builder run wrote nothing (rc $rrc) -- cannot measure"; tail -3 "$R/build.log"; exit 2; }
arm "rebus: the builder ran (rc)" "$rrc" 0
rnames="$(python3 "$HERE/corpus_suite_harness.py" list "$RT/ALL.reb" "$RT/ALL.ref" --lang rebus 2>/dev/null)"
arm "rebus: a program whose oracle cut times out is not admitted from its loose .ref" "$(printf '%s\n' "$rnames" | grep -cx 'gate_hang')" 0
arm "rebus: and it is an omit line with the measured reason" "$(grep -c '^gate_hang	.*over budget' "$RT/ALL.omit")" 1
# the builder names a new entry by its features; the program it came from is its ALL.csv origin cell
rent="$(python3 -c 'import csv,sys; print("\n".join(r["entry"] for r in csv.DictReader(open(sys.argv[1])) if r.get("origin") == sys.argv[2]))' "$RT/ALL.csv" gate_recut 2>/dev/null)"
arm "rebus: a stale loose .ref is admitted on the oracle's answer (one entry of origin gate_recut)" "$(printf '%s\n' "$rent" | grep -c .)" 1
arm "rebus: a program SPITBOL refuses on the transpile road is not an entry (CIO-70)" "$(python3 -c 'import csv,sys; print(sum(1 for r in csv.DictReader(open(sys.argv[1])) if r.get("origin") == "gate_refused"))' "$RT/ALL.csv" 2>/dev/null)" 0
arm "rebus: its omit line carries SPITBOL's error number and text" "$(grep -c '^gate_refused	.*SPITBOL ERROR 022 -- undefined function called' "$RT/ALL.omit")" 1
arm "rebus: no entry comes from the timed-out program" "$(python3 -c 'import csv,sys; print(sum(1 for r in csv.DictReader(open(sys.argv[1])) if r.get("origin") == "gate_hang"))' "$RT/ALL.csv" 2>/dev/null)" 0
rref="$(python3 - "$HERE" "$RT" "$rent" <<'PY' 2>/dev/null
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
c = h.LANG_CONFIGS["rebus"]
for e in h.read_block_suite(sys.argv[2] + "/ALL.reb", sys.argv[2] + "/ALL.ref", h.banner_re_for(c["comment_open"], c["comment_close"])):
    if e.name == sys.argv[3]: print("\n".join(e.ref) if isinstance(e.ref, list) else e.ref, end="")
PY
)"
arm "rebus: its ref is the oracle's fresh answer" "$(printf '%s' "$rref" | sed '/^$/d')" "fresh answer"
arm "rebus: the omit key that names no file is retracted" "$(grep -c '^gate_no_source_key' "$RT/ALL.omit")" 0
arm "rebus: the retraction is printed once with its count" "$(grep -cE '^RETRACTED-NO-SOURCE [0-9]+' "$R/build.log")" 1
rd_out="$(python3 "$HERE/util_rungs_content_diff.py" "$ROOT/corpus/tests/rebus" "$RT" --lang rebus 2>&1)"
arm "rebus: no entry already in the master moved (lost 0, changed 0, gained 1)" "$(printf '%s\n' "$rd_out" | grep -oE 'lost \(in A, not B\) : [0-9]+|gained \(in B, not A\): [0-9]+|differing content: [0-9]+' | grep -oE '[0-9]+$' | paste -sd' ')" "0 1 0"
[ "$RED" = 0 ] && { echo "GATE OK [$GATE_NAME]: $ARMS arms green -- with a stand-in scrip that prints nothing, the oracle alone admits both programs and the master's entries are unchanged; on the Rebus transpile road an oracle timeout is omitted, a stale .ref is re-cut and a key with no source is retracted"; exit 0; }
echo "GATE FAIL [$GATE_NAME]: $RED of $ARMS arms red"; exit 1
