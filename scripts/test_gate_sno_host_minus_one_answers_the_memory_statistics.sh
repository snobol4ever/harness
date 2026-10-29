#!/usr/bin/env bash
# test_gate_sno_host_minus_one_answers_the_memory_statistics.sh -- HOST(-1,n), n = 0..7, answers SPITBOL's eight memory
# statistics with SCRIP's OWN numbers, and a refused selector raises ERROR 254 as it does under the oracle (ceo CEO-1397; Lon 2026-10-02, in-chat
# to the ceo: "fix all the real gaps and ignore the expected differences").
#
# ⛔⭐ FOUND ON spitbol_x64_tests/gcbuster.sbl, THE ONE X64T RED: SCRIP's HOST had no arm for a negative selector and answered
# null, so MEMINCB, DATABTS, BASEMEM, TOPMEM, STACKSIZ, STACKCUR, WORDSIZE and STACKMAX stayed null and the program's &DUMP
# omitted eight variables -- a SHAPE difference. The VALUES are the implementation's own (memory increment, heap cap, base and
# top addresses, stack size, stack in use, word size, stack high-water mark) and differ by allocator and address space, so they
# are ORACLE IDENTITY (CEO-1344) and masked in the package's ALL.mask; what this gate pins is that every selector ANSWERS and
# the answers stand in the relations SPITBOL's own stand in. SPITBOL's dispatcher is osint/syshs.c case -1 (0 memincb, 1 databts,
# 2 basemem, 3 topmem, 4 stacksiz - 400, 5 stack in use, 6 sizeof(long), 7 stack high-water mark, any other selector or a
# non-integer one EXIT_1, which sbl reports as ERROR 254 'erroneous argument for host'; a missing or null selector reads 0 and a
# numeric string converts -- all five measured against sbl -bf on 2026-10-02 before this gate was written).
#
# THE ARMS: the witness runs under &ERRLIMIT so a raised 254 fails its statement, and prints only RELATIONS over the values (and
# the word size and &ERRTYPE), so the oracle and SCRIP print the SAME lines though their numbers differ:
#   1  the oracle (sbl -bf) prints the expected lines, 'selector 8 fails 254' among them  (cut at run time -- refuses if not)
#   2  m3 prints byte-identical lines          3  m4 prints byte-identical lines
#   4  DETECTOR -- the three refused selectors each read 254 and none answered, in both modes, so a HOST that answered every
#      selector with some integer cannot pass, and a HOST answering null prints 'wordsize ' with no relation lines and fails 2-3
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_host_minus_one_answers_the_memory_statistics
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        &ERRLIMIT = 10
        OUTPUT = 'wordsize ' HOST(-1,6)
        OUTPUT = 'string selector ' HOST(-1,'6')
        OUTPUT = EQ(HOST(-1),HOST(-1,0)) 'missing selector reads 0'
        OUTPUT = GT(HOST(-1,0),0) 'increment positive'
        OUTPUT = GE(HOST(-1,1),HOST(-1,0)) 'cap not below increment'
        OUTPUT = GT(HOST(-1,2),0) 'base positive'
        OUTPUT = GE(HOST(-1,3),HOST(-1,2)) 'top not below base'
        OUTPUT = GT(HOST(-1,4),0) 'stack size positive'
        OUTPUT = GE(HOST(-1,4),HOST(-1,5)) 'stack in use within size'
        OUTPUT = GE(HOST(-1,7),HOST(-1,5)) 'high water not below use'
        HOST(-1,8)                              :S(BAD)
        OUTPUT = 'selector 8 fails ' &ERRTYPE
        HOST(-1,-1)                             :S(BAD)
        OUTPUT = 'selector -1 fails ' &ERRTYPE
        HOST(-1,'x')                            :S(BAD)
        OUTPUT = 'selector x fails ' &ERRTYPE   :(END)
BAD     OUTPUT = 'a bad selector answered'
END
SNO
graded=0; fail=0
arm() { graded=$((graded+1)); if [ "$2" = "$3" ]; then echo "  PASS $1  [$2]"; else echo "  FAIL $1  want[$2] got[$3]"; fail=$((fail+1)); fi; }
( cd "$T" && timeout -k 5 30 "$SBL" -bf w.sno < /dev/null > ora.out 2>/dev/null )
grep -qx 'selector 8 fails 254' "$T/ora.out" || refuse "the oracle did not print 'selector 8 fails 254' on the witness -- the oracle or the witness moved, re-measure rather than score"
grep -qx 'wordsize 8' "$T/ora.out" || refuse "the oracle did not print 'wordsize 8' -- the oracle or the witness moved"
echo "  ARM 1 oracle expectation cut at run time: $(grep -c '' "$T/ora.out") lines, $(tr '\n' '|' < "$T/ora.out")"
graded=$((graded+1))
( cd "$T" && timeout -k 5 30 "$SCRIP" --run w.sno < /dev/null > m3.out 2> m3.err )
( cd "$T" && timeout -k 5 30 "$SCRIP" --compile w.sno --out=w.s > cc.log 2>&1 ) || refuse "mode-4 compile of the witness failed -- cannot measure"
( cd "$T" && gcc -c w.s -o w.o >> cc.log 2>&1 && gcc w.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o w.bin >> cc.log 2>&1 ) || refuse "mode-4 link of the witness failed -- cannot measure"
( cd "$T" && timeout -k 5 30 ./w.bin < /dev/null > m4.out 2> m4.err )
arm "m3-prints-the-oracles-lines" "$(tr '\n' '|' < "$T/ora.out")" "$(tr '\n' '|' < "$T/m3.out")"
arm "m4-prints-the-oracles-lines" "$(tr '\n' '|' < "$T/ora.out")" "$(tr '\n' '|' < "$T/m4.out")"
arm "detector-refused-selectors-raise-254-in-both-modes" "m3=3/0 m4=3/0" "m3=$(grep -c '^selector .* fails 254$' "$T/m3.out")/$(grep -c 'a bad selector answered' "$T/m3.out") m4=$(grep -c '^selector .* fails 254$' "$T/m4.out")/$(grep -c 'a bad selector answered' "$T/m4.out")"
echo "graded=$graded FAIL=$fail  (expectation cut from $SBL -bf at run time; the values themselves are oracle identity, CEO-1344, and are never compared here)"
[ "$graded" = 4 ] || refuse "expected 4 arms, graded $graded"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
