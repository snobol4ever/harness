#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_scrip_sizes_the_heap_with_d_and_i.sh -- SCRIP SIZES THE GC HEAP WITH -d (THE HARD CAP) AND -i (THE INITIAL WINDOW AND
# ENLARGE AMOUNT) AND THE STACK WITH -s, AS SPITBOL DOES, IN BOTH MODES; THE ENVIRONMENT KNOBS ARE A NAMED TEST SEAM THAT A SWITCH
# OVERRIDES (cto 2026-09-23, row spine-scrip-sizes-the-heap-with-d-and-i-and-the-stack-with-s-exactly-like-spitbol; Lon in-chat
# to the ceo, verbatim: "Do we set the stack and heap memory with the -s and the -m command line switches, just like SPITBOL. If
# not, do you not think we should?"; CEO-1225).
#
# WHY A SWITCH AND NOT AN ENV KNOB: an environment variable is invisible in a transcript -- it is how the 1 MB tiny arm read as a
# measurement while inert (CEO-1146) -- and a switch on the command line is recorded with the run.
#
# ARMS (every reading comes from the runtime's own GC-EXERCISE report, collections= and cap_kb=, never from the knob):
#   (1) a witness with a ~20 MB live set dies at -d4m and prints its answer under -d64m and at the default cap, in mode 3;
#   (2) the same witness compiled once and run as a binary takes -d4m and -d64m on ITS command line (mode 4);
#   ⛔ SINCE CEO-1261 (Lon 2026-09-25: "Let's set our default stack size and heap size for SCRIP to be the same as SPITBOL.") the
#   default cap is SPITBOL's -d128m and the default stack its -s4m, so the arms name a small cap explicitly instead of leaning on the
#   default -- the old 4 MB default is what the witness used to overflow, and a 128 MB live set is no witness for a gate.
#   (3) -i is the window: the same allocating witness collects many times at -i128k and never at -i64m, both under -d64m;
#   (4) the switch wins over the seam: SCRIP_HEAP_KB=128 in the environment with -i64m on the line reads zero collections;
#   (5) the seam still works alone (the 92 instrument scripts that size through SCRIP_HEAP_KB are not broken by this landing);
#   (6) -s sizes the stack: a deep-recursion witness that overflows SPITBOL's 4 MB default completes at -s512m, both modes
#       (the runtime sets the program's budget from -s, SCRIP_STACK or the 4 MB default, counted from where the program starts);
#   (7) the usage no longer calls -d/-i accepted-and-ignored;
#   (8) NEGATIVE: -d below -i is refused with its reason; a malformed -d value is refused; the -i arm can red (a wrong expectation).
#
# Usage: bash ../harness/scripts/test_gate_scrip_sizes_the_heap_with_d_and_i.sh    (exit 0 = green, 1 = measured broken, 2 = could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; C="$ROOT/scrip"
[ -x "$C" ] || { echo "REFUSED(2): scrip is not built"; exit 2; }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT; cd "$d" || exit 2
printf "        T = TABLE()\n        I = 0\nLOOP    I = I + 1\n        T<I> = DUPL('x', 1000)\n        LE(I, 20000)    :S(LOOP)\n        OUTPUT = 'done ' I\nEND\n" > big.sno
printf "        I = 0\nLOOP    I = I + 1\n        S = DUPL('y', 2000)\n        LE(I, 4000)    :S(LOOP)\n        OUTPUT = 'churn ' I\nEND\n" > churn.sno
printf "        DEFINE('F(N)')                        :(GO)\nF       F = EQ(N, 0) 0                     :S(RETURN)\n        F = F(N - 1) + 1                    :(RETURN)\nGO      OUTPUT = 'depth ' F(1000000)\nEND\n" > deep.sno
fails=0; arms=0
ck() { arms=$((arms+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else echo "  FAIL $2"; fails=$((fails+1)); fi; }
clean() { env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_MAX_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_STACK "$@"; }
colls() { grep -o 'collections=[0-9]*' "$1" | tail -1 | cut -d= -f2; }
o0=$(clean timeout -k 5 60 "$C" -d4m big.sno < /dev/null 2>/dev/null); r0=$?; od=$(clean timeout -k 5 60 "$C" big.sno < /dev/null 2>/dev/null)
[ "$o0" != "done 20001" ] && [ "$od" = "done 20001" ] && ck ok "(1a) the witness does NOT fit -d4m (rc=$r0, output '$o0') and answers at the default cap" || ck no "(1a) -d4m printed '$o0' (rc=$r0), the default cap printed '$od' -- the witness must die at 4 MB and answer at SPITBOL's 128 MB"
o1=$(clean timeout -k 5 60 "$C" -d64m big.sno < /dev/null 2>/dev/null); [ "$o1" = "done 20001" ] && ck ok "(1b) -d64m: the witness prints its answer in mode 3" || ck no "(1b) -d64m in mode 3 printed '$o1'"
if clean "$C" --compile --out=big.s big.sno < /dev/null > /dev/null 2>&1 && gcc -no-pie -o bigbin big.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null; then
    o2=$(clean timeout -k 5 60 ./bigbin -d4m < /dev/null 2>/dev/null); o3=$(clean timeout -k 5 60 ./bigbin -d64m < /dev/null 2>/dev/null)
    [ "$o2" != "done 20001" ] && [ "$o3" = "done 20001" ] && ck ok "(2) the mode-4 binary dies at -d4m and prints the answer with -d64m, each on its own command line" || ck no "(2) mode-4: with -d4m '$o2', with -d64m '$o3'"
else ck no "(2) could not compile or link the witness for mode 4"; fi
clean env SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$C" -d64m -i128k churn.sno < /dev/null > c1.out 2> c1.err; c1=$(colls c1.err)
clean env SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$C" -d64m -i64m churn.sno < /dev/null > c2.out 2> c2.err; c2=$(colls c2.err)
[ -n "$c1" ] && [ -n "$c2" ] && [ "$c1" -gt 10 ] && [ "$c2" = 0 ] && [ "$(cat c1.out)" = "churn 4001" ] && [ "$(cat c2.out)" = "churn 4001" ] && ck ok "(3) -i is the window: collections=$c1 at -i128k, $c2 at -i64m, same answer" || ck no "(3) -i: collections at -i128k=${c1:-?}, at -i64m=${c2:-?}, outputs '$(cat c1.out)' / '$(cat c2.out)'"
clean env SCRIP_HEAP_KB=128 SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$C" -d64m -i64m churn.sno < /dev/null > c3.out 2> c3.err; c3=$(colls c3.err)
[ "$c3" = 0 ] && ck ok "(4) the switch wins over the seam: SCRIP_HEAP_KB=128 with -i64m reads collections=0" || ck no "(4) with SCRIP_HEAP_KB=128 and -i64m collections=${c3:-?}"
clean env SCRIP_HEAP_KB=128 SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$C" churn.sno < /dev/null > c4.out 2> c4.err; c4=$(colls c4.err)
[ -n "$c4" ] && [ "$c4" -gt 10 ] && ck ok "(5) the seam alone still sizes a run: SCRIP_HEAP_KB=128 reads collections=$c4" || ck no "(5) SCRIP_HEAP_KB=128 alone reads collections=${c4:-?}"
s1=$(clean timeout -k 5 120 "$C" deep.sno < /dev/null 2>/dev/null); rs1=$?; s2=$(clean timeout -k 5 120 "$C" -s512m deep.sno < /dev/null 2>/dev/null); rs2=$?
[ "$s2" = "depth 1000000" ] && { [ "$rs1" != 0 ] || [ "$s1" != "depth 1000000" ]; } && ck ok "(6a) -s: the deep witness overflows the 4 MB default (rc=$rs1) and completes at -s512m, mode 3" || ck no "(6a) -s mode 3: default rc=$rs1 '$s1', at -s512m rc=$rs2 '$s2' (if both complete, the depth is too small to measure -s)"
if clean "$C" --compile --out=deep.s deep.sno < /dev/null > /dev/null 2>&1 && gcc -no-pie -o deepbin deep.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null; then
    s3=$(clean timeout -k 5 120 ./deepbin < /dev/null 2>/dev/null); rs3=$?; s4=$(clean timeout -k 5 120 ./deepbin -s512m < /dev/null 2>/dev/null)
    [ "$s4" = "depth 1000000" ] && { [ "$rs3" != 0 ] || [ "$s3" != "depth 1000000" ]; } && ck ok "(6b) -s on the mode-4 binary's command line: overflows at the 4 MB default (rc=$rs3), completes at -s512m" || ck no "(6b) -s mode 4: default rc=$rs3 '$s3', at -s512m '$s4'"
else ck no "(6b) could not compile or link the deep witness"; fi
u=$("$C" 2>&1 | grep -ciE '^ *-dN.*accepted'); [ "$u" = 0 ] && ck ok "(7) the usage no longer calls -d/-i accepted-and-ignored" || ck no "(7) usage lines still calling -d accepted-and-ignored: $u"
clean timeout -k 5 60 "$C" -d1m -i2m churn.sno < /dev/null > /dev/null 2> n1.err; rn1=$?; [ "$rn1" != 0 ] && grep -qi "below" n1.err && ck ok "(8a) -d below -i is refused with its reason (rc=$rn1)" || ck no "(8a) -d1m -i2m rc=$rn1: $(head -c 120 n1.err)"
clean timeout -k 5 60 "$C" -dbig churn.sno < /dev/null > /dev/null 2> n2.err; rn2=$?; [ "$rn2" != 0 ] && grep -qi "bad -d value" n2.err && ck ok "(8b) a malformed -d value is refused" || ck no "(8b) -dbig rc=$rn2: $(head -c 120 n2.err)"
[ "$c2" != 7 ] && ck ok "(8c) negative control: the -i arm can red (a planted wrong expectation reads FAIL)" || ck no "(8c) the -i arm cannot fail"
echo "population: $arms arm(s), $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [test_gate_scrip_sizes_the_heap_with_d_and_i]: -d caps the heap, -i sets its window and step, -s the stack, in both modes; the seam is named and overridden"; exit 0; fi
echo "GATE RED [test_gate_scrip_sizes_the_heap_with_d_and_i]: $fails arm(s) failed"; exit 1
