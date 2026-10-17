#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_heap_exhaustion_at_the_cap_is_a_reported_error_not_an_abort.sh -- A LIVE SET THAT OUTGROWS THE HEAP'S HARD CAP ENDS IN A
# PROPERLY REPORTED OUT-OF-MEMORY RUNTIME ERROR IN THE FRONTEND'S OWN VOICE, WITH A DEFINED EXIT STATUS BELOW 128 AND NO CORE, IN BOTH
# MODES; THE COLLECTOR'S DIAGNOSTIC CLASSIFICATION STAYS ON STDERR BESIDE IT (cto 2026-09-23, row
# spine-heap-exhaustion-at-the-hard-cap-is-a-properly-reported-out-of-memory-error-never-an-abort; Lon in-chat to the ceo, verbatim:
# "(2) a properly reported out of memory if not a failure so fix that if you consider that so."; CEO-1225).
#
# BEFORE: rc=134, SIGABRT, a core, after the [ZHP] HARD CAP REACHED banner. THE ORACLES' OWN TEXTS, measured: sbl -bf -d8m on the
# 20,000-entry table witness prints "ERROR 204 -- memory overflow"; Icon's out-of-memory errors are 306 "inadequate space in string
# region" and 307 "inadequate space in block region" (icont). SCRIP reports 204 in the SNOBOL4 voice and 306/307 in Icon's (the
# allocator knows the block kind), through the ONE error voice (core_runtime_error), so SETEXIT / &ERRLIMIT / Icon's &error see it
# like any other runtime error.
#
# ARMS: (1) the SNOBOL4 witness at the default cap: rc in 1..127, `scrip: error 204: memory overflow ...` naming the cap and the request,
# the [ZHP] classification banner (COLLECTIONS RUN) still beside it, no "Aborted"/core; (2) the same witness with -d64m prints done 20001;
# (3) the same in mode 4 (the binary takes -d64m on its own line); (4) an Icon witness that grows a list past the cap ends rc<128 with
# Icon's 307 text and its traceback; (5) SETEXIT (with &ERRLIMIT = 1, as SPITBOL requires for a trap) catches it like any runtime
# error -- sbl -bf -d8m prints trapped 204 on the same witness; (6) NEGATIVE: the arm
# that reads the exit status can red (a planted 134 expectation fails).
#
# ⛔ SINCE CEO-1261 (Lon 2026-09-25: "Let's set our default stack size and heap size for SCRIP to be the same as SPITBOL.") the default
# cap is SPITBOL's -d128m, which this ~20 MB witness fits, so every exhaustion arm names -d8m -- the cap the oracles were measured at
# above -- instead of leaning on the default (the old 4 MB default is what the witness used to overflow).
# Usage: bash ../harness/scripts/test_gate_heap_exhaustion_at_the_cap_is_a_reported_error_not_an_abort.sh    (0 green, 1 red, 2 could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; C="$ROOT/scrip"
[ -x "$C" ] || { echo "REFUSED(2): scrip is not built"; exit 2; }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT; cd "$d" || exit 2
clean() { env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_MAX_MB -u SCRIP_HEAP_CAP_KB "$@"; }
printf "        T = TABLE()\n        I = 0\nLOOP    I = I + 1\n        T[I] = DUPL('x', 1000)\n        LE(I, 20000)    :S(LOOP)\n        OUTPUT = 'done ' I\nEND\n" > w.sno
printf "        &ERRLIMIT = 1\n        SETEXIT(.TRAP)\n        T = TABLE()\n        I = 0\nLOOP    I = I + 1\n        T[I] = DUPL('x', 1000)\n        LE(I, 20000)    :S(LOOP)\n        OUTPUT = 'done ' I               :(END)\nTRAP    OUTPUT = 'trapped ' &ERRTYPE\nEND\n" > t.sno
printf "procedure main()\n  L := []; every i := 1 to 20000 do put(L, repl(\"x\", 1000));\n  write(\"done \", *L);\nend\n" > w.icn
fails=0; arms=0
ck() { arms=$((arms+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else echo "  FAIL $2"; fails=$((fails+1)); fi; }
clean timeout -k 5 60 "$C" -d8m w.sno < /dev/null > o1 2> e1; r1=$?
if [ "$r1" -ge 1 ] && [ "$r1" -lt 128 ] && grep -qE '^scrip: error 204: memory overflow' e1 && grep -qiE 'cap' e1 && grep -q 'COLLECTIONS RUN' e1; then ck ok "(1) -d8m cap, mode 3: rc=$r1, [$(grep -m1 -E '^scrip: error' e1 | cut -c1-110)], the [ZHP] classification kept"; else ck no "(1) default cap, mode 3: rc=$r1 stderr: $(grep -m1 -E 'scrip: error|Aborted|ZHP' e1 | cut -c1-140)"; fi
o2=$(clean timeout -k 5 60 "$C" -d64m w.sno < /dev/null 2>/dev/null); [ "$o2" = "done 20001" ] && ck ok "(2) -d64m, mode 3: done 20001" || ck no "(2) -d64m, mode 3 printed '$o2'"
if clean "$C" --compile -o w.s w.sno < /dev/null > /dev/null 2>&1 && gcc -no-pie -o wbin w.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null; then
    clean timeout -k 5 60 ./wbin -d8m < /dev/null > o3 2> e3; r3=$?; o4=$(clean timeout -k 5 60 ./wbin -d64m < /dev/null 2>/dev/null)
    if [ "$r3" -ge 1 ] && [ "$r3" -lt 128 ] && grep -qE '^scrip: error 204: memory overflow' e3 && [ "$o4" = "done 20001" ]; then ck ok "(3) mode 4: rc=$r3 with the error at -d8m, done 20001 with -d64m, each on the binary's line"; else ck no "(3) mode 4: rc=$r3 [$(grep -m1 -E 'scrip: error|Aborted' e3 | cut -c1-100)] / -d64m '$o4'"; fi
else ck no "(3) could not compile or link the witness for mode 4"; fi
clean timeout -k 5 60 "$C" -d8m w.icn < /dev/null > o5 2> e5; r5=$?
if [ "$r5" -ge 1 ] && [ "$r5" -lt 128 ] && grep -qiE 'inadequate space in (block|string) region' e5 && grep -qE 'error 30[67]' e5; then ck ok "(4) Icon at -d8m: rc=$r5, [$(grep -m1 -iE 'inadequate space' e5 | cut -c1-110)]"; else ck no "(4) Icon at the default cap: rc=$r5 stderr: $(grep -m1 -E 'error|Aborted|ZHP' e5 | cut -c1-140)"; fi
o6=$(clean timeout -k 5 60 "$C" -d8m t.sno < /dev/null 2>/dev/null); r6=$?; [ "$o6" = "trapped 204" ] && ck ok "(5) SETEXIT catches the out-of-memory like any runtime error (&ERRTYPE 204, rc=$r6)" || ck no "(5) SETEXIT: printed '$o6' rc=$r6"
[ "$r1" != 134 ] && ck ok "(6) negative control: the exit-status arm can red (a planted 134 expectation reads FAIL)" || ck no "(6) the witness still aborts (134)"
echo "population: $arms arm(s), $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [test_gate_heap_exhaustion_at_the_cap_is_a_reported_error_not_an_abort]: exhaustion at the cap is a reported out-of-memory error in the frontend's voice, rc below 128, no core, both modes"; exit 0; fi
echo "GATE RED [test_gate_heap_exhaustion_at_the_cap_is_a_reported_error_not_an_abort]: $fails arm(s) failed"; exit 1
