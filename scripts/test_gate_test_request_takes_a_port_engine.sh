#!/bin/bash
# test_gate_test_request_takes_a_port_engine.sh -- A PORT ENGINE'S REQUEST IS REFUSED AT FILING (ceo CEO-1912, re-cut by the coo; Lon 2026-10-22 15:0x, verbatim:
# "Let HQ-JVM and HQ-DOTNET run their own tests."; the ceo 15:2x: "A request that bounces back ungraded a turn later is a dark road; a refusal at filing
# is not."). CEO-1872's port lane is reversed: MODE LANES gives snobol4@dotnet to hq_dotnet and snobol4@jvm, snocone@jvm, rebus@jvm to hq_jvm, and the
# coo's loop grades no port engine (loop v14j), so s4e_test_request.sh --engine dotnet|jvm REFUSES rc 2, names the HQ whose lane it is and CEO-1912,
# and files nothing; the file keeps its name so its wiring stands. Hermetic, no build, nothing live: s4e_test_request.sh against a scratch request
# folder and the real corpus tables (read only). ARMS: (1) --engine dotnet --suites and --engine jvm --suites refuse rc 2 naming CEO-1912 and the HQ,
# filing nothing. (2) a dotnet request by part refuses rc 2 naming hq_dotnet and files nothing. (3) a jvm request by entry refuses rc 2 naming hq_jvm
# and files nothing. (4) a SCRIP request carries no engine line. (5) a port seat is found by its root name (hq_dotnet, hq_jvm) for a SCRIP request.
# (6) an unknown engine refuses rc 2 and files nothing. (7) --engine scrip files a plain SCRIP request: no engine line, no engine in its name.
# (8) --status names each pending request's engine (scrip). Red on harness e75d692: (1), (2), (3) and (8) fail there.
set -u
unset S4E_SEAT
H="$(cd "$(dirname "$0")" && pwd)"; Q="$H/s4e_test_request.sh"; G=test_request_takes_a_port_engine; fail=0; examined=0
C="$(cd "$H/../.." && pwd)/corpus"
[ -r "$Q" ] || { echo "REFUSE(2) [$G]: no $Q"; exit 2; }
[ -f "$C/packages/snobol4/gimpel/PARTITION.tsv" ] && [ -f "$C/tests/snobol4/PARTITION.tsv" ] || { echo "REFUSE(2) [$G]: no corpus partitions under $C"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export S4E_TEST_REQUEST_DIR="$T/req" S4E_CORPUS="$C"
arm() { examined=$((examined+1)); if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=$((fail+1)); fi; }
nreq() { ls "$T/req"/*.req 2>/dev/null | wc -l; }
n0=$(nreq); bash "$Q" --engine dotnet --suites > "$T/sd" 2>&1; rd=$?
bash "$Q" --engine jvm --suites > "$T/sj" 2>&1; rj=$?
arm "(1) --engine dotnet|jvm --suites refuse rc 2 naming CEO-1912 and the HQ, filing nothing" '[ $rd = 2 ] && [ $rj = 2 ] && grep -q "REFUSED(2)" "$T/sd" && grep -q "CEO-1912" "$T/sd" && grep -q "hq_dotnet" "$T/sd" && grep -q "hq_jvm" "$T/sj" && ! grep -q "^sno-rungs " "$T/sd" && [ $(nreq) = $n0 ]'
n0=$(nreq); S4E_SEAT=hq_dotnet bash "$Q" --engine dotnet gimpel --part core > "$T/o2" 2>&1; r2=$?
arm "(2) a dotnet part request refuses rc 2 naming hq_dotnet and files nothing" '[ $r2 = 2 ] && grep -q "REFUSED(2)" "$T/o2" && grep -q "hq_dotnet" "$T/o2" && grep -q "nothing filed" "$T/o2" && [ $(nreq) = $n0 ]'
n0=$(nreq); S4E_SEAT=hq_jvm bash "$Q" --engine jvm sno-rungs "$(awk -F'\t' '!/^#/ && $2=="core" {print $1; exit}' "$C/tests/snobol4/PARTITION.tsv")" > "$T/o3" 2>&1; r3=$?
arm "(3) a jvm entry request refuses rc 2 naming hq_jvm and files nothing" '[ $r3 = 2 ] && grep -q "REFUSED(2)" "$T/o3" && grep -q "hq_jvm" "$T/o3" && [ $(nreq) = $n0 ]'
S4E_SEAT=coo bash "$Q" gimpel --part core > "$T/o4" 2>&1; r4=$?
f4="$(ls "$T/req"/*-coo-gimpel-[0-9]*.req 2>/dev/null | head -1)"
arm "(4) a SCRIP request carries no engine line" '[ $r4 = 0 ] && [ -n "$f4" ] && ! grep -q "^engine=" "$f4"'
mkdir -p "$T/root/claude_dotnet/harness/scripts" "$T/root/claude_jvm/harness/scripts"
cp "$Q" "$T/root/claude_dotnet/harness/scripts/"; cp "$Q" "$T/root/claude_jvm/harness/scripts/"
n0=$(nreq); bash "$T/root/claude_dotnet/harness/scripts/s4e_test_request.sh" dotnet --part core > "$T/o5a" 2>&1; r5a=$?
bash "$T/root/claude_jvm/harness/scripts/s4e_test_request.sh" dotnet --part core > "$T/o5b" 2>&1; r5b=$?
arm "(5) a port seat is found by its root name for a SCRIP request" '[ $r5a = 0 ] && [ $r5b = 0 ] && grep -q "for hq_dotnet\." "$T/o5a" && grep -q "for hq_jvm\." "$T/o5b" && [ $(nreq) = $((n0 + 2)) ]'
n0=$(nreq); S4E_SEAT=coo bash "$Q" --engine foo gimpel --part core > "$T/o6" 2>&1; r6=$?
arm "(6) an unknown engine refuses rc 2 and files nothing" '[ $r6 = 2 ] && grep -q "REFUSED(2)" "$T/o6" && [ $(nreq) = $n0 ]'
n0=$(nreq); S4E_SEAT=hq_jvm bash "$Q" --engine scrip sno-rungs "$(awk -F'\t' '!/^#/ && $2=="core" {print $1; exit}' "$C/tests/snobol4/PARTITION.tsv")" > "$T/o7" 2>&1; r7=$?
f7="$(ls "$T/req"/*-hq_jvm-sno-rungs-[0-9]*.req 2>/dev/null | head -1)"
arm "(7) --engine scrip files a plain SCRIP request, no engine line and no engine in its name" '[ $r7 = 0 ] && [ -n "$f7" ] && ! grep -q "^engine=" "$f7" && [ $(nreq) = $((n0 + 1)) ]'
bash "$Q" --status > "$T/o8" 2>&1
arm "(8) --status names each request's engine, scrip, and no port request is pending" 'grep -q "coo-gimpel-[0-9]*  .* on scrip$" "$T/o8" && ! grep -qE " on (dotnet|jvm)$" "$T/o8"'
echo "GATE [$G] examined=$examined failed=$fail"
[ $fail = 0 ] || { echo "RED [$G]"; exit 1; }
echo "PASS [$G]"
