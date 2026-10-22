#!/bin/bash
# test_gate_test_request_takes_a_port_engine.sh -- THE coo TESTS EVERY ENGINE (Lon 2026-10-21 17:5x CDT, in-chat to the ceo, verbatim: "I suspect that
# COO should be in charge of DOTNET and JVM and X86/64 testing to keep machine load down."; ceo CEO-1872, row coo-the-loop-grades-the-port-engines-ceo-1872).
# Hermetic, no build, nothing live: s4e_test_request.sh against a scratch request folder and the real corpus tables (read only). ARMS: (1) --engine dotnet
# --suites and --engine jvm --suites list the port keys, sno-rungs and gimpel among them, and no Icon, Prolog or Pascal key. (2) a dotnet request by part
# files one request whose file carries engine=dotnet, the bare suite key and the part's entries, and whose name carries the engine. (3) a jvm request by
# entry files one with engine=jvm. (4) a SCRIP request carries no engine line (a SCRIP request file is unchanged). (5) a port seat is found by its root
# name: hq_dotnet and hq_jvm. (6) an unknown engine REFUSES rc 2 and files nothing. (7) a key no port runs (icn-rungs) REFUSES rc 2 under a port engine
# and files nothing. (8) --status names each pending request's engine.
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
bash "$Q" --engine dotnet --suites > "$T/sd" 2>&1; rd=$?
bash "$Q" --engine jvm --suites > "$T/sj" 2>&1; rj=$?
arm "(1) --engine dotnet|jvm --suites list the port keys and no other language's" '[ $rd = 0 ] && [ $rj = 0 ] && grep -q "^sno-rungs " "$T/sd" && grep -q "^gimpel " "$T/sj" && ! grep -qE "^(icn-rungs|pl-rungs|pas-rungs|ipl|swi) " "$T/sd" "$T/sj"'
S4E_SEAT=hq_dotnet bash "$Q" --engine dotnet gimpel --part core > "$T/o2" 2>&1; r2=$?
f2="$(ls "$T/req"/*-hq_dotnet-gimpel-dotnet-*.req 2>/dev/null | head -1)"
want="$(awk -F'\t' '!/^#/ && $2=="core" {print $1}' "$C/packages/snobol4/gimpel/PARTITION.tsv" | grep -v '^entry$' | tr '\n' ' ' | sed 's/ $//')"
arm "(2) a dotnet part request carries engine=dotnet, the bare key and the part's entries" '[ $r2 = 0 ] && [ -n "$f2" ] && grep -qx engine=dotnet "$f2" && grep -qx suite=gimpel "$f2" && grep -qxF "entries=$want" "$f2"'
S4E_SEAT=hq_jvm bash "$Q" --engine jvm sno-rungs "$(awk -F'\t' '!/^#/ && $2=="core" {print $1; exit}' "$C/tests/snobol4/PARTITION.tsv")" > "$T/o3" 2>&1; r3=$?
f3="$(ls "$T/req"/*-hq_jvm-sno-rungs-jvm-*.req 2>/dev/null | head -1)"
arm "(3) a jvm entry request carries engine=jvm" '[ $r3 = 0 ] && [ -n "$f3" ] && grep -qx engine=jvm "$f3"'
S4E_SEAT=coo bash "$Q" gimpel --part core > "$T/o4" 2>&1; r4=$?
f4="$(ls "$T/req"/*-coo-gimpel-[0-9]*.req 2>/dev/null | head -1)"
arm "(4) a SCRIP request carries no engine line" '[ $r4 = 0 ] && [ -n "$f4" ] && ! grep -q "^engine=" "$f4"'
mkdir -p "$T/root/claude_dotnet/harness/scripts" "$T/root/claude_jvm/harness/scripts"
cp "$Q" "$T/root/claude_dotnet/harness/scripts/"; cp "$Q" "$T/root/claude_jvm/harness/scripts/"
n0=$(nreq); bash "$T/root/claude_dotnet/harness/scripts/s4e_test_request.sh" --engine dotnet dotnet --part core > "$T/o5a" 2>&1; r5a=$?
bash "$T/root/claude_jvm/harness/scripts/s4e_test_request.sh" --engine jvm dotnet --part core > "$T/o5b" 2>&1; r5b=$?
arm "(5) a port seat is found by its root name" '[ $r5a = 0 ] && [ $r5b = 0 ] && grep -q "for hq_dotnet\." "$T/o5a" && grep -q "for hq_jvm\." "$T/o5b" && [ $(nreq) = $((n0 + 2)) ]'
n0=$(nreq); S4E_SEAT=coo bash "$Q" --engine foo gimpel --part core > "$T/o6" 2>&1; r6=$?
arm "(6) an unknown engine refuses rc 2 and files nothing" '[ $r6 = 2 ] && grep -q "REFUSED(2)" "$T/o6" && [ $(nreq) = $n0 ]'
n0=$(nreq); S4E_SEAT=hq_jvm bash "$Q" --engine jvm icn-rungs --part core > "$T/o7" 2>&1; r7=$?
arm "(7) a key no port runs refuses rc 2 under a port engine and files nothing" '[ $r7 = 2 ] && grep -q "no suite of the jvm engine" "$T/o7" && [ $(nreq) = $n0 ]'
bash "$Q" --status > "$T/o8" 2>&1
arm "(8) --status names each request's engine" 'grep -q "gimpel-dotnet-.* on dotnet$" "$T/o8" && grep -q "sno-rungs-jvm-.* on jvm$" "$T/o8" && grep -q "coo-gimpel-[0-9]*  .* on scrip$" "$T/o8"'
echo "GATE [$G] examined=$examined failed=$fail"
[ $fail = 0 ] || { echo "RED [$G]"; exit 1; }
echo "PASS [$G]"
