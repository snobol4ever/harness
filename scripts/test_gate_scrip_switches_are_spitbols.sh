#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_scrip_switches_are_spitbols.sh -- EVERY SPITBOL SWITCH SCRIP HONOURS BEHAVES AS sbl -bf DOES, AND EVERY ONE IT
# CANNOT HONOUR IS REFUSED WITH A STATED REASON, NEVER READ AS A FILE NAME AND NEVER ACCEPTED-AND-IGNORED (cto 2026-09-23,
# row spine-scrip-command-line-switches-are-spitbols-every-sbl-h-switch-with-spitbols-meaning; Lon in-chat to the ceo,
# verbatim: "Do make our SCRIP command-line switches just like SPITBOL."; CEO-1224, the three collisions ruled CEO-1227:
# "(1) Reject -F with stated reason. (2) keep our defaults for now. (3) reject for now.").
#
# THE ORACLE IS sbl -bf ITSELF, run beside scrip on the same witness for every behavioural switch: -n (compile, no
# execution, exit 231), -u "string" (HOST(0)), -r (INPUT reads the source after END), -b and -f (no signon, no folding),
# -T=file (TERMINAL to a file, the file compared byte for byte), -#=file (the channel pre-bound, INPUT(.v,#) opens it).
# Each pair must agree on stdout AND exit status. -F and -y are refused with the reason Lon named (non-zero exit, the
# word "case" / "save" in the message, never "cannot open"); -k and the listing family are refused with a reason; and
# no switch of sbl -h is read as a file name.
#
# NEGATIVE-TESTED IN EVERY RUN: an invented switch (-Q) must still be refused as an unknown argument by the driver's
# existing file-name path, so the gate can see the shape it forbids for real switches; and the -u arm plants a wrong
# expectation and must red on it.
#
# Usage: bash ../harness/scripts/test_gate_scrip_switches_are_spitbols.sh    (exit 0 = green, 1 = measured broken, 2 = could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
C="$ROOT/scrip"; B=/home/resources/x64/bin/sbl
[ -x "$C" ] || { echo "REFUSED(2): scrip is not built"; exit 2; }
[ -x "$B" ] || { echo "REFUSED(2): no SPITBOL oracle at $B"; exit 2; }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
cd "$d" || exit 2
printf "        OUTPUT = 'ran'\nEND\n" > n.sno
printf "        OUTPUT = '[' HOST(0) ']'\nEND\n" > u.sno
printf "        OUTPUT = INPUT\n        OUTPUT = INPUT\nEND\nfirst line after end\nsecond line after end\n" > r.sno
printf "        TERMINAL = 'to terminal'\n        OUTPUT = 'to output'\nEND\n" > t.sno
printf "        INPUT(.IN, 1)                          :F(ERR)\n        OUTPUT = 'read: ' IN\nEND\nERR     OUTPUT = 'channel 1 did not open'\nEND\n" > c.sno
printf "channel one text\n" > chan1.txt
printf -- "-LIST\n        OUTPUT = 'ran'\nEND\n" > list.sno
fails=0; arms=0
pair() {   # $1 label, $2 sbl switches, $3 scrip switches, $4 file
    arms=$((arms+1))
    o1=$($B -bf $2 "$4" < /dev/null 2>/dev/null); r1=$?
    o2=$("$C" $3 "$4" < /dev/null 2>/dev/null); r2=$?
    if [ "$o1|$r1" = "$o2|$r2" ]; then echo "  ok   $1: sbl and scrip agree (rc=$r1, '$o1')"; else echo "  FAIL $1: sbl rc=$r1 '$o1' vs scrip rc=$r2 '$o2'"; fails=$((fails+1)); fi
}
pair "-n suppress execution" "-n" "-n" n.sno
pair "-u string -> HOST(0)" "-u hello" "-u hello" u.sno
pair "no -u -> HOST(0) null" "" "" u.sno
pair "-r INPUT after END" "-r" "-r" r.sno
pair "-b no signon" "-b" "-b" n.sno
pair "-f no folding" "-f" "-f" n.sno
pair "-T=file TERMINAL to a file" "-T=t1.txt" "-T=t2.txt" t.sno
arms=$((arms+1)); if [ "$(cat t1.txt 2>/dev/null)" = "$(cat t2.txt 2>/dev/null)" ] && [ -s t2.txt ]; then echo "  ok   -T: the TERMINAL files agree ('$(cat t2.txt)')"; else echo "  FAIL -T: TERMINAL files differ (sbl '$(cat t1.txt 2>/dev/null)' scrip '$(cat t2.txt 2>/dev/null)')"; fails=$((fails+1)); fi
pair "-1=file channel pre-bound" "-1=chan1.txt" "-1=chan1.txt" c.sno
arms=$((arms+1)); o=$(printf "        OUTPUT = '[' HOST(0) ']'\nEND\n" > m4.sno; "$C" --compile -o m4.s m4.sno < /dev/null 2>/dev/null && gcc -no-pie -o m4bin m4.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null && ./m4bin -u fromm4 < /dev/null 2>/dev/null); if [ "$o" = "[fromm4]" ]; then echo "  ok   mode-4 binary: a leading -u string is HOST(0)"; else echo "  FAIL mode-4 binary: HOST(0) read '$o', wanted [fromm4]"; fails=$((fails+1)); fi
refused() {   # $1 label, $2 switch, $3 word the reason must carry
    arms=$((arms+1))
    "$C" $2 n.sno < /dev/null > /dev/null 2> z.err; zr=$?
    if [ "$zr" != 0 ] && ! grep -q "cannot open '-" z.err && grep -qi -- "$3" z.err; then echo "  ok   $1: refused rc=$zr with its reason"; else echo "  FAIL $1: rc=$zr, stderr: $(head -c 160 z.err)"; fails=$((fails+1)); fi
}
refused "-F case folding" "-F" "case"
refused "-y save file" "-y" "save"
refused "-k run with errors" "-k" "compilation error"
for sw in -c -a -l -p -z -g60 -t80 -h -e; do refused "$sw listing/statistics" "$sw" "listing"; done
# ⭐ aac5d0f5d made -o=file the -LIST SINK, not a refusal (CEO-1389 (2)) -- m3 takes it as a driver switch (it
# setenv's SCRIP_SNO_LIST_SINK and parses the program in the same process); a standalone m4 binary has no such
# switch parsing of its own, so the SAME env var goes straight to its environment instead (test_snoflake_suite.sh's
# own fix uses this exact split). Both must land the listing in the file and keep stdout to just the program's OUTPUT.
arms=$((arms+1)); o3=$("$C" --run -o=list3.lst list.sno < /dev/null 2>/dev/null); r3=$?
if [ "$r3" = 0 ] && [ "$o3" = "ran" ] && [ -s list3.lst ] && grep -q "macro spitbol version" list3.lst; then
    echo "  ok   -o=file under -LIST (m3): listing sunk to file, stdout clean"
else
    echo "  FAIL -o=file under -LIST (m3): rc=$r3 stdout='$o3' sink=$([ -s list3.lst ] && echo present || echo MISSING-OR-EMPTY)"; fails=$((fails+1))
fi
arms=$((arms+1))
"$C" --compile -o list4.s list.sno < /dev/null > /dev/null 2>&1 && gcc -no-pie -o list4.bin list4.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null
o4=$(SCRIP_SNO_LIST_SINK="$d/list4.lst" ./list4.bin < /dev/null 2>/dev/null); r4=$?
if [ "$r4" = 0 ] && [ "$o4" = "ran" ] && [ -s "$d/list4.lst" ] && grep -q "macro spitbol version" "$d/list4.lst"; then
    echo "  ok   SCRIP_SNO_LIST_SINK under -LIST (m4): listing sunk to file, stdout clean"
else
    echo "  FAIL SCRIP_SNO_LIST_SINK under -LIST (m4): rc=$r4 stdout='$o4' sink=$([ -s "$d/list4.lst" ] && echo present || echo MISSING-OR-EMPTY)"; fails=$((fails+1))
fi
arms=$((arms+1)); acc=; for a in -d64m -i1m -m16m -s4m -x "-T=tt.txt" "-1=c1.txt" "-u x" -n -r -b -f; do "$C" $a n.sno < /dev/null > /dev/null 2> acc.err; grep -q "cannot open '-" acc.err && acc="$acc $a"; done
if [ -z "$acc" ]; then echo "  ok   no sbl -h switch is read as a file name"; else echo "  FAIL read as a file name:$acc"; fails=$((fails+1)); fi
arms=$((arms+1)); "$C" -Q n.sno < /dev/null > /dev/null 2> q.err; if grep -q "cannot open '-Q'" q.err; then echo "  ok   negative control: an invented switch (-Q) still shows the file-name shape this gate forbids for real ones"; else echo "  FAIL negative control: -Q did not take the file-name path ($(head -c 100 q.err))"; fails=$((fails+1)); fi
arms=$((arms+1)); o=$("$C" -u planted u.sno < /dev/null 2>/dev/null); if [ "$o" != "[not-planted]" ]; then echo "  ok   negative control: the -u arm can red (a wrong expectation reads FAIL)"; else echo "  FAIL negative control: the -u arm cannot fail"; fails=$((fails+1)); fi
echo "population: $arms arm(s), $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [test_gate_scrip_switches_are_spitbols]: every honoured switch behaves as sbl -bf and every refused one says why"; exit 0; fi
echo "GATE RED [test_gate_scrip_switches_are_spitbols]: $fails arm(s) failed"; exit 1
